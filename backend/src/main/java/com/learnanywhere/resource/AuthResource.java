package com.learnanywhere.resource;

import com.learnanywhere.domain.AuthModels.LoginRequest;
import com.learnanywhere.service.IAuthService;
import jakarta.inject.Inject;
import jakarta.ws.rs.Consumes;
import jakarta.ws.rs.GET;
import jakarta.ws.rs.HeaderParam;
import jakarta.ws.rs.POST;
import jakarta.ws.rs.Path;
import jakarta.ws.rs.Produces;
import jakarta.ws.rs.core.MediaType;
import jakarta.ws.rs.core.Response;
import org.eclipse.microprofile.openapi.annotations.Operation;
import org.eclipse.microprofile.openapi.annotations.security.SecurityRequirement;

@Path("/api/v1/admin/auth")
@Produces(MediaType.APPLICATION_JSON)
@Consumes(MediaType.APPLICATION_JSON)
public class AuthResource implements IAuthResource {
  @Inject IAuthService service;

  @POST
  @Path("login")
  @Operation(summary = "Log in as administrator; first login creates an account only with the configured staff bootstrap token",
      description = "Returns 201 for a new administrator or 200 for an existing administrator. First account creation requires the existing ADMIN_TOKEN bearer; later logins use email/password. Passwords require 12–128 characters.")
  public Response login(LoginRequest request, @HeaderParam("Authorization") String authorization) {
    var result = service.login(request, authorization);
    return Response.status(result.created() ? 201 : 200).header("Cache-Control", "no-store").entity(result).build();
  }

  @GET
  @Path("me")
  @SecurityRequirement(name = "BearerAuth")
  @Operation(summary = "Get the signed-in administrator")
  public Response me(@HeaderParam("Authorization") String authorization) {
    return Response.ok(service.me(authorization)).header("Cache-Control", "no-store").build();
  }

  @POST
  @Path("logout")
  @SecurityRequirement(name = "BearerAuth")
  @Operation(summary = "Revoke this login session")
  public Response logout(@HeaderParam("Authorization") String authorization) {
    service.logout(authorization);
    return Response.noContent().header("Cache-Control", "no-store").build();
  }
}
