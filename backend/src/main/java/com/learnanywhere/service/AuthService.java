package com.learnanywhere.service;

import com.learnanywhere.domain.AuthModels.LoginRequest;
import com.learnanywhere.domain.AuthModels.LoginResponse;
import com.learnanywhere.domain.AuthModels.User;
import com.learnanywhere.domain.Models.ApiException;
import com.learnanywhere.repository.IAuthRepository;
import com.learnanywhere.config.LearningConfig;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.SecureRandom;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.Locale;
import org.apache.commons.codec.binary.Hex;

@ApplicationScoped
public class AuthService implements IAuthService {
  @Inject IAuthRepository repository;
  @Inject LearningConfig config;
  @Inject IPasswordHasher passwords;

  private String token() {
    byte[] bytes = new byte[32];
    new SecureRandom().nextBytes(bytes);
    return Hex.encodeHexString(bytes);
  }

  private byte[] digest(String token) {
    try {
      return MessageDigest.getInstance("SHA-256").digest(token.getBytes(StandardCharsets.UTF_8));
    } catch (Exception failure) {
      throw new IllegalStateException(failure);
    }
  }

  private byte[] bearer(String header) {
    if (header == null || !header.matches("Bearer [0-9a-f]{64}")) {
      throw new ApiException(401, "unauthorized", "Valid bearer session required");
    }
    return digest(header.substring(7));
  }

  public LoginResponse login(LoginRequest request, String bootstrapAuthorization) {
    if (request == null || request.email() == null || request.password() == null) {
      throw new ApiException(400, "invalid_login", "Email and password required");
    }
    String email = request.email().trim().toLowerCase(Locale.ROOT);
    if (email.length() > 254 || !email.matches("[^\\s@]+@[^\\s@]+\\.[^\\s@]+")
        || request.password().length() < 12 || request.password().length() > 128
        || request.password().isBlank()) {
      throw new ApiException(400, "invalid_login", "Valid email and a 12–128 character password required");
    }
    String staffToken = config.adminToken().orElse("");
    boolean allowCreate = bootstrapAuthorization != null && !staffToken.isEmpty()
        && MessageDigest.isEqual(("Bearer " + staffToken).getBytes(StandardCharsets.UTF_8),
            bootstrapAuthorization.getBytes(StandardCharsets.UTF_8));
    String token = token();
    Instant expires = Instant.now().plus(8, ChronoUnit.HOURS);
    var attempt = repository.login(email, passwords.hash(request.password()),
        encoded -> passwords.matches(request.password(), encoded), allowCreate, digest(token), expires);
    if (attempt.status() == 429) throw new ApiException(429, "login_limited", "Too many failed logins. Try again in 15 minutes.");
    if (attempt.status() != 200) throw new ApiException(401, "invalid_credentials", "Invalid email or password");
    return new LoginResponse(attempt.user(), token,
        "Bearer", expires, attempt.created());
  }

  public User me(String authorization) { return repository.me(bearer(authorization)); }
  public void logout(String authorization) { repository.logout(bearer(authorization)); }
}
