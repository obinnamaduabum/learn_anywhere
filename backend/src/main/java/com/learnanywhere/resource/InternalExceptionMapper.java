package com.learnanywhere.resource;

import jakarta.ws.rs.core.Response;
import jakarta.ws.rs.ext.ExceptionMapper;
import jakarta.ws.rs.ext.Provider;
import java.util.Map;

@Provider
public class InternalExceptionMapper implements ExceptionMapper<IllegalStateException> {
  public Response toResponse(IllegalStateException e) {
    return Response.status(500)
        .entity(
            Map.of(
                "error",
                Map.of("code", "internal_error", "message", "Request could not be completed")))
        .build();
  }
}
