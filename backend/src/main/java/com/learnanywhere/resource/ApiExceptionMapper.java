package com.learnanywhere.resource;

import com.learnanywhere.domain.Models.ApiException;
import jakarta.ws.rs.core.Response;
import jakarta.ws.rs.ext.ExceptionMapper;
import jakarta.ws.rs.ext.Provider;
import java.util.Map;

@Provider
public class ApiExceptionMapper implements ExceptionMapper<ApiException> {
  public Response toResponse(ApiException e) {
    return Response.status(e.status)
        .entity(Map.of("error", Map.of("code", e.code, "message", e.getMessage())))
        .build();
  }
}
