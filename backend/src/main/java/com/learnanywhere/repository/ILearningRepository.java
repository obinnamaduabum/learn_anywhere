package com.learnanywhere.repository;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.node.ObjectNode;
import com.learnanywhere.domain.Models.ApprovalRequest;
import com.learnanywhere.domain.Models.CourseRequest;
import com.learnanywhere.domain.Models.DraftRequest;
import com.learnanywhere.domain.Models.Event;
import com.learnanywhere.domain.Models.StoredPack;
import com.learnanywhere.domain.Models.SyncRequest;
import com.learnanywhere.domain.Models.SyncResponse;
import java.util.List;
import java.util.UUID;
import java.util.function.BiConsumer;

public interface ILearningRepository {
  JsonNode reserveRequest(UUID installation, CourseRequest request);

  JsonNode claimRequest();

  JsonNode requests(UUID installation);

  void finishRequest(UUID id, String status, Long draftId);

  void register(UUID id, byte[] hash);

  UUID authenticate(byte[] hash);

  List<JsonNode> courses();

  JsonNode progress(UUID installation);

  StoredPack pack(String course, int version, String language);

  SyncResponse sync(UUID installation, SyncRequest request, BiConsumer<ObjectNode, Event> apply);

  long saveDraft(DraftRequest request);

  JsonNode draft(long id);

  void approve(long id, ApprovalRequest request);
}
