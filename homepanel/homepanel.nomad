job "homepanel" {
  datacenters = ["dc1"]
  type = "service"

  group "homepanel" {
    count = 1

    service {
      name = "homepanel"
      tags = [
        "traefik.enable=true",
        "traefik.http.routers.homepanel.rule=PathPrefix(`/`)",
        "traefik.http.routers.homepanel.middlewares=homepanel-redirect@consulcatalog",
        "traefik.http.routers.homepanel.service=noop@internal",
        "traefik.http.middlewares.homepanel-redirect.redirectregex.regex=.*",
        "traefik.http.middlewares.homepanel-redirect.redirectregex.replacement=http://hubitat.home.nd.gl/apps/api/4/dashboard/75?access_token=c32a2bae-5a60-467b-9ed1-c33d893ee207&local=true",
      ]
    }

    task "noop" {
      driver = "exec"
    }
  }
}
