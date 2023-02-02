job "traefik" {
  datacenters = ["dc1"]
  type = "service"

  group "traefik" {
    count = 1

    network {
      port "http" {
        static = 80
      }
      port "https" {
        static = 443
      }
      port "api" {
        static = 8081
      }
    }

    task "traefik" {
      driver = "docker"

      resources {
      }

      service {
        name = "traefik"
        port = "http"

        check {
          name = "alive"
          type = "tcp"
          port = "http"
          interval = "100s"
          timeout = "10s"
        }
      }

      config {
        image = "traefik:2.4.2"
        network_mode = "host"

        volumes = [
          "local/traefik.toml:/etc/traefik/traefik.toml"
        ]
      }

      template {
        data = <<EOF
[entryPoints]
    [entryPoints.http]
    address = ":{{env "NOMAD_PORT_http"}}"
    [entryPoints.https]
    address = ":{{env "NOMAD_PORT_https"}}"
    [entryPoints.traefik]
    address = ":{{env "NOMAD_PORT_api"}}"

[certificateResolvers.le.acme]
    email = "arelius@gmail.com"
    storage = "acme.json"
    caServer = "https://acme-v02.api.letsencrypt.org/directory"
    #caServer = "https://acme-staging-v02.api.letsencrypt.org/directory"
    [certificateResolvers.le.acme.dnsChallenge]
    provider = "route53"


[api]
    dashboard = true
    insecure = true

[providers.consulCatalog]
    prefix = "traefik"
    exposedByDefault = false

    [providers.consulCatalog.endpoint]
    address = "127.0.0.1:8500"
    scheme = "http"

EOF
        destination = "local/traefik.toml"
      }

      template {
        data = <<EOH
AWS_ACCESS_KEY_ID={{key "dnsmasq/aws/access_key"}}
AWS_SECRET_ACCESS_KEY={{key "dnsmasq/aws/secret_key"}}
AWS_REGION=us-west-1
AWS_HOSTED_ZONE_ID=Z32ZTTO2MKJRE3
EOH

        destination = "secrets/file.env"
        env = true
      }
    }

    task "updatedns" {
      template {
        data = <<EOH
{
    "Changes" : [
        {
            "Action" : "UPSERT",
            "ResourceRecordSet" : {
                "Name" : "traefik.home.nd.gl.",
                "Type" : "A",
                "TTL" : 30,
                "ResourceRecords" : [
                    {
                        "Value" : "{{ env "NOMAD_IP_http" }}"
                    }
                ]
            }
        }
    ]
}
EOH
        destination = "aws/recordupdate.json"
      }

      template {
        data = <<EOH
AWS_ACCESS_KEY_ID={{key "dnsmasq/aws/access_key"}}
AWS_SECRET_ACCESS_KEY={{key "dnsmasq/aws/secret_key"}}
AWS_DEFAULT_REGION=us-west-1
EOH

        destination = "secrets/file.env"
        env = true
      }

      lifecycle {
        hook = "prestart"
        sidecar = false
      }

      driver = "docker"
      config {
        image = "scatteredray/aws-cli:arm"
        args = ["route53", "change-resource-record-sets", "--hosted-zone-id", "Z32ZTTO2MKJRE3", "--change-batch", "file://recordupdate.json"]

        volumes = [
          "aws:/aws"
        ]
      }
    }
  }
}
