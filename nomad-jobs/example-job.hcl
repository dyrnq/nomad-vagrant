job "example-job" {
  # A group defines a series of tasks that should be co-located
  # on the same client (host). All tasks within a group will be
  # placed on the same host.

  # Specify this job should run in the region named "us". Regions
  # are defined by the Nomad servers' configuration.
  #region = "us"

  # Spread the tasks in this job between us-west-1 and us-east-1.
  datacenters = ["dc1"]

  # Run this job as a "service" type. Each job type has different
  # properties. See the documentation below for more examples.
  type = "service"

  # Specify this job to have rolling updates, two-at-a-time, with
  # 30 second intervals.
  update {
    stagger      = "30s"
    max_parallel = 1
  }

  # A group defines a series of tasks that should be co-located
  # on the same client (host). All tasks within a group will be
  # placed on the same host.
  group "example-group" {
    # Specify the number of these tasks we want.
    count = 3

    # Create an individual task (unit of work). This particular
    # task utilizes a Docker container to front a web application.
    task "example-task" {
      # Specify the driver to be "exec". Nomad supports
      # multiple drivers.

      driver = "exec"

      config {
        command = "python3"
        args    = [
            "-m",
            "http.server",
            "--bind", 
            "0.0.0.0"
            ]
      }



      # The service block tells Nomad how to register this service
      # with Consul for service discovery and monitoring.
      service {
        # This tells Consul to monitor the service on the port
        # labelled "http". Since Nomad allocates high dynamic port
        # numbers, we use labels to refer to them.
        port = "http"
        address_mode = "host"
        check {
          type     = "http"
          path     = "/"
          interval = "10s"
          timeout  = "2s"
        }
      }

      # Specify the maximum resources required to run the task,
      # include CPU, memory, and bandwidth.
    //   resources {
    //     cpu    = 500 # MHz
    //     memory = 128 # MB
    //   }
    }

    network {
        port "http" {
            static = 8000
        }
    }

  }
}
