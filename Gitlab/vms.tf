data "yandex_compute_image" "ubuntu_2204_lts" {
  family = "ubuntu-2204-lts"
}

# ВМ для GitLab: 2 vCPU, 8 GB RAM
resource "yandex_compute_instance" "gitlab" {
  name        = "gitlab-ce"
  hostname    = "gitlab-ce"
  platform_id = "standard-v3"
  zone        = "ru-central1-a"

  resources {
    cores         = 4
    memory        = 8
    core_fraction = 20
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.ubuntu_2204_lts.image_id
      type     = "network-hdd"
      size     = 30
    }
  }

  metadata = {
    user-data          = file("./cloud-init.yml")
    serial-port-enable = 1
  }

  scheduling_policy {
    preemptible = true
  }

  network_interface {
    subnet_id          = yandex_vpc_subnet.develop_a.id
    nat                = true
    security_group_ids = [
      yandex_vpc_security_group.LAN.id,
      yandex_vpc_security_group.web_sg.id
    ]
  }
}

# ВМ для GitLab Runner: 2 vCPU, 4 GB RAM
resource "yandex_compute_instance" "runner" {
  name        = "gitlab-runner"
  hostname    = "gitlab-runner"
  platform_id = "standard-v3"
  zone        = "ru-central1-a"

  resources {
    cores         = 2
    memory        = 4
    core_fraction = 20
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.ubuntu_2204_lts.image_id
      type     = "network-hdd"
      size     = 10
    }
  }

  metadata = {
    user-data          = file("./cloud-init.yml")
    serial-port-enable = 1
  }

  scheduling_policy {
    preemptible = true
  }

  network_interface {
    subnet_id          = yandex_vpc_subnet.develop_a.id
    nat                = true
    security_group_ids = [
      yandex_vpc_security_group.LAN.id
    ]
  }
}

# Inventory для Ansible
resource "local_file" "inventory" {
  content = <<-EOF
[all:children]
gitlab
runner

[gitlab]
gitlab ansible_host=\${yandex_compute_instance.gitlab.network_interface.0.nat_ip_address} ansible_user=dmitry

[runner]
runner ansible_host=\${yandex_compute_instance.runner.network_interface.0.nat_ip_address} ansible_user=dmitry
EOF
  filename = "./ansible/hosts.ini"
}


