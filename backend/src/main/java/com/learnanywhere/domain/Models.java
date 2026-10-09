package com.learnanywhere.domain;

import com.fasterxml.jackson.databind.JsonNode;
import jakarta.validation.Valid;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import java.util.List;

public final class Models {
  private Models() {}

  public record CourseRequest(String title, String language, String source, String requestId) {}

  public record Event(
      @NotBlank @Size(max = 128) String id,
      @NotBlank String type,
      int lessonId,
      String questionId,
      int selectedOption,
      List<String> checklist) {}

  public record SyncRequest(
      @NotBlank String courseId,
      @Min(1) int version,
      @NotBlank String language,
      @NotEmpty @Size(max = 100) List<@Valid Event> events) {}

  public record SyncResponse(
      List<String> acceptedEventIds, int confirmedPoints, int coursePoints) {}

  public record Installation(String installationId, String token) {}

  public record DraftRequest(
      @NotEmpty List<@NotBlank String> topics,
      @NotBlank String provider,
      @NotBlank String model,
      @NotNull JsonNode pack) {}

  public record ApprovalRequest(
      @NotBlank String reviewer, @NotBlank String title, @NotBlank String description, String category) {}

  public record StoredPack(byte[] bytes, String hash) {}

  public static class ApiException extends RuntimeException {
    public final int status;
    public final String code;

    public ApiException(int status, String code, String message) {
      super(message);
      this.status = status;
      this.code = code;
    }
  }
}
