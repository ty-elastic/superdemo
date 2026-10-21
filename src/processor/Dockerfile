FROM maven:3-eclipse-temurin-25 AS build  
COPY src /usr/src/app/src  
COPY pom.xml /usr/src/app
WORKDIR /usr/src/app
RUN mvn package -Dmaven.test.skip

FROM eclipse-temurin:25

RUN apt update && apt install -y wget 

WORKDIR /usr/src/app

COPY --from=build /usr/src/app/target/processor-0.0.1-SNAPSHOT.jar /processor.jar

ARG EDOT_VERSION=1.13.0
RUN wget -O elastic-otel-javaagent.jar https://repo1.maven.org/maven2/co/elastic/otel/elastic-otel-javaagent/$EDOT_VERSION/elastic-otel-javaagent-$EDOT_VERSION.jar 

ENV BOOTSTRAP_SERVER=""
ENV IN_TOPIC=""
ENV IN_GROUP=""
ENV OUT_TOPIC=""
ENV NOTIFIER_ENDPOINT=""

#ENV OTEL_SERVICE_NAME=processor
ENV OTEL_RESOURCE_ATTRIBUTES="service.version=1.0"
ENV OTEL_EXPORTER_OTLP_ENDPOINT=http://opentelemetry-kube-stack-daemon-collector.opentelemetry-operator-system.svc.cluster.local:4318
ENV OTEL_JAVA_EXPERIMENTAL_SPAN_ATTRIBUTES_COPY_FROM_BAGGAGE_INCLUDE=*
ENV OTEL_JAVA_EXPERIMENTAL_LOG_ATTRIBUTES_COPY_FROM_BAGGAGE_INCLUDE=*

EXPOSE 9003
ENTRYPOINT java \
-javaagent:elastic-otel-javaagent.jar \
-jar /processor.jar \
--bootstrap_server=${BOOTSTRAP_SERVER} \
--in_topic=${IN_TOPIC} \
--in_group=${IN_GROUP} \
--out_endpoint=${NOTIFIER_ENDPOINT} \
--out_topic=${OUT_TOPIC}

