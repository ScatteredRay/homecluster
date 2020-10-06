job "homeddns" {
    datacenters = ["dc1"]
    type = "batch"

    periodic {
        cron = "@hourly"
    }

    group "dns" {
        count = 1

        task "updatedns" {
            template {
                data = <<EOH
{
    "Changes" : [
        {
            "Action" : "UPSERT",
            "ResourceRecordSet" : {
                "Name" : "home.nd.gl.",
                "Type" : "A",
                "TTL" : 30,
                "ResourceRecords" : [
                    {
                        "Value" : "__DNS_ADDRESS__"
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
                entrypoint = ["/bin/sh"]
                args = ["-c", "apk --no-cache add curl sed && sed -i s/__DNS_ADDRESS__/$(curl -sf http://checkip.amazonaws.com/)/g recordupdate.json && aws route53 change-resource-record-sets --hosted-zone-id Z32ZTTO2MKJRE3 --change-batch file://recordupdate.json"]

                volumes = [
                    "aws:/aws"
                ]
            }
        }
    }
}
