package com.learnanywhere.repository;

import com.learnanywhere.domain.AuthModels.LoginAttempt;
import com.learnanywhere.domain.AuthModels.User;
import com.learnanywhere.domain.Models.ApiException;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.SQLException;
import java.sql.Timestamp;
import java.time.Instant;
import java.util.UUID;
import java.util.function.Predicate;
import javax.sql.DataSource;

@ApplicationScoped
public class PostgresAuthRepository implements IAuthRepository {
  @Inject DataSource db;

  @FunctionalInterface
  private interface Work<T> { T run(Connection connection) throws SQLException; }

  private <T> T transaction(Work<T> work) {
    try (Connection connection = db.getConnection()) {
      connection.setAutoCommit(false);
      try {
        T value = work.run(connection);
        connection.commit();
        return value;
      } catch (SQLException | RuntimeException failure) {
        connection.rollback();
        if (failure instanceof SQLException sql && "23505".equals(sql.getSQLState())) {
          throw new ApiException(409, "account_conflict", "Administrator account conflict");
        }
        throw failure;
      }
    } catch (SQLException failure) {
      throw new IllegalStateException("Account database operation failed", failure);
    }
  }

  private PreparedStatement sql(Connection connection, String query, Object... values) throws SQLException {
    PreparedStatement statement = connection.prepareStatement(query);
    for (int i = 0; i < values.length; i++) statement.setObject(i + 1, values[i]);
    return statement;
  }

  public LoginAttempt login(String email, String passwordHash, Predicate<String> matches,
      boolean allowCreate, byte[] sessionHash, Instant expiresAt) {
    return transaction(connection -> {
      // Serialize simultaneous first logins so one normalized email creates one user.
      try (var lock = sql(connection, "SELECT pg_advisory_xact_lock(hashtextextended(?, 1))", email);
          var rows = lock.executeQuery()) { rows.next(); }
      UUID userId = null;
      boolean created = false;
      try (var statement = sql(connection,
          "SELECT id,password_hash,failed_logins,locked_until "
              + "FROM admin_users WHERE email=? FOR UPDATE", email); var rows = statement.executeQuery()) {
        if (rows.next()) {
          userId = rows.getObject("id", UUID.class);
          Timestamp locked = rows.getTimestamp("locked_until");
          if (locked != null && locked.toInstant().isAfter(Instant.now())) {
            return new LoginAttempt(null, false, 429);
          }
          if (!matches.test(rows.getString("password_hash"))) {
            int failures = locked == null ? rows.getInt("failed_logins") + 1 : 1;
            Timestamp until = failures >= 10 ? Timestamp.from(Instant.now().plusSeconds(900)) : null;
            try (var update = sql(connection,
                "UPDATE admin_users SET failed_logins=?,locked_until=? WHERE id=?", failures, until, userId)) {
              update.executeUpdate();
            }
            // Return instead of throwing so failed-attempt accounting commits.
            return new LoginAttempt(null, false, 401);
          }
        }
      }
      if (userId == null) {
        if (!allowCreate) {
          matches.test(passwordHash);
          return new LoginAttempt(null, false, 401);
        }
        created = true;
        userId = UUID.randomUUID();
        try (var insert = sql(connection,
            "INSERT INTO admin_users(id,email,password_hash) VALUES(?,?,?)",
            userId, email, passwordHash)) { insert.executeUpdate(); }
      } else {
        try (var update = sql(connection,
            "UPDATE admin_users SET failed_logins=0,locked_until=NULL WHERE id=?", userId)) { update.executeUpdate(); }
      }
      try (var insert = sql(connection,
          "INSERT INTO admin_sessions(token_hash,user_id,expires_at) VALUES(?,?,?)",
          sessionHash, userId, Timestamp.from(expiresAt))) { insert.executeUpdate(); }
      return new LoginAttempt(new User(userId, email), created, 200);
    });
  }

  public User me(byte[] sessionHash) {
    return transaction(connection -> {
      try (var statement = sql(connection,
          "SELECT u.id,u.email FROM admin_sessions s JOIN admin_users u ON u.id=s.user_id "
              + "WHERE s.token_hash=? AND s.expires_at>now()", sessionHash);
          var rows = statement.executeQuery()) {
        if (!rows.next()) throw new ApiException(401, "unauthorized", "Invalid or expired session");
        return new User(rows.getObject("id", UUID.class), rows.getString("email"));
      }
    });
  }

  public void logout(byte[] sessionHash) {
    transaction(connection -> {
      try (var statement = sql(connection, "DELETE FROM admin_sessions WHERE token_hash=?", sessionHash)) {
        statement.executeUpdate();
      }
      return null;
    });
  }
}
