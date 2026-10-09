package com.learnanywhere.service;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ObjectNode;
import com.learnanywhere.domain.Models.ApiException;
import com.learnanywhere.domain.Models.Event;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.Arrays;
import org.junit.jupiter.api.Test;

class LearningServiceTest {
  ObjectMapper json = new ObjectMapper();

  JsonNode pack() throws Exception {
    return json.readTree(Files.readString(Path.of("../frontend/assets/packs/en.json")));
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
  void readingUnlocksLessonsAndQuizRewardsOnce() throws Exception {
    JsonNode p = pack();
    ObjectNode s = state();
    assertThrows(
        ApiException.class, () -> LearningService.apply(s, p, event("lesson_read", 1, null, 0)));
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
            Arrays.asList("screen_lock", "unique_password", "mfa", "backup"));
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
