FROM eclipse-temurin:17-jre
WORKDIR /app
COPY --chown=10001:10001 target/quarkus-app/ /app/
USER 10001
EXPOSE 8084
ENTRYPOINT ["java", "-jar", "/app/quarkus-run.jar"]
