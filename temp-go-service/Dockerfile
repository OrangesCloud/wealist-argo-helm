FROM alpine:latest
RUN apk add --no-cache curl
EXPOSE 8081
RUN mkdir -p /health
RUN echo '{"status":"ok"}' > /health/live
RUN echo '{"status":"ok"}' > /health/ready
CMD ["sh", "-c", "while true; do echo 'Go service running...'; sleep 30; done"]