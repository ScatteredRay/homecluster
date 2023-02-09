job "grafana" {
  datacenters = ["dc1"]
  type = "service"

  group "grafana" {
    count = 1

    network {
      mode = "host"
      port "grafana" {}
    }

    task "grafana" {
      driver = "docker"

      env {
        GF_INSTALL_PLUGINS = "grafana-clock-panel"
        GF_PATHS_PROVISIONING = "/config/provisioning"
      }

      config {
        image = "grafana/grafana-oss:9.3.6"
        args = [
          "--config", "/config/grafana-config.ini"
        ]

        ports = ["grafana"]

        mount {
          type = "bind"
          source = "local/grafana-config.ini"
          target = "/config/grafana-config.ini"
          readonly = true
        }

        mount {
          type = "bind"
          source = "local/loki.yml"
          target = "/config/provisioning/datasources/loki.yml"
          readonly = true
        }

        #mount {
        #  type = "bind"
        #  source = "/mnt/cfs/grafana"
        #  target = "/data"
        #  readonly = false
        #}

        volumes = [
          "/mnt/cfs/grafana:/data" # Volumes are created by the docker daemon
        #  "local/grafana-config.ini:/config/grafana-config.ini"
        ]
      }

      constraint {
        attribute = "${meta.cfs}"
        operator = "="
        value = true
      }

#[security]
#admin_user = {{key "security/admin/email"}}
      template {
        data = <<EOF
[server]
http_port = {{env "NOMAD_PORT_grafana"}}

[auth.anonymous]
enabled = true
#org_role = Viewer
org_role = Admin

[database]
type = sqlite3
path = /data/grafana.sqlite
EOF
        destination = "local/grafana-config.ini"
      }

      template {
        data = <<EOF
apiVersion: 1

datasources:
{{range service "loki"}}
  - name: {{.Name}}_{{.ID}}
    type: loki
    access: proxy
    url: http://{{.Address}}:{{.Port}}
    jsonData:
      maxLines: 1000
{{end}}
EOF
        destination = "local/loki.yml"
      }
    }
  }

  group "loki" {
    count = 1

    network {
      mode = "host"
      port "http" {}
      port "grpc" {}
    }

    service {
      name = "loki"
      address_mode = "host"
      tags = ["loki"]
      port = "http"
    }

    task "loki" {
      driver = "docker"

      config {
        image = "grafana/loki:2.7.3"

        args = [
          "-config.file=/config/loki-config.yaml",
          "-print-config-stderr"
        ]

        ports = ["http", "grpc"]

        mount {
          type = "bind"
          source = "local/loki-config.yaml"
          target = "/config/loki-config.yaml"
          readonly = true
        }

        volumes = [
          "/mnt/cfs/loki:/loki" # Volumes are created by the docker daemon
        ]
      }


      template {
        data = <<EOF
auth_enabled: false

server:
  http_listen_port: {{env "NOMAD_PORT_http"}}
  grpc_listen_port: {{env "NOMAD_PORT_grpc"}}

common:
  path_prefix: /loki
  storage:
    filesystem:
      chunks_directory: /loki/chunks
      rules_directory: /loki/rules
  replication_factor: 1
  ring:
    kvstore:
      store: inmemory

query_range:
  results_cache:
    cache:
      embedded_cache:
        enabled: true
        max_size_mb: 100

schema_config:
  configs:
  - from: 2023-01-01
    store: boltdb-shipper
    object_store: filesystem
    schema: v11
    index:
      prefix: index_
      period: 24h

analytics:
  reporting_enabled: false
EOF
        destination = "local/loki-config.yaml"
      }
    }

    constraint {
      attribute = "${meta.cfs}"
      operator = "="
      value = true
    }
  }
}