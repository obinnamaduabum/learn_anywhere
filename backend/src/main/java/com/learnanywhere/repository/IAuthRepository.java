package com.learnanywhere.repository;

import com.learnanywhere.domain.AuthModels.LoginAttempt;
import com.learnanywhere.domain.AuthModels.User;
import java.time.Instant;
import java.util.function.Predicate;

public interface IAuthRepository {
  LoginAttempt login(String email, String passwordHash, Predicate<String> matches,
      boolean allowCreate, byte[] sessionHash, Instant expiresAt);
  User me(byte[] sessionHash);
  void logout(byte[] sessionHash);
}
