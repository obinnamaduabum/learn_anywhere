package com.learnanywhere.resource;

import com.fasterxml.jackson.databind.JsonNode;
import com.learnanywhere.domain.Models.ApprovalRequest;
import com.learnanywhere.domain.Models.CourseRequest;
import com.learnanywhere.domain.Models.DraftRequest;
import com.learnanywhere.domain.Models.Installation;
import com.learnanywhere.domain.Models.SyncRequest;
import com.learnanywhere.domain.Models.SyncResponse;
import com.learnanywhere.service.ILearningService;
import com.learnanywhere.service.LearningService;
import jakarta.inject.Inject;
import jakarta.ws.rs.Consumes;
import jakarta.ws.rs.DefaultValue;
import jakarta.ws.rs.GET;
import jakarta.ws.rs.HeaderParam;
import jakarta.ws.rs.POST;
import jakarta.ws.rs.Path;
import jakarta.ws.rs.PathParam;
import jakarta.ws.rs.Produces;
import jakarta.ws.rs.QueryParam;
import jakarta.ws.rs.core.MediaType;
import jakarta.ws.rs.core.Response;
import java.util.Map;
import org.eclipse.microprofile.openapi.annotations.Operation;
import org.eclipse.microprofile.openapi.annotations.enums.SecuritySchemeType;
import org.eclipse.microprofile.openapi.annotations.media.Content;
import org.eclipse.microprofile.openapi.annotations.media.Schema;
import org.eclipse.microprofile.openapi.annotations.responses.APIResponse;
import org.eclipse.microprofile.openapi.annotations.security.SecurityRequirement;
import org.eclipse.microprofile.openapi.annotations.security.SecurityScheme;

@Path("/api/v1")
@Produces(MediaType.APPLICATION_JSON)
@Consumes(MediaType.APPLICATION_JSON)
@SecurityScheme(
    securitySchemeName = "BearerAuth",
    type = SecuritySchemeType.HTTP,
    scheme = "bearer")
public class LearningResource implements ILearningResource {
  @Inject ILearningService service;

  @POST
  @Path("course-requests")
  @Operation(summary = "Request human content or generate a reviewable AI course; 3 AI requests per day per installation")
  @SecurityRequirement(name = "BearerAuth")
  public Response requestCourse(@HeaderParam("Authorization") String auth, CourseRequest request) {
    return Response.status(202).entity(service.requestCourse(auth,request)).build();
  }

  @POST
  @Path("course-requests/status")
  @Operation(summary = "Check this installation's requested courses and review status")
  @SecurityRequirement(name = "BearerAuth")
  public Response requests(@HeaderParam("Authorization") String auth) {
    return Response.ok(service.requests(auth)).build();
  }

  @GET
  @Path("health")
  public Map<String, String> health() {
    return Map.of("status", "ok");
  }

  @POST
  @Path("installations")
  @Operation(summary = "Create anonymous installation")
  @APIResponse(
      responseCode = "201",
      description = "Installation created; token returned once",
      content = @Content(schema = @Schema(implementation = Installation.class)))
  public Response register() {
    return Response.status(201).entity(service.register()).build();
  }

  @GET
  @Path("courses")
  @Operation(
      summary = "Discover normal courses and course series",
      description = "Returns newest-created courses first, with created_at timestamps. Returns type=course for a standalone course and type=series for a parent course. "
          + "Series include an ordered parts array; each part has its own stable id, partIndex, "
          + "lessonCount and language packs. Download and sync using the part id, not the parent id.")
  @APIResponse(responseCode = "200", description = "Course catalog with normal courses and nested series parts")
  public Response courses() {
    return Response.ok(service.courses()).build();
  }

  @GET
  @Path("explanations/{course}/{language}")
  @Operation(summary = "Check availability and download reviewed explanations for an immutable course version",
      description = "Returns available=false if absent; otherwise explanationVersion and an explanation for each lesson ID. No AI request is made.")
  public JsonNode explanations(@PathParam("course") String course, @PathParam("language") String language,
      @QueryParam("version") @DefaultValue("1") int version) {
    return service.explanations(course, version, language);
  }

  @GET
  @Path("packs/{course}/{language}")
  @Operation(summary = "Download versioned offline language pack")
  public Response pack(
      @PathParam("course") String course,
      @PathParam("language") String language,
      @QueryParam("version") @DefaultValue("1") int version,
      @HeaderParam("If-None-Match") String etag) {
    var p = service.pack(course, version, language);
    String tag = "\"" + p.hash() + "\"";
    if (tag.equals(etag)) return Response.status(304).header("ETag", tag).build();
    return Response.ok(p.bytes(), MediaType.APPLICATION_JSON).header("ETag", tag).build();
  }

  @POST
  @Path("progress/restore")
  @Operation(summary = "Retrieve this installation's confirmed progress without changing it")
  @SecurityRequirement(name = "BearerAuth")
  public Response restore(@HeaderParam("Authorization") String auth) {
    return Response.ok(service.progress(auth)).build();
  }

  @POST
  @Path("progress/sync")
  @Operation(summary = "Synchronize offline events and confirm points")
  @APIResponse(
      responseCode = "200",
      description = "Committed event acknowledgement and confirmed points",
      content = @Content(schema = @Schema(implementation = SyncResponse.class)))
  @SecurityRequirement(name = "BearerAuth")
  public Response sync(@HeaderParam("Authorization") String auth, SyncRequest request) {
    if (request == null)
      throw LearningService.invalid("Request required");
    return Response.ok(service.sync(auth, request)).build();
  }

  @POST
  @Path("admin/drafts")
  @Operation(summary = "Import topic-based AI content for review")
  @SecurityRequirement(name = "BearerAuth")
  public Response importDraft(@HeaderParam("Authorization") String auth, DraftRequest request) {
    if (request == null)
      throw LearningService.invalid("Request required");
    return Response.status(201)
        .entity(Map.of("draftId", service.importDraft(auth, request), "status", "draft"))
        .build();
  }

  @GET
  @Path("admin/drafts/{id}")
  @Operation(summary = "Inspect draft content before approval")
  @SecurityRequirement(name = "BearerAuth")
  public Response draft(@HeaderParam("Authorization") String auth, @PathParam("id") long id) {
    return Response.ok(service.draft(auth, id)).build();
  }

  @POST
  @Path("admin/drafts/{id}/approve")
  @Operation(summary = "Explicitly approve and publish a reviewed draft")
  @SecurityRequirement(name = "BearerAuth")
  public Response approve(
      @HeaderParam("Authorization") String auth,
      @PathParam("id") long id,
      ApprovalRequest request) {
    if (request == null)
      throw LearningService.invalid("Request required");
    service.approve(auth, id, request);
    return Response.ok(Map.of("status", "approved")).build();
  }
  @POST
  @Path("admin/explanations")
  @SecurityRequirement(name = "BearerAuth")
  @Operation(summary = "Save a draft explanation version for an existing course pack")
  public Response importExplanationDraft(@HeaderParam("Authorization") String auth, JsonNode payload) {
    return Response.status(201).entity(Map.of("draftId",service.importExplanationDraft(auth,payload),"status","draft")).build();
  }

  @GET
  @Path("admin/explanations/{id}")
  @SecurityRequirement(name = "BearerAuth")
  @Operation(summary = "Review a saved explanation draft")
  public Response explanationDraft(@HeaderParam("Authorization") String auth, @PathParam("id") long id) {
    return Response.ok(service.explanationDraft(auth,id)).build();
  }

  @POST
  @Path("admin/explanations/{id}/approve")
  @SecurityRequirement(name = "BearerAuth")
  @Operation(summary = "Publish an explicitly approved explanation version without replacing its course")
  public Response approveExplanation(@HeaderParam("Authorization") String auth, @PathParam("id") long id, JsonNode payload) {
    service.approveExplanation(auth,id,payload);
    return Response.ok(Map.of("status","approved")).build();
  }

}
