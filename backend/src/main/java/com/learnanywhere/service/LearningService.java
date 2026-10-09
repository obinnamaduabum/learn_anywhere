package com.learnanywhere.service;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ObjectNode;
import com.learnanywhere.config.LearningConfig;
import com.learnanywhere.domain.Models.ApiException;
import com.learnanywhere.domain.Models.ApprovalRequest;
import com.learnanywhere.domain.Models.CourseRequest;
import com.learnanywhere.domain.Models.DraftRequest;
import com.learnanywhere.domain.Models.Event;
import com.learnanywhere.domain.Models.Installation;
import com.learnanywhere.domain.Models.StoredPack;
import com.learnanywhere.domain.Models.SyncRequest;
import com.learnanywhere.domain.Models.SyncResponse;
import com.learnanywhere.repository.ILearningRepository;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import io.quarkus.scheduler.Scheduled;
import java.io.IOException;
import java.net.URI;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.SecureRandom;
import java.util.Arrays;
import java.util.HashSet;
import java.util.List;
import java.util.Set;
import java.util.UUID;
import org.apache.commons.codec.binary.Hex;
import org.apache.commons.lang3.StringUtils;

@ApplicationScoped
public class LearningService implements ILearningService {
  @Inject ILearningRepository repository;
  @Inject ObjectMapper json;
  @Inject OpenAIContentGenerator generator;
  @Inject LearningConfig config;

  public Installation register() {
    byte[] bytes = new byte[32];
    new SecureRandom().nextBytes(bytes);
    String token = Hex.encodeHexString(bytes);
    UUID id = UUID.randomUUID();
    repository.register(id, digest(token));
    return new Installation(id.toString(), token);
  }

  private byte[] digest(String value) {
    try {
      return MessageDigest.getInstance("SHA-256").digest(value.getBytes(StandardCharsets.UTF_8));
    } catch (Exception e) {
      throw new IllegalStateException(e);
    }
  }

  private String bearer(String header) {
    if (header == null || !header.startsWith("Bearer "))
      throw new ApiException(401, "unauthorized", "Bearer token required");
    return header.substring(7);
  }

  private void admin(String header) {
    String token = bearer(header);
    if (config.adminToken().orElse("").isEmpty()
        || !MessageDigest.isEqual(
            token.getBytes(StandardCharsets.UTF_8),
            config.adminToken().orElse("").getBytes(StandardCharsets.UTF_8)))
      throw new ApiException(403, "forbidden", "Staff token required");
  }

  public List<JsonNode> courses() {
    return repository.courses();
  }

  public StoredPack pack(String course, int version, String language) {
    if (version < 1) throw invalid("Invalid version");
    return repository.pack(course, version, language);
  }

  public JsonNode requestCourse(String auth, CourseRequest request) {
    if (request == null || request.title() == null || request.title().trim().isEmpty() || request.title().length() > 160
        || !Arrays.asList("en","fr","pt","ar","ha","yo","ig").contains(request.language())
        || !Arrays.asList("ai","human").contains(request.source())) throw invalid("Valid title, supported language and ai/human source required");
    UUID requestId;
    try { requestId = UUID.fromString(request.requestId()); } catch (Exception e) { throw invalid("Valid requestId required"); }
    String token = bearer(auth);
    if (token.length() != 64) throw new ApiException(401,"unauthorized","Invalid token");
    UUID installation = repository.authenticate(digest(token));
    if (request.source().equals("ai")) generator.requireConfigured();
    return repository.reserveRequest(installation,request);
  }

  public JsonNode requests(String auth) {
    String token = bearer(auth);
    if (token.length() != 64) throw new ApiException(401,"unauthorized","Invalid token");
    return repository.requests(repository.authenticate(digest(token)));
  }

  @Scheduled(every = "10s", concurrentExecution = Scheduled.ConcurrentExecution.SKIP)
  void generateRequestedCourse() {
    if (!generator.configured()) return;
    JsonNode job = repository.claimRequest();
    if (job == null) return;
    UUID requestId = UUID.fromString(job.path("id").asText());
    String title = job.path("title").asText();
    String language = job.path("language").asText();
    try {
      ObjectNode pack = (ObjectNode) generator.generate(title,List.of(title),language,"text");
      pack.put("id","requested-" + requestId).put("language",language).put("version",1);
      pack.put("reviewStatus","AI-generated draft; human review pending");
      validatePack(pack);
      long draftId = repository.saveDraft(new DraftRequest(List.of(title),"OpenAI",generator.modelName(),pack));
      repository.finishRequest(requestId,"awaiting_approval",draftId);

    } catch (RuntimeException e) { repository.finishRequest(requestId,"failed",null); }
  }

  public JsonNode progress(String auth) {
    String token = bearer(auth);
    if (token.length() != 64) throw new ApiException(401, "unauthorized", "Invalid token");
    return repository.progress(repository.authenticate(digest(token)));
  }

  public SyncResponse sync(String auth, SyncRequest request) {
    String token = bearer(auth);
    if (token.length() != 64) throw new ApiException(401, "unauthorized", "Invalid token");
    UUID id = repository.authenticate(digest(token));
    try {
      JsonNode pack =
          json.readTree(
              repository.pack(request.courseId(), request.version(), request.language()).bytes());
      return repository.sync(id, request, (state, event) -> apply(state, pack, event));
    } catch (IOException e) {
      throw new IllegalStateException("Stored pack invalid", e);
    }
  }

  public long importDraft(String auth, DraftRequest request) {
    admin(auth);
    validatePack(request.pack());
    ((ObjectNode) request.pack()).put("reviewStatus", "AI-generated draft; human review pending");
    return repository.saveDraft(request);
  }

  public JsonNode draft(String auth, long id) {
    admin(auth);
    return repository.draft(id);
  }

  public void approve(String auth, long id, ApprovalRequest request) {
    admin(auth);
    validatePack(repository.draft(id).path("pack"));
    if (request.category() != null
        && (request.category().trim().isEmpty() || request.category().trim().length() > 80))
      throw invalid("Category must contain 1 to 80 characters");
    repository.approve(id, request);
  }

  public static ApiException invalid(String message) {
    return new ApiException(422, "validation_error", message);
  }

  public JsonNode explanations(String course, int version, String language) {
    try {
      JsonNode source = json.readTree(pack(course, version, language).bytes());
      ObjectNode result = json.createObjectNode();
      result.put("courseId", course); result.put("courseVersion", version); result.put("language", language);
      JsonNode content = source.path("explanations");
      result.put("available", !content.isMissingNode());
      if (!content.isMissingNode()) {
        result.put("explanationVersion", content.path("version").asInt());
        result.set("lessons", content.path("lessons"));
      }
      return result;
    } catch (java.io.IOException e) { throw invalid("Could not read explanation pack"); }
  }

  static void validateExplanations(JsonNode p) {
    if (!p.has("explanations")) return;
    JsonNode content = p.path("explanations");
    if (!content.path("version").isIntegralNumber() || content.path("version").asInt() < 1
        || !content.path("lessons").isArray() || content.path("lessons").size() != 5)
      throw invalid("Explanations need a positive version and five lessons");
    int id = 0;
    for (JsonNode item : content.path("lessons")) {
      if (!item.path("id").isInt() || item.path("id").asInt() != id++ || !item.path("text").isTextual()
          || item.path("text").asText().isBlank() || item.path("text").asText().length() > 6000)
        throw invalid("Explanation needs ordered lesson ID and text up to 6000 characters");
    }
  }

  public static void validatePack(JsonNode p) {
    validateExplanations(p);
    if (!p.isObject()
        || StringUtils.isBlank(p.path("id").asText())
        || StringUtils.isBlank(p.path("language").asText())
        || p.path("version").asInt() < 1
        || !p.path("lessons").isArray()
        || p.path("lessons").size() != 5)
      throw invalid("Pack needs identity, language, version and five lessons");
    Set<String> ids = new HashSet<>();
    int i = 0;
    for (JsonNode l : p.path("lessons")) {
      if (!l.path("id").isInt()
          || l.path("id").asInt() != i++
          || StringUtils.isBlank(l.path("title").asText())
          || StringUtils.isBlank(l.path("body").asText())
          || !l.path("questions").isArray()
          || l.path("questions").isEmpty())
        throw invalid("Lesson needs ordered ID, title, accessible text and quiz");
      String format = l.path("format").asText("text");
      if (!Arrays.asList("text", "video", "slides").contains(format)) throw invalid("Unsupported format");
      if (format.equals("slides") && (!l.path("slides").isArray() || l.path("slides").isEmpty()))
        throw invalid("Slide content required");
      try {
        URI u = URI.create(l.path("sourceUrl").asText());
        if (!"https".equals(u.getScheme()) || u.getHost() == null)
          throw invalid("HTTPS source required");
      } catch (IllegalArgumentException e) {
        throw invalid("Invalid source URL");
      }
      for (JsonNode q : l.path("questions")) {
        String id = q.path("id").asText();
        if (StringUtils.isBlank(id)
            || !ids.add(id)
            || StringUtils.isBlank(q.path("prompt").asText())
            || StringUtils.isBlank(q.path("explanation").asText())
            || !q.path("options").isArray()
            || q.path("options").size() < 2
            || !q.path("correct").isInt()
            || q.path("correct").asInt() < 0
            || q.path("correct").asInt() >= q.path("options").size())
          throw invalid("Invalid quiz question");
      }
    }
  }

  public static void apply(ObjectNode state, JsonNode pack, Event event) {
    ObjectNode lessons = (ObjectNode) state.get("lessons"),
        rewards = (ObjectNode) state.get("rewards");
    if (event.type().equals("task_completed")) {
      for (JsonNode l : pack.path("lessons")) {
        if (!lessons.path(l.path("id").asText()).path("complete").asBoolean())
          throw invalid("Complete every lesson quiz first");
      }
      if (event.checklist() == null
          || !event
              .checklist()
              .containsAll(
                  pack.path("id").asText().equals("digital-safety-v1")
                      ? Arrays.asList("screen_lock", "unique_password", "mfa", "backup")
                      : Arrays.asList("recap", "practice", "plan", "demonstrate")))
        throw invalid("Complete safety checklist");
      state.put("taskComplete", true);
      rewards.put("final-task", 100);
      return;
    }
    JsonNode lesson = null, previous = null;
    for (JsonNode l : pack.path("lessons")) {
      if (l.path("id").asInt() == event.lessonId()) {
        lesson = l;
        break;
      }
      previous = l;
    }
    if (lesson == null) throw invalid("Unknown lesson");
    if (previous != null
        && !lessons.path(previous.path("id").asText()).path("read").asBoolean())
      throw invalid("Read previous lesson first");
    String key = Integer.toString(event.lessonId());
    ObjectNode progress = (ObjectNode) lessons.get(key);
    if (progress == null) {
      progress = lessons.putObject(key);
      progress.putObject("answers");
    }
    ObjectNode answers = (ObjectNode) progress.get("answers");
    switch (event.type()) {
      case "lesson_read" -> progress.put("read", true);
      case "quiz_answered" -> {
        if (!progress.path("read").asBoolean()) throw invalid("Read lesson first");
        JsonNode q = null;
        for (JsonNode question : lesson.path("questions")) {
          if (question.path("id").asText().equals(event.questionId())) {
            q = question;
            break;
          }
        }
        if (q == null) throw invalid("Unknown question");
        if (event.selectedOption() < 0 || event.selectedOption() >= q.path("options").size())
          throw invalid("Invalid answer option");
        answers.put(event.questionId(), event.selectedOption());
        if (event.selectedOption() == q.path("correct").asInt())
          rewards.put("question:" + event.questionId(), 10);
      }
      case "quiz_completed" -> {
        if (!progress.path("read").asBoolean()) throw invalid("Read lesson first");
        for (JsonNode q : lesson.path("questions")) {
          if (!answers.has(q.path("id").asText())) throw invalid("Answer every question first");
        }
        progress.put("complete", true);
        rewards.put("lesson:" + key, 50);
      }
      default -> throw invalid("Unknown event type");
    }
  }
}
