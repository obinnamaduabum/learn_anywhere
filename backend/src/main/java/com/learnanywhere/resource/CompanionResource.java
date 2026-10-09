package com.learnanywhere.resource;
import com.fasterxml.jackson.databind.JsonNode;
import com.learnanywhere.service.ILearningCompanion;
import com.learnanywhere.service.ILearningCompanion.CompanionRequest;
import jakarta.inject.Inject;
import jakarta.ws.rs.Consumes;
import jakarta.ws.rs.HeaderParam;
import jakarta.ws.rs.POST;
import jakarta.ws.rs.Path;
import jakarta.ws.rs.Produces;
import jakarta.ws.rs.core.MediaType;
import org.eclipse.microprofile.openapi.annotations.Operation;
import org.eclipse.microprofile.openapi.annotations.security.SecurityRequirement;
@Path("/api/v1/learning-companion")
@Consumes(MediaType.APPLICATION_JSON)
@Produces(MediaType.APPLICATION_JSON)
public class CompanionResource {
  @Inject ILearningCompanion companion;
  @POST
  @Operation(summary="Optional AI lesson explanation, reflective practice, or reminder suggestions; no learner history is sent to AI")
  @SecurityRequirement(name="BearerAuth")
  public JsonNode assist(@HeaderParam("Authorization") String auth, CompanionRequest request) { return companion.assist(auth,request); }
}
