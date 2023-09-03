job "netshoot-2" {
    datacenters = ["dc1"]
    type = "service"
    group "netshoot-group" {
        count = 6
        // reschedule {
        //     attempts = 1
        //     interval       = "1h"
        //     delay = "10s"
        //     unlimited      = false
        // }

        task "netshoot-task-1" {
            driver = "containerd-driver"
            config {
                # image = "nicolaka/netshoot"
                # command = "sh"
                # args = ["-c", "while true; do echo 'hello'; sleep 5; done"]
                image ="traefik/whoami"
                args = ["--port", "8080", "verbose"]
            }
            // resources {
            //     cpu = 500
            //     memory = 256
            // }


        }

        service {
            port = "http"
            address_mode = "alloc"
            check {
                address_mode = "alloc"
                type     = "http"
                path     = "/"
                interval = "3s"
                timeout  = "1s"
            }
        }

        network {
            mode = "cni/cbr0"
            port "http" {
                to = 8080
            }
        }
    }
}