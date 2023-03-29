job "hoppscotch" {
  datacenters = ["dc1"]
  type = "service"

  group "hoppscotch" {
    count = 1

    network {
      port "http" { to = 3000 }
    }

    service {
      name = "hoppscotch"
      port = "http"
      tags = [
        "traefik.enable=true",
        "traefik.http.routers.hoppscotch.rule=Host(\"hoppscotch.home.nd.gl\")",
        "traefik.http.routers.hoppscotch.service=hoppscotch@consulcatalog"
      ]
    }

    task "hoppscotch" {
      driver = "docker"

      config {
        image = "hoppscotch/hoppscotch:latest"
        args = [
        ]
        ports = ["http"]
      }

    }

      # TODO: move this into the updatedns job based on tags.
      task "updatedns" {
      template {
        data = <<EOH
{
    "Changes" : [
        {
            "Action" : "UPSERT",
            "ResourceRecordSet" : {
                "Name" : "hoppscotch.home.nd.gl.",
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
        image = "public.ecr.aws/aws-cli/aws-cli:2.11.6"
        args = ["route53", "change-resource-record-sets", "--hosted-zone-id", "Z32ZTTO2MKJRE3", "--change-batch", "file://recordupdate.json"]

        volumes = [
          "aws:/aws"
        ]
      }
    }
  }
}