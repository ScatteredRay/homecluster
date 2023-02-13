job "consuldns" {
  datacenters = ["dc1"]
  type = "service"

  meta {
    run_uuid = "${uuidv4()}" # Force re-run
  }

  group "updatedns" {
    count = 1

    task "noop" {
      driver = "docker"

      config {
        image = "alpine:3.17.2"
        command = "/bin/ash"
        args = [
          "-c",
          "while true; do sleep 3600; done"
        ]
      }
    }

    task "updatedns" {
      template {
        data = <<EOF
{
    "Changes" : [
{{$index := 0 -}}
{{range services}}{{if .Tags | contains "dns-entry" -}}
{{if gt $index 0}},{{end}}
{{$index = add $index 1 -}}
{{range service .Name -}}
        {
            "Action" : "UPSERT",
            "ResourceRecordSet" : {
                "Name" : "{{.Name}}.services.home.nd.gl.",
                "Type" : "A",
                "TTL" : 30,
                "ResourceRecords" : [
                    {
                        "Value" : "{{.Address}}"
                    }
                ]
            }
        }{{end -}}
{{end}}{{end -}}
    ]
}
EOF
        destination = "aws/recordupdate.json"
        change_mode = "restart"
      }

      template {
        data = <<EOF
AWS_ACCESS_KEY_ID={{key "dnsmasq/aws/access_key"}}
AWS_SECRET_ACCESS_KEY={{key "dnsmasq/aws/secret_key"}}
AWS_DEFAULT_REGION=us-west-1
EOF

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
