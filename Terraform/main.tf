#docker rm -f $(docker ps -a -q)
#terraform console
#curl -L  http://127.0.0.1:1080 ; curl -L  http://127.0.0.1:2080

resource "docker_image" "nginx" {
  name         = var.containers.nginx.image
  keep_locally = true
}

resource "docker_image" "wordpress" {
  name         = var.containers.wordpress.image
  keep_locally = true
}

resource "docker_container" "nginx" {
  image = docker_image.nginx.image_id
  name  = "my-project-${var.containers.nginx.name}"

  ports {
    internal = var.containers.nginx.ports.internal
    external = var.containers.nginx.ports.external
  }
  network_mode = "bridge"
}

resource "docker_container" "wordpress" {
  image = docker_image.wordpress.image_id
  name  = "my-project-${var.containers.wordpress.name}"

  ports {
    internal = var.containers.wordpress.ports.internal
    external = var.containers.wordpress.ports.external
  }
  network_mode = "bridge"
}

resource "random_password" "any_uniq_name" {
  length = 16
}

resource "local_file" "xxx" {
  content  = "my-project-${random_password.any_uniq_name.result}"
  filename = "/tmp/xxx.txt"
}

data "local_file" "from_resourse" {

  filename = "/etc/passwd"
}
