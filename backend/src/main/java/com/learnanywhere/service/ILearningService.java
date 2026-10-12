package com.learnanywhere.service;

import com.fasterxml.jackson.databind.JsonNode;
import com.learnanywhere.domain.Models.ApprovalRequest;
import com.learnanywhere.domain.Models.CourseRequest;
import com.learnanywhere.domain.Models.DraftRequest;
import com.learnanywhere.domain.Models.Installation;
import com.learnanywhere.domain.Models.StoredPack;
import com.learnanywhere.domain.Models.SyncRequest;
import com.learnanywhere.domain.Models.SyncResponse;
import java.util.List;

public interface ILearningService {
  JsonNode requestCourse(String auth, CourseRequest request);

  JsonNode requests(String auth);

  Installation register();

  List<JsonNode> courses();

  JsonNode progress(String auth);

  StoredPack pack(String course, int version, String language);

  JsonNode explanations(String course, int version, String language);

  SyncResponse sync(String authorization, SyncRequest request);

  long importDraft(String authorization, DraftRequest request);

  JsonNode draft(String authorization, long id);

  void approve(String authorization, long id, ApprovalRequest request);
  long importExplanationDraft(String auth, JsonNode payload);
  JsonNode explanationDraft(String auth, long id);
  void approveExplanation(String auth, long id, JsonNode payload);
}
