job "dnsmasq" {
    datacenters = ["dc1"]
    type = "service"

    group "dns" {
        count = 1

        network {
          port "dns" {
            static = 53
            to = 53
          }
        }

        task "dnsmasq" {
            driver = "docker"
            config {
                image = "scatteredray/dnsmasq:arm"
                args = ["--server=/consul/${NOMAD_IP_dns}#8600"]
           }

            resources {
            }

           service {
               name = "dnsmasq"
               address_mode = "host"
               tags = ["dnsmasq"]
               port = "dns"
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
                "Name" : "dns.home.nd.gl.",
                "Type" : "A",
                "TTL" : 30,
                "ResourceRecords" : [
                    {
                        "Value" : "{{env "NOMAD_IP_dns"}}"
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

        # task "avahi" {
        #     driver = "raw_exec"

        #     config {
        #         command = "/usr/bin/avahi-publish"
        #         args = ["-v", "-s", "DNS service", "_dns._tcp", "53"]

        #     }
        # }
    }
}

