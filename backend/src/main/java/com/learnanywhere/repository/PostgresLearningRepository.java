package com.learnanywhere.repository;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ArrayNode;
import com.fasterxml.jackson.databind.node.ObjectNode;
import com.learnanywhere.domain.Models.ApiException;
import com.learnanywhere.domain.Models.ApprovalRequest;
import com.learnanywhere.domain.Models.CourseRequest;
import com.learnanywhere.domain.Models.DraftRequest;
import com.learnanywhere.domain.Models.Event;
import com.learnanywhere.domain.Models.StoredPack;
import com.learnanywhere.domain.Models.SyncRequest;
import com.learnanywhere.domain.Models.SyncResponse;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import java.security.MessageDigest;
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.SQLException;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.UUID;
import java.util.function.BiConsumer;
import javax.sql.DataSource;
import org.apache.commons.codec.binary.Hex;

@ApplicationScoped
public class PostgresLearningRepository implements ILearningRepository {
  @Inject DataSource db;
  @Inject ObjectMapper json;

  @FunctionalInterface
  interface Work<T> {
    T run(Connection c) throws Exception;
  }

  <T> T tx(Work<T> work) {
    try (Connection c = db.getConnection()) {
      c.setAutoCommit(false);
      try {
        try (var settings = c.createStatement()) {
          settings.execute("SET LOCAL synchronous_commit = on");
        }
        T result = work.run(c);
        c.commit();
        return result;
      } catch (Exception | Error e) {
        try {
          c.rollback();
        } catch (SQLException rollbackFailure) {
          e.addSuppressed(rollbackFailure);
        }
        if (e instanceof Error fatal) throw fatal;
        if (e instanceof ApiException a) throw a;
        if (e instanceof SQLException sq && "23505".equals(sq.getSQLState()))
          throw new ApiException(409, "content_conflict", "Release language pack already exists");
        throw new IllegalStateException("Database operation failed", e);
      }
    } catch (SQLException e) {
      throw new IllegalStateException("Database unavailable", e);
    }
  }

  private PreparedStatement sql(Connection c, String query, Object... args) throws SQLException {
    var s = c.prepareStatement(query);
    for (int i = 0; i < args.length; i++) s.setObject(i + 1, args[i]);
    return s;
  }

  public static String hash(byte[] bytes) {
    try {
      return Hex.encodeHexString(MessageDigest.getInstance("SHA-256").digest(bytes));
    } catch (Exception e) {
      throw new IllegalStateException(e);
    }
  }

  public JsonNode reserveRequest(UUID installation, CourseRequest request) {
    return tx(c -> {
      try (var lock = sql(c, "SELECT id FROM installations WHERE id=? FOR UPDATE", installation); var rows = lock.executeQuery()) { rows.next(); }
      try (var existing = sql(c, "SELECT title,language,source,status,draft_id FROM course_requests WHERE id=? AND installation_id=?", UUID.fromString(request.requestId()), installation); var rows = existing.executeQuery()) {
        if (rows.next()) {
          if (!request.title().equals(rows.getString(1)) || !request.language().equals(rows.getString(2)) || !request.source().equals(rows.getString(3)))
            throw new ApiException(409,"request_conflict","Request ID reused with different content");
          var out = json.createObjectNode().put("status",rows.getString(4)).put("requestId",request.requestId()).put("existing",true);
          if (rows.getObject(5) != null) out.put("draftId",rows.getLong(5));
          return out;
        }
      }
      int used = 0;
      try (var count = sql(c, "SELECT count(*) FROM course_requests WHERE installation_id=? AND source='ai' AND created_at >= date_trunc('day', now() AT TIME ZONE 'UTC') AT TIME ZONE 'UTC'", installation); var rows = count.executeQuery()) { rows.next(); used = rows.getInt(1); }
      if (request.source().equals("ai") && used >= 3) throw new ApiException(429,"ai_limit","Daily AI limit reached: 3 requests. Try again after midnight UTC.");
      String status = request.source().equals("ai") ? "queued" : "requested";
      try (var insert = sql(c, "INSERT INTO course_requests(id,installation_id,title,language,source,status) VALUES(?,?,?,?,?,?)", UUID.fromString(request.requestId()),installation,request.title(),request.language(),request.source(),status)) { insert.executeUpdate(); }
      return json.createObjectNode().put("requestId",request.requestId()).put("status",status).put("remaining",request.source().equals("ai") ? 2-used : 3-used);
    });
  }

  public JsonNode claimRequest() {
    return tx(c -> {
      try (var statement = sql(c, "SELECT id,title,language FROM course_requests WHERE source='ai' AND status='queued' ORDER BY created_at FOR UPDATE SKIP LOCKED LIMIT 1"); var rows = statement.executeQuery()) {
        if (!rows.next()) return null;
        var item = json.createObjectNode().put("id",rows.getString(1)).put("title",rows.getString(2)).put("language",rows.getString(3));
        try (var update = sql(c,"UPDATE course_requests SET status='generating' WHERE id=?",UUID.fromString(rows.getString(1)))) { update.executeUpdate(); }
        return item;
      }
    });
  }

  public JsonNode requests(UUID installation) {
    return tx(c -> {
      var items = json.createArrayNode();
      try (var statement = sql(c,"SELECT id,title,source,status,draft_id,created_at FROM course_requests WHERE installation_id=? ORDER BY created_at DESC LIMIT 50",installation); var rows = statement.executeQuery()) {
        while (rows.next()) {
          var item = items.addObject().put("id",rows.getString(1)).put("title",rows.getString(2)).put("source",rows.getString(3)).put("status",rows.getString(4));
          if (rows.getObject(5) != null) {
            item.put("draftId",rows.getLong(5));
            try (var review = sql(c,"SELECT status FROM content_drafts WHERE id=?",rows.getLong(5)); var draft = review.executeQuery()) {
              if (draft.next() && draft.getString(1).equals("approved")) item.put("status","published");
            }
          }
        }
      }
      return json.createObjectNode().set("requests",items);
    });
  }

  public void finishRequest(UUID id, String status, Long draftId) {
    tx(c -> { try (var update = sql(c, "UPDATE course_requests SET status=?,draft_id=? WHERE id=?",status,draftId,id)) { update.executeUpdate(); } return null; });
  }

  public void register(UUID id, byte[] hash) {
    tx(
        c -> {
          try (var s = sql(c, "INSERT INTO installations(id,token_hash) VALUES(?,?)", id, hash)) {
            s.executeUpdate();
          }
          return null;
        });
  }

  public UUID authenticate(byte[] hash) {
    return tx(
        c -> {
          try (var s = sql(c, "SELECT id FROM installations WHERE token_hash=?", hash);
              var r = s.executeQuery()) {
            if (!r.next())
              throw new ApiException(401, "unauthorized", "Invalid installation token");
            return (UUID) r.getObject(1);
          }
        });
  }

  public StoredPack pack(String course, int version, String language) {
    return tx(
        c -> {
          try (var s =
                  sql(
                      c,
                      "SELECT payload FROM language_packs WHERE course_id=? AND version=? AND"
                          + " language=?",
                      course,
                      version,
                      language);
              var r = s.executeQuery()) {
            if (!r.next()) throw new ApiException(404, "not_found", "Pack not found");
            var bytes = r.getBytes(1);
            return new StoredPack(bytes, hash(bytes));
          }
        });
  }

  public JsonNode progress(UUID installation) {
    return tx(c -> {
      var out = json.createObjectNode();
      var items = out.putArray("courses");
      int total = 0;
      try (var statement = sql(c, "SELECT course_id,version,state,points FROM course_progress WHERE installation_id=?", installation);
          var rows = statement.executeQuery()) {
        while (rows.next()) {
          var item = items.addObject();
          item.put("courseId", rows.getString(1));
          item.put("version", rows.getInt(2));
          item.set("state", json.readTree(rows.getString(3)));
          total += rows.getInt(4);
        }
      }
      out.put("confirmedPoints", total);
      return out;
    });
  }

  public List<JsonNode> courses() {
    return tx(
        c -> {
          var courses = new LinkedHashMap<String, ObjectNode>();
          try (var s =
                  sql(
                      c,
                      "SELECT"
                          + " c.id,COALESCE(series.title,c.title),COALESCE(series.description,c.description),r.lesson_count,p.language,p.version,p.review_status,octet_length(p.payload),series.course_id,parent.title,series.part_index,parent.description,COALESCE(parent.created_at,standalone.created_at),COALESCE(series.created_at,standalone.created_at),COALESCE(parent.category,standalone.category)"
                          + " FROM content_units c JOIN course_releases r ON c.id=r.course_id JOIN"
                          + " language_packs p ON p.course_id=r.course_id AND p.version=r.version"
                          + " LEFT JOIN course_series series ON series.part_course_id=c.id"
                          + " LEFT JOIN courses parent ON parent.id=series.course_id"
                          + " LEFT JOIN courses standalone ON standalone.id=c.id"
                          + " WHERE r.version=(SELECT MAX(version) FROM course_releases WHERE"
                          + " course_id=c.id) ORDER BY COALESCE(parent.created_at,standalone.created_at) DESC,COALESCE(series.course_id,c.id),series.part_index,p.language");
              var r = s.executeQuery()) {
            while (r.next()) {
              String id = r.getString(1);
              var item = courses.get(id);
              if (item == null) {
                item = json.createObjectNode();
                item.put("id", id);
                item.put("title", r.getString(2));
                item.put("description", r.getString(3));
                item.put("lessonCount", r.getInt(4));
                item.put("created_at", r.getTimestamp(14).toInstant().toString());
                item.put("category", r.getString(15));
                item.put("seriesCreatedAt", r.getTimestamp(13).toInstant().toString());
                if (r.getString(9) != null) {
                  item.put("seriesId", r.getString(9));
                  item.put("seriesTitle", r.getString(10));
                  item.put("partIndex", r.getInt(11));
                  item.put("seriesDescription", r.getString(12));
                }
                item.putArray("packs");
                courses.put(id, item);
              }
              var pack = ((ArrayNode) item.get("packs")).addObject();
              pack.put("language", r.getString(5));
              pack.put("version", r.getInt(6));
              pack.put("reviewStatus", r.getString(7));
              pack.put("bytes", r.getInt(8));
            }
          }
          var catalog = new LinkedHashMap<String, ObjectNode>();
          for (ObjectNode item : courses.values()) {
            if (!item.has("seriesId")) {
              item.put("type", "course");
              catalog.put(item.path("id").asText(), item);
              continue;
            }
            String parentId = item.path("seriesId").asText();
            ObjectNode parent = catalog.get(parentId);
            if (parent == null) {
              parent = json.createObjectNode();
              parent.put("id", parentId);
              parent.put("type", "series");
              parent.put("category", item.path("category").asText());
              parent.put("created_at", item.path("seriesCreatedAt").asText());
              parent.put("title", item.path("seriesTitle").asText());
              parent.put("description", item.path("seriesDescription").asText());
              parent.put("lessonCount", 0);
              parent.putArray("packs");
              parent.putArray("parts");
              catalog.put(parentId, parent);
            }
            ((ArrayNode) parent.get("parts")).add(item);
            parent.put("lessonCount", parent.path("lessonCount").asInt() + item.path("lessonCount").asInt());
            for (JsonNode pack : item.path("packs")) {
              boolean found = false;
              for (JsonNode existing : parent.path("packs")) {
                if (existing.path("language").equals(pack.path("language"))) found = true;
              }
              if (!found) ((ArrayNode) parent.get("packs")).add(pack);
            }
          }
          for (ObjectNode item : courses.values()) item.remove("seriesCreatedAt");
          return new ArrayList<JsonNode>(catalog.values());
        });
  }

  public SyncResponse sync(UUID id, SyncRequest request, BiConsumer<ObjectNode, Event> apply) {
    return tx(
        c -> {
          try (var s = sql(c, "SELECT id FROM installations WHERE id=? FOR UPDATE", id);
              var r = s.executeQuery()) {
            if (!r.next()) throw new ApiException(401, "unauthorized", "Installation missing");
          }
          ObjectNode state = json.createObjectNode();
          state.putObject("lessons");
          state.putObject("rewards");
          try (var s =
                  sql(
                      c,
                      "SELECT state FROM course_progress WHERE installation_id=? AND course_id=?"
                          + " AND version=?",
                      id,
                      request.courseId(),
                      request.version());
              var r = s.executeQuery()) {
            if (r.next()) state = (ObjectNode) json.readTree(r.getString(1));
          }
          List<String> accepted = new ArrayList<>();
          for (var event : request.events()) {
            var payload = json.createObjectNode();
            payload.put("course", request.courseId());
            payload.put("version", request.version());
            payload.set("event", json.valueToTree(event));
            String digest = hash(json.writeValueAsBytes(payload));
            boolean exists = false;
            try (var s =
                    sql(
                        c,
                        "SELECT digest FROM activity_events WHERE installation_id=? AND event_id=?",
                        id,
                        event.id());
                var r = s.executeQuery()) {
              if (r.next()) {
                exists = true;
                if (!digest.equals(r.getString(1)))
                  throw new ApiException(
                      409, "event_conflict", "Event ID reused with different data");
              }
            }
            if (!exists) {
              apply.accept(state, event);
              try (var s =
                  sql(
                      c,
                      "INSERT INTO"
                          + " activity_events(installation_id,event_id,course_id,version,digest,payload)"
                          + " VALUES(?,?,?,?,?,?::jsonb)",
                      id,
                      event.id(),
                      request.courseId(),
                      request.version(),
                      digest,
                      payload.toString())) {
                s.executeUpdate();
              }
            }
            accepted.add(event.id());
          }
          int points = 0;
          for (var reward : state.get("rewards")) points += reward.asInt();
          try (var s =
              sql(
                  c,
                  "INSERT INTO course_progress(installation_id,course_id,version,state,points)"
                      + " VALUES(?,?,?,?::jsonb,?) ON CONFLICT(installation_id,course_id,version)"
                      + " DO UPDATE SET"
                      + " state=EXCLUDED.state,points=EXCLUDED.points,updated_at=now()",
                  id,
                  request.courseId(),
                  request.version(),
                  state.toString(),
                  points)) {
            s.executeUpdate();
          }
          int total;
          try (var s =
                  sql(
                      c,
                      "SELECT COALESCE(SUM(points),0) FROM course_progress WHERE installation_id=?",
                      id);
              var r = s.executeQuery()) {
            r.next();
            total = r.getInt(1);
          }
          return new SyncResponse(accepted, total, points);
        });
  }

  public long saveDraft(DraftRequest request) {
    return tx(
        c -> {
          try (var s =
                  sql(
                      c,
                      "INSERT INTO content_drafts(course_id,language,provider,model,payload,topics)"
                          + " VALUES(?,?,?,?,?::jsonb,?::jsonb) RETURNING id",
                      request.pack().path("id").asText(),
                      request.pack().path("language").asText(),
                      request.provider(),
                      request.model(),
                      request.pack().toString(),
                      json.writeValueAsString(request.topics()));
              var r = s.executeQuery()) {
            r.next();
            return r.getLong(1);
          }
        });
  }

  public JsonNode draft(long id) {
    return tx(
        c -> {
          try (var s =
                  sql(
                      c,
                      "SELECT payload,status,topics,reviewed_by,reviewed_at FROM content_drafts"
                          + " WHERE id=?",
                      id);
              var r = s.executeQuery()) {
            if (!r.next()) throw new ApiException(404, "not_found", "Draft missing");
            var out = json.createObjectNode();
            out.set("pack", json.readTree(r.getString(1)));
            out.put("status", r.getString(2));
            out.set("topics", json.readTree(r.getString(3)));
            out.put("reviewedBy", r.getString(4));
            out.put("reviewedAt", r.getString(5));
            return out;
          }
        });
  }

  public void approve(long id, ApprovalRequest request) {
    tx(
        c -> {
          ObjectNode pack;
          try (var s =
                  sql(c, "SELECT payload,status FROM content_drafts WHERE id=? FOR UPDATE", id);
              var r = s.executeQuery()) {
            if (!r.next()) throw new ApiException(404, "not_found", "Draft missing");
            if (!r.getString(2).equals("draft"))
              throw new ApiException(409, "draft_conflict", "Only pending drafts may be approved");
            pack = (ObjectNode) json.readTree(r.getString(1));
          }
          String course = pack.path("id").asText();
          int version = pack.path("version").asInt();
          // Serialize first publication and translations, even when no release exists yet.
          try (var lock = sql(c, "SELECT pg_advisory_xact_lock(hashtextextended(?, 0))",
              course + ":" + version); var ignored = lock.executeQuery()) {
            ignored.next();
          }
          try (var check =
                  sql(
                      c,
                      "SELECT payload FROM language_packs WHERE course_id=? AND version=? LIMIT 1",
                      course,
                      version);
              var r = check.executeQuery()) {
            if (r.next()) {
              JsonNode base = json.readTree(r.getBytes(1));
              if (base.path("lessons").size() != pack.path("lessons").size())
                throw new ApiException(422, "translation_mismatch", "Lesson counts differ");
              for (int i = 0; i < base.path("lessons").size(); i++) {
                JsonNode a = base.path("lessons").get(i), b = pack.path("lessons").get(i);
                if (!a.path("id").equals(b.path("id"))
                    || a.path("questions").size() != b.path("questions").size())
                  throw new ApiException(
                      422, "translation_mismatch", "Lesson/question structure differs");
                for (int j = 0; j < a.path("questions").size(); j++) {
                  JsonNode x = a.path("questions").get(j), y = b.path("questions").get(j);
                  if (!x.path("id").equals(y.path("id"))
                      || !x.path("correct").equals(y.path("correct"))
                      || x.path("options").size() != y.path("options").size())
                    throw new ApiException(
                        422, "translation_mismatch", "Question IDs and answer ordering must match");
                }
              }
            }
          }
          pack.put("reviewStatus", "reviewed");
          try (var s =
              sql(
                  c,
                  "INSERT INTO content_units(id,title,description) VALUES(?,?,?) ON CONFLICT DO NOTHING",
                  course,
                  request.title(),
                  request.description())) {
            s.executeUpdate();
          }
          try (var s = sql(c,
              "INSERT INTO courses(id,title,description,category) SELECT ?,?,?,? WHERE NOT EXISTS"
                  + " (SELECT 1 FROM course_series WHERE part_course_id=?) ON CONFLICT DO NOTHING",
              course, request.title(), request.description(),
              request.category() == null ? "General Learning" : request.category().trim(), course)) {
            s.executeUpdate();
          }
          try (var s =
              sql(
                  c,
                  "INSERT INTO course_releases(course_id,version,lesson_count) VALUES(?,?,?) ON"
                      + " CONFLICT DO NOTHING",
                  course,
                  version,
                  pack.path("lessons").size())) {
            s.executeUpdate();
          }
          try (var s =
              sql(
                  c,
                  "INSERT INTO language_packs(course_id,version,language,review_status,payload)"
                      + " VALUES(?,?,?,'reviewed',?)",
                  course,
                  version,
                  pack.path("language").asText(),
                  json.writeValueAsBytes(pack))) {
            s.executeUpdate();
          }
          try (var s =
              sql(
                  c,
                  "UPDATE content_drafts SET status='approved',reviewed_by=?,reviewed_at=now()"
                      + " WHERE id=?",
                  request.reviewer(),
                  id)) {
            s.executeUpdate();
          }
          return null;
        });
  }
  public long saveExplanationDraft(JsonNode payload) {
    return tx(c -> {
      try (var statement = sql(c, "INSERT INTO explanation_versions(course_id,course_version,language,explanation_version,payload) VALUES(?,?,?,?,?::jsonb) RETURNING id",
          payload.path("courseId").asText(), payload.path("courseVersion").asInt(), payload.path("language").asText(),
          payload.path("explanationVersion").asInt(), json.writeValueAsString(payload)); var rows = statement.executeQuery()) {
        rows.next(); return rows.getLong(1);
      }
    });
  }

  public JsonNode explanationDraft(long id) {
    return tx(c -> {
      try (var statement = sql(c, "SELECT payload,status,reviewed_by FROM explanation_versions WHERE id=?", id); var rows = statement.executeQuery()) {
        if (!rows.next()) throw new ApiException(404,"not_found","Explanation draft missing");
        ObjectNode result = json.createObjectNode();
        result.set("payload", json.readTree(rows.getString(1)));
        result.put("status", rows.getString(2)); result.put("reviewedBy", rows.getString(3));
        return result;
      }
    });
  }

  public void approveExplanation(long id, String reviewer) {
    tx(c -> {
      try (var statement = sql(c, "UPDATE explanation_versions SET status='approved',reviewed_by=?,reviewed_at=now() WHERE id=? AND status='draft'", reviewer, id)) {
        if (statement.executeUpdate() != 1) throw new ApiException(409,"draft_conflict","Only pending explanation drafts may be approved");
      }
      return null;
    });
  }

  public JsonNode approvedExplanations(String course, int version, String language) {
    return tx(c -> {
      try (var statement = sql(c, "SELECT payload FROM explanation_versions WHERE course_id=? AND course_version=? AND language=? AND status='approved' ORDER BY explanation_version DESC LIMIT 1",
          course, version, language); var rows = statement.executeQuery()) {
        return rows.next() ? json.readTree(rows.getString(1)) : null;
      }
    });
  }

}
