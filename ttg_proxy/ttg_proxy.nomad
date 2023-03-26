job "ttg_proxy" {
  datacenters = ["dc1"]
  type = "service"

  group "proxy" {
    count = 1

    network {
      mode = "host"
      port "socks" {
        static = 8888
      }
    }

    task "proxy" {
      driver = "docker"

      config {
        image = "${REGISTRY_ADDR}:${REGISTRY_PORT}/nd/openssh:latest"

        args = [
          "/bin/ssh",
          "-tt",
          "-vv",
          "-o", "StrictHostKeyChecking=no",
          "-i",
          "/ttg_admin.pem",
          "-D",
          "0.0.0.0:${NOMAD_PORT_socks}",
          "admin@192.168.20.1"
        ]

        ports = ["socks"]

        mount {
          type = "bind"
          source = "local/ttg_admin.pem"
          target = "/ttg_admin.pem"
          readonly = true
        }
      }

      service {
        name = "ttgproxy"
        port = "socks"
        tags = [
          "dns-entry"
        ]

        check {
          name = "alive"
          type = "tcp"
          port = "socks"
          interval = "100s"
          timeout = "10s"
        }

      }

      template {
        data = <<EOF
{{key "ttg_admin/pem"}}
EOF
        destination = "local/ttg_admin.pem"
        perms = "600"
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
    }
  }
}