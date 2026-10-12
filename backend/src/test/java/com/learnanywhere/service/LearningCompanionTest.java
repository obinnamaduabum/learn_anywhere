package com.learnanywhere.service;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertThrows;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.learnanywhere.domain.Models.ApiException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.UUID;
import org.junit.jupiter.api.Test;
class LearningCompanionTest {
  @Test void providerContextExcludesAssessmentAnswers() throws Exception {
    var mapper = new ObjectMapper();
    var pack = mapper.readTree(Files.readString(Path.of("../frontend/assets/packs/en.json")));
    var context = LearningCompanion.lessonContext(mapper,pack,0);
    assertEquals(pack.path("lessons").get(0).path("body"),context.path("body"));
    assertFalse(context.has("questions"));
    assertFalse(context.has("correct"));
    assertThrows(ApiException.class,() -> LearningCompanion.lessonContext(mapper,pack,99));
  }
  @Test void reviewedExplanationsRequireCompleteOrderedContent() throws Exception {
    var mapper = new ObjectMapper();
    var pack = mapper.createObjectNode();
    LearningService.validateExplanations(pack);
    var contentLessons = pack.putArray("lessons");
    for (int i = 0; i < 3; i++) contentLessons.addObject().put("id", i);
    var explanations = pack.putObject("explanations");
    explanations.put("version",1);
    var lessons = explanations.putArray("lessons");
    for (int i=0;i<3;i++) lessons.addObject().put("id",i).put("text","Reviewed explanation");
    LearningService.validateExplanations(pack);
    ((com.fasterxml.jackson.databind.node.ObjectNode) lessons.get(2)).put("id",0);
    assertThrows(ApiException.class,() -> LearningService.validateExplanations(pack));
  }
  @Test void quotaBoundsRequestsPerInstallation() {
    var service = new LearningCompanion();
    UUID id = UUID.randomUUID();
    for(int i=0;i<10;i++) service.reserve(id);
    assertThrows(ApiException.class,() -> service.reserve(id));
    service.reserve(UUID.randomUUID());
  }
}
