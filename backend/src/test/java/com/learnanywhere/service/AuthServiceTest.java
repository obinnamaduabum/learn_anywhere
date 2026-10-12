package com.learnanywhere.service;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

import com.learnanywhere.config.LearningConfig;
import com.learnanywhere.domain.AuthModels.LoginAttempt;
import com.learnanywhere.domain.AuthModels.LoginRequest;
import com.learnanywhere.domain.AuthModels.User;
import com.learnanywhere.domain.Models.ApiException;
import com.learnanywhere.repository.IAuthRepository;
import java.time.Instant;
import java.util.Optional;
import java.util.UUID;
import java.util.function.Predicate;
import org.junit.jupiter.api.Test;

class AuthServiceTest {
  @Test
  void passwordsUseIndependentSaltsAndRejectWrongPasswords() {
    var hasher = new PasswordHasher();
    String a = hasher.hash("A long test password");
    String b = hasher.hash("A long test password");
    assertNotEquals(a, b);
    assertTrue(hasher.matches("A long test password", a));
    assertFalse(hasher.matches("Wrong test password", a));
    assertFalse(hasher.matches("A long test password", "malformed"));
  }

  private AuthService service() {
    AuthService service = new AuthService();
    service.passwords = new PasswordHasher();
    service.config = new LearningConfig() {
      public Optional<String> adminToken() { return Optional.of("test-bootstrap-only"); }
      public Optional<String> openaiKey() { return Optional.empty(); }
      public Optional<String> openaiModel() { return Optional.empty(); }
      public Optional<String> groqKey() { return Optional.empty(); }
      public Optional<String> groqModel() { return Optional.empty(); }
    };
    return service;
  }

  @Test
  void firstLoginRequiresBootstrapAndNormalizesEmail() {
    AuthService service = service();
    service.repository = new IAuthRepository() {
      public LoginAttempt login(String email, String hash, Predicate<String> matches,
          boolean allowCreate, byte[] sessionHash, Instant expiry) {
        assertEquals("admin@example.invalid", email);
        assertEquals(32, sessionHash.length);
        assertTrue(expiry.isAfter(Instant.now()));
        assertTrue(expiry.isBefore(Instant.now().plusSeconds(9 * 3600)));
        return allowCreate ? new LoginAttempt(new User(UUID.randomUUID(), email), true, 200)
            : new LoginAttempt(null, false, 401);
      }
      public User me(byte[] hash) { throw new UnsupportedOperationException(); }
      public void logout(byte[] hash) { throw new UnsupportedOperationException(); }
    };
    LoginRequest request = new LoginRequest(" ADMIN@EXAMPLE.INVALID ", "A long test password");
    assertEquals(401, assertThrows(ApiException.class, () -> service.login(request, null)).status);
    var response = service.login(request, "Bearer test-bootstrap-only");
    assertTrue(response.created());
    assertEquals(64, response.token().length());
    assertEquals("Bearer", response.tokenType());
  }

  @Test
  void invalidPayloadAndSessionAreRejectedBeforeRepositoryAccess() {
    AuthService service = service();
    assertEquals(400, assertThrows(ApiException.class, () -> service.login(null, null)).status);
    assertEquals(400, assertThrows(ApiException.class,
        () -> service.login(new LoginRequest("invalid", "short"), null)).status);
    assertEquals(401, assertThrows(ApiException.class, () -> service.me("Bearer bad")).status);
  }
}
