job "homepanel" {
  datacenters = ["dc1"]
  type = "service"

  group "homepanel" {
    count = 1

    service {
      name = "homepanel"
      tags = [
        "traefik.enable=true",
        "traefik.http.routers.homepanel.rule=Host(`panel.home.nd.gl`)",
        "traefik.http.routers.homepanel.middlewares=homepanel-redirect@consulcatalog",
        "traefik.http.routers.homepanel.service=noop@internal",
        "traefik.http.middlewares.homepanel-redirect.redirectregex.regex=.*",
        "traefik.http.middlewares.homepanel-redirect.redirectregex.replacement=http://hubitat.home.nd.gl/apps/api/4/dashboard/75?access_token=c32a2bae-5a60-467b-9ed1-c33d893ee207&local=true",
      ]
    }

    task "noop" {
      driver = "exec"

      config {
        command = "sh"
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
                "Name" : "panel.home.nd.gl.",
                "Type" : "CNAME",
                "TTL" : 30,
                "ResourceRecords" : [
                    {
                        "Value" : "traefik.home.nd.gl"
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
