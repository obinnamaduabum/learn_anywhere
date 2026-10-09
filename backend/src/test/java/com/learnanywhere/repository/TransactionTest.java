package com.learnanywhere.repository;

import com.learnanywhere.domain.Models.ApiException;
import java.lang.reflect.Proxy;
import java.sql.Connection;
import java.sql.Statement;
import java.util.ArrayList;
import java.util.List;
import javax.sql.DataSource;
import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;

class TransactionTest {
  private PostgresLearningRepository repository(List<String> calls) {
    Statement settings = (Statement) Proxy.newProxyInstance(getClass().getClassLoader(),
        new Class<?>[] {Statement.class}, (proxy, method, args) -> {
          if (method.getName().equals("execute")) {
            calls.add((String) args[0]);
            return true;
          }
          return null;
        });
    Connection connection = (Connection) Proxy.newProxyInstance(getClass().getClassLoader(),
        new Class<?>[] {Connection.class}, (proxy, method, args) -> {
          if (method.getName().equals("createStatement")) return settings;
          if (method.getName().equals("setAutoCommit")) calls.add("autoCommit:" + args[0]);
          if (method.getName().equals("commit") || method.getName().equals("rollback"))
            calls.add(method.getName());
          return null;
        });
    PostgresLearningRepository repository = new PostgresLearningRepository();
    repository.db = (DataSource) Proxy.newProxyInstance(getClass().getClassLoader(),
        new Class<?>[] {DataSource.class}, (proxy, method, args) -> connection);
    return repository;
  }

  @Test
  void commitsBeforeReturningResult() {
    List<String> calls = new ArrayList<>();
    String result = repository(calls).tx(connection -> {
      calls.add("write");
      return "saved";
    });
    assertEquals("saved", result);
    assertEquals(List.of("autoCommit:false", "SET LOCAL synchronous_commit = on", "write", "commit"), calls);
  }

  @Test
  void rollsBackValidationFailuresWithoutCommit() {
    List<String> calls = new ArrayList<>();
    assertThrows(ApiException.class, () -> repository(calls).tx(connection -> {
      calls.add("write");
      throw new ApiException(409, "conflict", "Conflict");
    }));
    assertEquals(List.of("autoCommit:false", "SET LOCAL synchronous_commit = on", "write", "rollback"), calls);
  }
}
