package com.learnanywhere.resource;

import com.fasterxml.jackson.databind.JsonNode;

import com.learnanywhere.domain.Models.ApprovalRequest;
import com.learnanywhere.domain.Models.CourseRequest;
import com.learnanywhere.domain.Models.DraftRequest;
import com.learnanywhere.domain.Models.SyncRequest;
import jakarta.validation.Valid;
import jakarta.ws.rs.core.Response;

public interface ILearningResource {
  Response requestCourse(String auth, CourseRequest request);

  Response importExplanationDraft(String auth, JsonNode payload);
  Response explanationDraft(String auth, long id);
  Response approveExplanation(String auth, long id, JsonNode payload);

  Response register();

  Response courses();

  Response pack(String course, String language, int version, String etag);

  Response sync(String auth, @Valid SyncRequest request);

  Response importDraft(String auth, @Valid DraftRequest request);

  Response draft(String auth, long id);

  Response approve(String auth, long id, @Valid ApprovalRequest request);
}
