package com.learnanywhere.service;
import com.fasterxml.jackson.databind.JsonNode;
public interface ILearningCompanion {
  JsonNode assist(String authorization, CompanionRequest request);
  record CompanionRequest(String courseId, int version, String language, int lessonId, String action) {}
}
