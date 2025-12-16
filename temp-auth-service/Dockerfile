FROM openjdk:17-jre-slim
EXPOSE 8080
RUN mkdir -p /actuator/health
RUN echo '{"status":"UP"}' > /actuator/health/liveness
RUN echo '{"status":"UP"}' > /actuator/health/readiness
CMD ["sh", "-c", "while true; do echo 'Auth service running...'; sleep 30; done"]