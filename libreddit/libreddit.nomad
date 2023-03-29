job "libreddit" {
  datacenters = ["dc1"]
  type = "service"

  group "libreddit" {
    count = 1

    network {
      port "http" { to = 8080 }
    }

    service {
      name = "libreddit"
      port = "http"
      tags = [
        "traefik.enable=true",
        "traefik.http.routers.libreddit.rule=Host(\"reddit.home.nd.gl\")",
        "traefik.http.routers.libreddit.service=libreddit@consulcatalog"
      ]
    }

    task "libreddit" {
      driver = "docker"

      config {
        image = "libreddit/libreddit:arm"
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
                "Name" : "reddit.home.nd.gl.",
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