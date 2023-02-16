job "redis" {
  datacenters = ["dc1"]
  type = "service"

  group "redis" {
    count = 1

    network {
      #mode = "bridge" # Needs root?
      mode = "host"
      port "redis" {
        static = 6379
      }
    }

    task "redis" {
      driver = "docker"

      # Launch as a user besides root so that the start scripts stops trying to chown the mount
      user = "nobody"

      config {
        image = "redis:7.0"
        args = [
          #"--name", "nd-redis",
          "--port", "${NOMAD_PORT_redis}",
          "--save", "60", "1"
        ]
        ports = ["redis"]
        mount {
          type = "bind"
          target = "/data"
          source = "/mnt/persist/redis/nd-redis"
          readonly = false
        }
      }

      constraint {
        attribute = "${meta.cfs}"
        operator = "="
        value = true
      }

      service {
        name = "redis"
        port = "redis"
        tags = [
          "dns-entry"
        ]
      }
    }
  }
}