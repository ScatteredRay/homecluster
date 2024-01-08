job "mail_sync" {
  datacenters = ["dc1"]
  type = "batch"

  group "mail_sync" {
    count = 1

    task "mail_sync" {
      driver = "docker"

      config {
        image = "${REGISTRY_ADDR}:${REGISTRY_PORT}/nd/mbsync:latest"

        args = [
          #"/bin/ls", "-laht", "/mail/ishere"
          "/bin/mbsync",
          "--config", "/config/mbsyncrc",
          "--create-near",
          "-a", "-V",
        ]

        mount {
          type = "bind"
          source = "local/mbsync"
          target = "/config/mbsyncrc"
          readonly = true
        }

        volumes = [
          "/mnt/cfs/mailsync:/mail"
        ]
      }

      template {
        data = <<EOF
IMAPAccount ishere
Host mail.ishere.com
User indy@ishere.com
Pass {{key "mailsync/ishere/password"}}

IMAPStore ishere-remote
Account ishere

#MBSync doesn't seem to want to create the path, so need a way to create it.
MaildirStore ishere-local
Path /mail/ishere
Inbox /mail/ishere/Inbox
Subfolders Verbatim

Channel ishere
Far :ishere-remote:
Near :ishere-local:
Create Near
#Sync Pull
Sync PullNew
Expunge None
Remove None
SyncState *

EOF
        destination = "local/mbsync"
      }

      template {
        data = <<EOF
{{- range service "registry"}}
REGISTRY_ADDR={{.Address}}
REGISTRY_PORT={{.Port}}
{{end -}}
EOF
        destination = "local/env"
        env = true
      }
    }
  }
}