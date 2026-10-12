package com.learnanywhere.service;

import jakarta.enterprise.context.ApplicationScoped;
import java.security.MessageDigest;
import java.security.SecureRandom;
import java.util.Base64;
import javax.crypto.SecretKeyFactory;
import javax.crypto.spec.PBEKeySpec;

@ApplicationScoped
public class PasswordHasher implements IPasswordHasher {
  private static final int ITERATIONS = 600_000;

  private byte[] derive(String password, byte[] salt, int iterations) {
    PBEKeySpec spec = new PBEKeySpec(password.toCharArray(), salt, iterations, 256);
    try {
      return SecretKeyFactory.getInstance("PBKDF2WithHmacSHA256").generateSecret(spec).getEncoded();
    } catch (Exception failure) {
      throw new IllegalStateException("Password hashing unavailable", failure);
    } finally {
      spec.clearPassword();
    }
  }

  public String hash(String password) {
    byte[] salt = new byte[16];
    new SecureRandom().nextBytes(salt);
    return "pbkdf2-sha256$" + ITERATIONS + "$" + Base64.getEncoder().encodeToString(salt)
        + "$" + Base64.getEncoder().encodeToString(derive(password, salt, ITERATIONS));
  }

  public boolean matches(String password, String encoded) {
    try {
      String[] parts = encoded.split("\\$");
      if (parts.length != 4 || !parts[0].equals("pbkdf2-sha256")) return false;
      int iterations = Integer.parseInt(parts[1]);
      if (iterations != ITERATIONS) return false;
      byte[] salt = Base64.getDecoder().decode(parts[2]);
      byte[] expected = Base64.getDecoder().decode(parts[3]);
      if (salt.length != 16 || expected.length != 32) return false;
      return MessageDigest.isEqual(expected, derive(password, salt, iterations));
    } catch (IllegalArgumentException failure) {
      return false;
    }
  }
}
