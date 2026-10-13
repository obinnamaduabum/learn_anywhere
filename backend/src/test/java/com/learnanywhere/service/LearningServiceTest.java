package com.learnanywhere.service;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ObjectNode;
import com.fasterxml.jackson.databind.node.ArrayNode;
import com.learnanywhere.domain.Models.ApiException;
import com.learnanywhere.domain.Models.Event;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.Arrays;
import org.junit.jupiter.api.Test;

class LearningServiceTest {
  ObjectMapper json = new ObjectMapper();

  JsonNode pack() throws Exception {
    return json.readTree(Files.readString(Path.of("../frontend/test/fixtures/packs/en.json")));
  }

  @Test
  void validatesOptionalBackendMarkdown() throws Exception {
    ObjectNode p = (ObjectNode) pack();
    ObjectNode lesson = (ObjectNode) p.path("lessons").get(0);
    lesson.put("bodyMarkdown", "## Key idea\n\nA **clear** paragraph.\n\n- First step\n- Second step");
    LearningService.validatePack(p);
    lesson.put("bodyMarkdown", "<script>unsafe</script>");
    assertThrows(ApiException.class, () -> LearningService.validatePack(p));
    lesson.put("bodyMarkdown", " ");
    assertThrows(ApiException.class, () -> LearningService.validatePack(p));
    lesson.remove("bodyMarkdown");
    LearningService.validatePack(p);
  }

  ObjectNode state() {
    ObjectNode s = json.createObjectNode();
    s.putObject("lessons");
    s.putObject("rewards");
    return s;
  }

  Event event(String type, int lesson, String question, int answer) {
    return new Event("event", type, lesson, question, answer, null);
  }

  @Test
  void validatesIncludedPack() throws Exception {
    LearningService.validatePack(pack());
  }

  @Test
  void acceptsMaterialDependentLessonCounts() throws Exception {
    for (int count : Arrays.asList(1, 3, 8)) {
      ObjectNode p = (ObjectNode) pack();
      JsonNode template = p.path("lessons").get(0).deepCopy();
      ArrayNode lessons = p.putArray("lessons");
      for (int i = 0; i < count; i++) {
        ObjectNode lesson = template.deepCopy();
        lesson.put("id", i);
        int questionIndex = 0;
        for (JsonNode question : lesson.path("questions")) {
          ((ObjectNode) question).put("id", "l" + i + "-q" + questionIndex++);
        }
        lessons.add(lesson);
      }
      LearningService.validatePack(p);
      ObjectNode explanations = p.putObject("explanations");
      explanations.put("version", 1);
      ArrayNode entries = explanations.putArray("lessons");
      for (int i = 0; i < count; i++) entries.addObject().put("id", i).put("text", "Reviewed explanation");
      LearningService.validatePack(p);
      entries.remove(count - 1);
      assertThrows(ApiException.class, () -> LearningService.validatePack(p));
    }
    ObjectNode empty = (ObjectNode) pack();
    empty.putArray("lessons");
    assertThrows(ApiException.class, () -> LearningService.validatePack(empty));
  }

  @Test
  void draftReadingTimesMustBeFiveToFifteenMinutes() throws Exception {
    for (int duration : Arrays.asList(5, 10, 15)) {
      JsonNode p = pack();
      for (JsonNode lesson : p.path("lessons")) {
        ((ObjectNode) lesson).put("minutes", duration).put("body", "word ".repeat(duration * 200));
      }
      LearningService.validateReadingTimes(p);
    }
    for (int duration : Arrays.asList(0, 4, 16)) {
      JsonNode p = pack();
      ((ObjectNode) p.path("lessons").get(0)).put("minutes", duration);
      assertThrows(ApiException.class, () -> LearningService.validateReadingTimes(p));
    }
    JsonNode shortPack = pack();
    for (JsonNode lesson : shortPack.path("lessons")) ((ObjectNode) lesson).put("minutes", 5);
    assertThrows(ApiException.class, () -> LearningService.validateReadingTimes(shortPack));
    JsonNode p = pack();
    ((ObjectNode) p.path("lessons").get(0)).remove("minutes");
    assertThrows(ApiException.class, () -> LearningService.validateReadingTimes(p));
  }

  @Test
  void readingCanBeOutOfOrderAndQuizRewardsOnce() throws Exception {
    JsonNode p = pack();
    ObjectNode s = state();
    LearningService.apply(s, p, event("lesson_read", 1, null, 0));
    assertEquals(false, s.path("lessons").path("0").path("read").asBoolean());
    LearningService.apply(s, p, event("lesson_read", 0, null, 0));
    LearningService.apply(s, p, event("lesson_read", 1, null, 0));
    assertThrows(
        ApiException.class, () -> LearningService.apply(s, p, event("quiz_completed", 0, null, 0)));
    for (int i = 0; i < 2; i++) {
      for (JsonNode q : p.path("lessons").get(0).path("questions")) {
        LearningService.apply(
            s, p, event("quiz_answered", 0, q.path("id").asText(), q.path("correct").asInt()));
      }
      LearningService.apply(s, p, event("quiz_completed", 0, null, 0));
    }
    int points = 0;
    for (JsonNode r : s.path("rewards")) points += r.asInt();
    assertEquals(80, points);
    LearningService.apply(s, p, event("lesson_read", 1, null, 0));
  }

  @Test
  void quizBeforeReadingPreservesUnreadStateAndDeduplicatesRewards() throws Exception {
    JsonNode p = pack();
    ObjectNode s = state();
    int id = 4;
    assertThrows(
        ApiException.class, () -> LearningService.apply(s, p, event("quiz_completed", id, null, 0)));
    for (int attempt = 0; attempt < 2; attempt++) {
      for (JsonNode question : p.path("lessons").get(id).path("questions")) {
        LearningService.apply(
            s, p, event("quiz_answered", id, question.path("id").asText(), question.path("correct").asInt()));
      }
      LearningService.apply(s, p, event("quiz_completed", id, null, 0));
    }
    assertEquals(false, s.path("lessons").path("4").path("read").asBoolean());
    assertEquals(true, s.path("lessons").path("4").path("complete").asBoolean());
    int points = 0;
    for (JsonNode reward : s.path("rewards")) points += reward.asInt();
    assertEquals(80, points);
    assertEquals(false, s.path("lessons").has("0"));
  }

  @Test
  void zeroScoreUnlocksAndFinalChecklistRequired() throws Exception {
    JsonNode p = pack();
    ObjectNode s = state();
    for (JsonNode lesson : p.path("lessons")) {
      int id = lesson.path("id").asInt();
      LearningService.apply(s, p, event("lesson_read", id, null, 0));
      for (JsonNode q : lesson.path("questions")) {
        LearningService.apply(
            s,
            p,
            event(
                "quiz_answered",
                id,
                q.path("id").asText(),
                (q.path("correct").asInt() + 1) % q.path("options").size()));
      }
      LearningService.apply(s, p, event("quiz_completed", id, null, 0));
    }
    assertThrows(
        ApiException.class, () -> LearningService.apply(s, p, event("task_completed", 0, null, 0)));
    var finalEvent =
        new Event(
            "f",
            "task_completed",
            0,
            null,
            0,
            Arrays.asList("recap", "practice", "plan", "demonstrate"));
    LearningService.apply(s, p, finalEvent);
    LearningService.apply(s, p, finalEvent);
    int points = 0;
    for (JsonNode r : s.path("rewards")) points += r.asInt();
    assertEquals(350, points);
  }

  @Test
  void badAnswerAndMissingSourceRejected() throws Exception {
    JsonNode p = pack();
    ObjectNode s = state();
    LearningService.apply(s, p, event("lesson_read", 0, null, 0));
    assertThrows(
        ApiException.class,
        () -> LearningService.apply(s, p, event("quiz_answered", 0, "1-1", 99)));
    ((ObjectNode) p.path("lessons").get(0)).put("sourceUrl", "http://invalid.local");
    assertThrows(ApiException.class, () -> LearningService.validatePack(p));
  }

  @Test
  void whitespaceOnlyContentRejected() throws Exception {
    for (String blank : Arrays.asList("", " \t\n", "\u2003")) {
      JsonNode p = pack();
      ((ObjectNode) p.path("lessons").get(0)).put("body", blank);
      assertThrows(ApiException.class, () -> LearningService.validatePack(p));
    }
  }

}
