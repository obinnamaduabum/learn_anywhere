package com.learnanywhere.domain;

import java.time.Instant;
import java.util.UUID;

public final class AuthModels {
  private AuthModels() {}

  public record LoginRequest(String email, String password) {}
  public record User(UUID id, String email) {}
  public record LoginAttempt(User user, boolean created, int status) {}
  public record LoginResponse(User user, String token,
      String tokenType, Instant expiresAt, boolean created) {}
}
