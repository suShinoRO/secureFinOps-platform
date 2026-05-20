FROM eclipse-temurin:21-jdk-alpine AS builder
WORKDIR /app
COPY pom.xml .
COPY src ./src
RUN apk add --no-cache maven && mvn clean package -DskipTests

FROM eclipse-temurin:21-jre-alpine
WORKDIR /app

RUN addgroup -S appgroup && adduser -S appuser -G appgroup

RUN mkdir -p /tmp/app && chown -R appuser:appgroup /tmp/app

USER appuser

COPY --from=builder /app/target/*.jar app.jar

ENV JAVA_OPTS="-Djava.io.tmpdir=/tmp/app \
               -Dserver.tomcat.basedir=/tmp/app \
               -XX:+UseContainerSupport \
               -XX:MaxRAMPercentage=75.0"

EXPOSE 8080

ENTRYPOINT ["sh", "-c", "java $JAVA_OPTS -jar app.jar"]