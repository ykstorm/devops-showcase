FROM alpine/helm:3.14.0
WORKDIR /app
COPY . .
CMD ["echo", "stackup — use makefile targets: make up/down/smoke/lint"]
