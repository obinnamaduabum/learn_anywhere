package com.learnanywhere.service;

public interface IPasswordHasher {
  String hash(String password);
  boolean matches(String password, String encoded);
}
