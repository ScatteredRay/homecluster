job "dnsmasq" {
    datacenters = ["dc1"]
    type = "service"

    group "dns" {
        count = 1

        task "dnsmasq" {
            driver = "docker"
            config {
                image = "scatteredray/dnsmasq:arm"
                args = ["--server=/consul/${NOMAD_IP_dns}#8600"]
           }

            resources {
                network {
                    port "dns" {
                        static = 53
                        to = 53
                    }
                }
            }

           service {
               name = "dnsmasq"
               address_mode = "host"
               tags = ["dnsmasq"]
               port = "dns"
           }
        }
    }
}
