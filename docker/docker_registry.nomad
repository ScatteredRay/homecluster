job "docker_registry" {
  datacenters = ["dc1"]
  type = "service"

  group "docker_registry" {
    count = 1

    network {
      port "registry" {
        to = 5000
      }
    }

    task "docker_registry" {
      driver = "docker"

      config {
        image = "registry:2.8.1"

        ports = ["registry"]

        volumes = [
          "/mnt/cfs/docker_registry:/var/lib/registry" # Volumes are created by the docker daemon
        ]
      }

      constraint {
        attribute = "${meta.cfs}"
        operator = "="
        value = true
      }

      service {
        name = "registry"
        port = "registry"
        tags = [
          "dns-entry"
        ]
      }
    }
  }
}