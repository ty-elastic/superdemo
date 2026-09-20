FROM maven:3-eclipse-temurin-25 AS build  
COPY src /usr/src/app/src 
COPY pom.xml /usr/src/app

WORKDIR /usr/src/app
RUN --mount=type=cache,target=/root/.m2 mvn package -Dmaven.test.skip

FROM eclipse-temurin:25

WORKDIR /usr/src/app

COPY --from=build /usr/src/app/target/recorder-0.0.1-SNAPSHOT.jar /usr/src/app/recorder.jar

EXPOSE 9003
ENTRYPOINT ["java", "-jar", "/usr/src/app/recorder.jar"]
