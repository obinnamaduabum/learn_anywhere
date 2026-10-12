package com.learnanywhere.service;

import com.learnanywhere.domain.AuthModels.LoginRequest;
import com.learnanywhere.domain.AuthModels.LoginResponse;
import com.learnanywhere.domain.AuthModels.User;

public interface IAuthService {
  LoginResponse login(LoginRequest request, String bootstrapAuthorization);
  User me(String authorization);
  void logout(String authorization);
}
