package com.learnanywhere.resource;

import com.learnanywhere.domain.AuthModels.LoginRequest;
import jakarta.ws.rs.core.Response;

public interface IAuthResource {
  Response login(LoginRequest request, String authorization);
  Response me(String authorization);
  Response logout(String authorization);
}
