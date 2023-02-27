job "awscli_image" {
  datacenters = ["dc1"]
  type = "batch"

  group "make_image" {
    count = 1

    task "awscli" {
      driver = "docker"

      config {
        image = "gcr.io/kaniko-project/executor"

        args = [
          "--dockerfile", "/workspace/Dockerfile",
          "--insecure",
          "--destination", "${REGISTRY_ADDR}:${REGISTRY_PORT}/nd/aws-cli:latest"
        ]

        mount {
          type = "bind"
          source = "local/Dockerfile"
          target = "/workspace/Dockerfile"
          readonly = true
        }
      }

      template {
        data = <<EOF
{{- range service "registry"}}
REGISTRY_ADDR={{.Address}}
REGISTRY_PORT={{.Port}}
{{end -}}
EOF
        destination = "local/env"
        env = true
      }

      template {
        data = <<EOF
FROM alpine:latest
RUN apk --no-cache add aws-cli

WORKDIR /aws
ENTRYPOINT ["/usr/bin/aws"]
EOF
        destination = "local/Dockerfile"
      }
    }
  }
}