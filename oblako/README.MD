# Практическое задание с самопроверкой «Подъем инфраструктуры в облаке». Студент: Демин Дмитрий .

## Задание 1

Повторить демонстрацию лекции (развернуть vpc, 2 веб сервера, бастион сервер).

### vms.tf

``` HCL

#считываем данные об образе ОС
data "yandex_compute_image" "ubuntu_2204_lts" {
  family = "ubuntu-2204-lts"
}

resource "yandex_compute_instance" "bastion" {
  name        = "bastion" #Имя ВМ в облачной консоли
  hostname    = "bastion" #формирует FDQN имя хоста, без hostname будет сгенрировано случаное имя.
  platform_id = "standard-v3"
  zone        = "ru-central1-a" #зона ВМ должна совпадать с зоной subnet!!!

  resources {
    cores         = 2
    memory        = 1
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

  scheduling_policy { preemptible = true }

  network_interface {
    subnet_id          = yandex_vpc_subnet.develop_a.id #зона ВМ должна совпадать с зоной subnet!!!
    nat                = true
    security_group_ids = [yandex_vpc_security_group.LAN.id, yandex_vpc_security_group.bastion.id]
  }
}


resource "yandex_compute_instance" "web_a" {
  name        = "web-a" #Имя ВМ в облачной консоли
  hostname    = "web-a" #формирует FDQN имя хоста, без hostname будет сгенрировано случаное имя.
  platform_id = "standard-v3"
  zone        = "ru-central1-a" #зона ВМ должна совпадать с зоной subnet!!!


  resources {
    cores         = 2
    memory        = 1
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

  scheduling_policy { preemptible = true }

  network_interface {
    subnet_id          = yandex_vpc_subnet.develop_a.id
    nat                = false
    security_group_ids = [yandex_vpc_security_group.LAN.id, yandex_vpc_security_group.web_sg.id]
  }
}

resource "yandex_compute_instance" "web_b" {
  name        = "web-b" #Имя ВМ в облачной консоли
  hostname    = "web-b" #формирует FDQN имя хоста, без hostname будет сгенрировано случаное имя.
  platform_id = "standard-v3"
  zone        = "ru-central1-b" #зона ВМ должна совпадать с зоной subnet!!!

  resources {
    cores         = var.test.cores
    memory        = 1
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

  scheduling_policy { preemptible = true }

  network_interface {
    subnet_id          = yandex_vpc_subnet.develop_b.id
    nat                = false
    security_group_ids = [yandex_vpc_security_group.LAN.id, yandex_vpc_security_group.web_sg.id]

  }
}


resource "local_file" "inventory" {
  content  = <<-XYZ
  [bastion]
  ${yandex_compute_instance.bastion.network_interface.0.nat_ip_address}

  [webservers]
  ${yandex_compute_instance.web_a.network_interface.0.ip_address}
  ${yandex_compute_instance.web_b.network_interface.0.ip_address}

  [webservers:vars]
  ansible_user=user
  ansible_ssh_common_args='-o ProxyCommand="ssh -p 22 -W %h:%p -q user@${yandex_compute_instance.bastion.network_interface.0.nat_ip_address}"'
  XYZ
  filename = "./hosts.ini"
}
```
### variables.tf

``` HCL
variable "flow" {
  type    = string
}

variable "cloud_id" {
  type    = string
}
variable "folder_id" {
  type    = string
}

variable "test" {
  type = map(number)
  default = {
    cores         = 2
    memory        = 1
    core_fraction = 20
  }
}
```
### providers.tf

``` HCL
terraform {
  required_providers {
    yandex = {
      source  = "yandex-cloud/yandex"
      version = "0.129.0"
    }
  }

  required_version = ">=1.8.4"
}

provider "yandex" {
  # token                    = "do not use!!!"
  cloud_id                 = var.cloud_id
  folder_id                = var.folder_id
  service_account_key_file = "authorized_key.json"
}


```
### network.tf

``` HCL
#создаем облачную сеть
resource "yandex_vpc_network" "develop" {
  name = "develop-fops-${var.flow}"
}

#создаем подсеть zone A
resource "yandex_vpc_subnet" "develop_a" {
  name           = "develop-fops-${var.flow}-ru-central1-a"
  zone           = "ru-central1-a"
  network_id     = yandex_vpc_network.develop.id
  v4_cidr_blocks = ["10.0.1.0/24"]
  route_table_id = yandex_vpc_route_table.rt.id
}

#создаем подсеть zone B
resource "yandex_vpc_subnet" "develop_b" {
  name           = "develop-fops-${var.flow}-ru-central1-b"
  zone           = "ru-central1-b"
  network_id     = yandex_vpc_network.develop.id
  v4_cidr_blocks = ["10.0.2.0/24"]
  route_table_id = yandex_vpc_route_table.rt.id
}

#создаем NAT для выхода в интернет
resource "yandex_vpc_gateway" "nat_gateway" {
  name = "fops-gateway-${var.flow}"
  shared_egress_gateway {}
}

#создаем сетевой маршрут для выхода в интернет через NAT
resource "yandex_vpc_route_table" "rt" {
  name       = "fops-route-table-${var.flow}"
  network_id = yandex_vpc_network.develop.id

  static_route {
    destination_prefix = "0.0.0.0/0"
    gateway_id         = yandex_vpc_gateway.nat_gateway.id
  }
}

#создаем группы безопасности(firewall)

resource "yandex_vpc_security_group" "bastion" {
  name       = "bastion-sg-${var.flow}"
  network_id = yandex_vpc_network.develop.id
  ingress {
    description    = "Allow 0.0.0.0/0"
    protocol       = "TCP"
    v4_cidr_blocks = ["0.0.0.0/0"]
    port           = 22
  }
  egress {
    description    = "Permit ANY"
    protocol       = "ANY"
    v4_cidr_blocks = ["0.0.0.0/0"]
    from_port      = 0
    to_port        = 65535
  }

}


resource "yandex_vpc_security_group" "LAN" {
  name       = "LAN-sg-${var.flow}"
  network_id = yandex_vpc_network.develop.id
  ingress {
    description    = "Allow 10.0.0.0/8"
    protocol       = "ANY"
    v4_cidr_blocks = ["10.0.0.0/8"]
    from_port      = 0
    to_port        = 65535
  }
  egress {
    description    = "Permit ANY"
    protocol       = "ANY"
    v4_cidr_blocks = ["0.0.0.0/0"]
    from_port      = 0
    to_port        = 65535
  }

}

resource "yandex_vpc_security_group" "web_sg" {
  name       = "web-sg-${var.flow}"
  network_id = yandex_vpc_network.develop.id


  ingress {
    description    = "Allow HTTPS"
    protocol       = "TCP"
    port           = 443
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description    = "Allow HTTP"
    protocol       = "TCP"
    port           = 80
    v4_cidr_blocks = ["0.0.0.0/0"]
  }


}


```
### cloud-init.yml

``` HCL
#cloud-config
users:
  - name: user
    groups: sudo
    shell: /bin/bash
    sudo: ["ALL=(ALL) NOPASSWD:ALL"]
    ssh_authorized_keys:
      - ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKcJnCxtZGhVAoGCl/hZPKHJ+QF8fQCFnnhxygRfTZGB dmitry@dmitry-VirtualBox

```
### ansible.cfg

``` HCL
[defaults]
host_key_checking = False

```
### .terraformrc

``` HCL
provider_installation {
  network_mirror {
    url = "https://terraform-mirror.yandexcloud.net/"
    include = ["registry.terraform.io/*/*"]
  }
  direct {
    exclude = ["registry.terraform.io/*/*"]
  }
}

```
### Выполняем команды

``` BASH
terraform init & terraform apply

```
### Результат

``` Text
yandex_vpc_gateway.nat_gateway: Creating...
yandex_vpc_network.develop: Creating...
yandex_vpc_gateway.nat_gateway: Creation complete after 2s [id=enpkq1norfr86qv7hmcd]
yandex_vpc_network.develop: Creation complete after 3s [id=enpk52m1c2245r2tmvnc]
yandex_vpc_route_table.rt: Creating...
yandex_vpc_security_group.bastion: Creating...
yandex_vpc_security_group.web_sg: Creating...
yandex_vpc_security_group.LAN: Creating...
yandex_vpc_route_table.rt: Creation complete after 1s [id=enpppg75tv5jf24h9q9t]
yandex_vpc_subnet.develop_a: Creating...
yandex_vpc_subnet.develop_b: Creating...
yandex_vpc_security_group.web_sg: Creation complete after 2s [id=enpgd4pq0rvr31seerm9]
yandex_vpc_subnet.develop_a: Creation complete after 1s [id=e9b6sk5ap4bo7j3h41p2]
yandex_vpc_subnet.develop_b: Creation complete after 2s [id=e2lvebjna4ti74pm0ktg]
yandex_vpc_security_group.LAN: Creation complete after 4s [id=enpb7c856o7tnvktbs2f]
yandex_compute_instance.web_a: Creating...
yandex_compute_instance.web_b: Creating...
yandex_vpc_security_group.bastion: Creation complete after 5s [id=enp99chin0k64f1eihbj]
yandex_compute_instance.bastion: Creating...
yandex_compute_instance.web_a: Still creating... [00m10s elapsed]
yandex_compute_instance.web_b: Still creating... [00m10s elapsed]
yandex_compute_instance.bastion: Still creating... [00m10s elapsed]
yandex_compute_instance.web_a: Still creating... [00m20s elapsed]
yandex_compute_instance.web_b: Still creating... [00m20s elapsed]
yandex_compute_instance.bastion: Still creating... [00m20s elapsed]
yandex_compute_instance.web_b: Still creating... [00m30s elapsed]
yandex_compute_instance.web_a: Still creating... [00m30s elapsed]
yandex_compute_instance.bastion: Still creating... [00m30s elapsed]
yandex_compute_instance.web_a: Still creating... [00m40s elapsed]
yandex_compute_instance.web_b: Still creating... [00m40s elapsed]
yandex_compute_instance.bastion: Still creating... [00m40s elapsed]
yandex_compute_instance.web_b: Creation complete after 42s [id=epdg55moj4q3t33mseq7]
yandex_compute_instance.web_a: Creation complete after 44s [id=fhmt47nmi5cblh6t70tm]
yandex_compute_instance.bastion: Creation complete after 49s [id=fhm6b4q68p4so3ac5kcl]
local_file.inventory: Creating...
local_file.inventory: Creation complete after 0s [id=e2ffa63f8c23116148c66459fb2238cbf095c30b]

Apply complete! Resources: 12 added, 0 changed, 0 destroyed.

```
### Создается файл hosts.ini

``` ini
[bastion]
130.193.39.195

[webservers]
10.0.1.4
10.0.2.34

[webservers:vars]
ansible_user=user
ansible_ssh_common_args='-o ProxyCommand="ssh -p 22 -W %h:%p -q user@130.193.39.195"'

```
### Проверяем подключение по SSH

``` BASH
ssh user@130.193.39.195
ssh -J user@130.193.39.195 user@10.0.1.4
ssh -J user@130.193.39.195 user@10.0.2.34

```
### Результат

``` Text
The authenticity of host '130.193.39.195 (130.193.39.195)' can't be established.
ED25519 key fingerprint is SHA256:kmp9zA6EU1dcaO77NMtFqR6dLLL/p+eoExTK9NYWdio.
This key is not known by any other names.
Are you sure you want to continue connecting (yes/no/[fingerprint])? y
Please type 'yes', 'no' or the fingerprint: y
Please type 'yes', 'no' or the fingerprint: y
Please type 'yes', 'no' or the fingerprint: yes
Warning: Permanently added '130.193.39.195' (ED25519) to the list of known hosts.
Welcome to Ubuntu 22.04.5 LTS (GNU/Linux 5.15.0-186-generic x86_64)

 * Documentation:  https://help.ubuntu.com
 * Management:     https://landscape.canonical.com
 * Support:        https://ubuntu.com/pro

 System information as of Tue Jul 21 12:03:17 UTC 2026

  System load:  0.0               Processes:             92
  Usage of /:   19.9% of 9.04GB   Users logged in:       0
  Memory usage: 18%               IPv4 address for eth0: 10.0.1.8
  Swap usage:   0%


Expanded Security Maintenance for Applications is not enabled.

0 updates can be applied immediately.

Enable ESM Apps to receive additional future security updates.
See https://ubuntu.com/esm or run: sudo pro status



The programs included with the Ubuntu system are free software;
the exact distribution terms for each program are described in the
individual files in /usr/share/doc/*/copyright.

Ubuntu comes with ABSOLUTELY NO WARRANTY, to the extent permitted by
applicable law.

To run a command as administrator (user "root"), use "sudo <command>".
See "man sudo_root" for details.

user@bastion:~$ exit
logout
Connection to 130.193.39.195 closed.

The authenticity of host '10.0.1.4 (<no hostip for proxy command>)' can't be established.
ED25519 key fingerprint is SHA256:nqs5/P73fpaZpEcyg9eXCcEKYfquFTAf/ft9X8aycfs.
This key is not known by any other names.
Are you sure you want to continue connecting (yes/no/[fingerprint])? yes
Warning: Permanently added '10.0.1.4' (ED25519) to the list of known hosts.
Welcome to Ubuntu 22.04.5 LTS (GNU/Linux 5.15.0-186-generic x86_64)

 * Documentation:  https://help.ubuntu.com
 * Management:     https://landscape.canonical.com
 * Support:        https://ubuntu.com/pro

 System information as of Tue Jul 21 12:05:41 UTC 2026

  System load:  0.16              Processes:             95
  Usage of /:   19.9% of 9.04GB   Users logged in:       0
  Memory usage: 17%               IPv4 address for eth0: 10.0.1.4
  Swap usage:   0%


Expanded Security Maintenance for Applications is not enabled.

0 updates can be applied immediately.

Enable ESM Apps to receive additional future security updates.
See https://ubuntu.com/esm or run: sudo pro status



The programs included with the Ubuntu system are free software;
the exact distribution terms for each program are described in the
individual files in /usr/share/doc/*/copyright.

Ubuntu comes with ABSOLUTELY NO WARRANTY, to the extent permitted by
applicable law.

To run a command as administrator (user "root"), use "sudo <command>".
See "man sudo_root" for details.

user@web-a:~$ exit
logout
Connection to 10.0.1.4 closed.

The authenticity of host '10.0.2.34 (<no hostip for proxy command>)' can't be established.
ED25519 key fingerprint is SHA256:Ep08piwkdgLy/XDe771GgpUQZH+uC9B81DiC1/SzVw0.
This key is not known by any other names.
Are you sure you want to continue connecting (yes/no/[fingerprint])? yes
Warning: Permanently added '10.0.2.34' (ED25519) to the list of known hosts.
Welcome to Ubuntu 22.04.5 LTS (GNU/Linux 5.15.0-186-generic x86_64)

 * Documentation:  https://help.ubuntu.com
 * Management:     https://landscape.canonical.com
 * Support:        https://ubuntu.com/pro

 System information as of Tue Jul 21 12:06:41 UTC 2026

  System load:  0.0               Processes:             92
  Usage of /:   19.9% of 9.04GB   Users logged in:       0
  Memory usage: 18%               IPv4 address for eth0: 10.0.2.34
  Swap usage:   0%


Expanded Security Maintenance for Applications is not enabled.

0 updates can be applied immediately.

Enable ESM Apps to receive additional future security updates.
See https://ubuntu.com/esm or run: sudo pro status



The programs included with the Ubuntu system are free software;
the exact distribution terms for each program are described in the
individual files in /usr/share/doc/*/copyright.

Ubuntu comes with ABSOLUTELY NO WARRANTY, to the extent permitted by
applicable law.

To run a command as administrator (user "root"), use "sudo <command>".
See "man sudo_root" for details.

user@web-b:~$ exit
logout
Connection to 10.0.2.34 closed.


```
## Задание 2

1. С помощью ansible подключиться к web-a и web-b , установить на них nginx.(написать нужный ansible playbook)
2. Провести тестирование и приложить скриншоты развернутых в облаке ВМ, успешно отработавшего ansible playbook.



### Проверяем доступно ли подключение по SSH для ansible

``` BASH
ansible webservers -i hosts.ini -m ping

```

### Результат

``` Text
[WARNING]: Host '10.0.2.34' is using the discovered Python interpreter at '/usr/bin/python3.10', but future installation of another Python interpreter could cause a different interpreter to be discovered. See https://docs.ansible.com/ansible-core/2.21/reference_appendices/interpreter_discovery.html for more information.
10.0.2.34 | SUCCESS => {
    "ansible_facts": {
        "discovered_interpreter_python": "/usr/bin/python3.10"
    },
    "changed": false,
    "ping": "pong"
}
[WARNING]: Host '10.0.1.4' is using the discovered Python interpreter at '/usr/bin/python3.10', but future installation of another Python interpreter could cause a different interpreter to be discovered. See https://docs.ansible.com/ansible-core/2.21/reference_appendices/interpreter_discovery.html for more information.
10.0.1.4 | SUCCESS => {
    "ansible_facts": {
        "discovered_interpreter_python": "/usr/bin/python3.10"
    },
    "changed": false,
    "ping": "pong"
}

```

### Создаем файл nginx.yml

``` YAML
---
- name: Install and start Nginx on webservers
  hosts: webservers
  gather_facts: yes
  vars:
    ansible_ssh_user: user
    ansible_become: true
    ansible_become_method: sudo
  pre_tasks:
    - name: Wait for SSH to be ready
      wait_for:
        host: "{{ (ansible_ssh_host|default(ansible_host))|default(inventory_hostname) }}"
        port: 22
        delay: 5
        timeout: 300
        state: started
        search_regex: OpenSSH

  tasks:
    - name: Update apt cache
      apt:
        update_cache: yes
        cache_valid_time: 3600

    - name: Install nginx
      apt:
        name: nginx
        state: present

    - name: Ensure nginx is running and enabled
      systemd:
        name: nginx
        enabled: yes
        state: started

    - name: Verify nginx status
      command: systemctl is-active --quiet nginx
      register: nginx_status
      failed_when: nginx_status.rc != 0
      changed_when: false

    - name: Show nginx version
      command: nginx -v
      register: nginx_version
      changed_when: false
      failed_when: false

    - debug:
        msg: "Nginx installed on {{ inventory_hostname }}: {{ nginx_version.stdout }}"


```

### Применяем команду

``` BASH
ansible-playbook -i hosts.ini nginx.yml

```
### Результат

``` Text
PLAY [Install and start Nginx on webservers] *******************************************************************************************************

TASK [Gathering Facts] *****************************************************************************************************************************
[WARNING]: Host '10.0.2.34' is using the discovered Python interpreter at '/usr/bin/python3.10', but future installation of another Python interpreter could cause a different interpreter to be discovered. See https://docs.ansible.com/ansible-core/2.21/reference_appendices/interpreter_discovery.html for more information.
ok: [10.0.2.34]
[WARNING]: Host '10.0.1.4' is using the discovered Python interpreter at '/usr/bin/python3.10', but future installation of another Python interpreter could cause a different interpreter to be discovered. See https://docs.ansible.com/ansible-core/2.21/reference_appendices/interpreter_discovery.html for more information.
ok: [10.0.1.4]

TASK [Wait for SSH to be ready] ********************************************************************************************************************
ok: [10.0.2.34]
ok: [10.0.1.4]

TASK [Update apt cache] ****************************************************************************************************************************
changed: [10.0.2.34]
changed: [10.0.1.4]

TASK [Install nginx] *******************************************************************************************************************************
changed: [10.0.2.34]
changed: [10.0.1.4]

TASK [Ensure nginx is running and enabled] *********************************************************************************************************
ok: [10.0.2.34]
ok: [10.0.1.4]

TASK [Verify nginx status] *************************************************************************************************************************
ok: [10.0.1.4]
ok: [10.0.2.34]

TASK [Show nginx version] **************************************************************************************************************************
ok: [10.0.1.4]
ok: [10.0.2.34]

TASK [debug] ***************************************************************************************************************************************
ok: [10.0.1.4] => {
    "msg": "Nginx installed on 10.0.1.4: "
}
ok: [10.0.2.34] => {
    "msg": "Nginx installed on 10.0.2.34: "
}

PLAY RECAP *****************************************************************************************************************************************
10.0.1.4                   : ok=8    changed=2    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
10.0.2.34                  : ok=8    changed=2    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0


```

## Задание 3*
1. Добавить еще одну виртуальную машину.
2. Установить на нее любую базу данных.
3. Выполнить проверку состояния запущенных служб через Ansible.

### Изменяем файл vms.tf

``` HCL

#считываем данные об образе ОС
data "yandex_compute_image" "ubuntu_2204_lts" {
  family = "ubuntu-2204-lts"
}

resource "yandex_compute_instance" "bastion" {
  name        = "bastion" #Имя ВМ в облачной консоли
  hostname    = "bastion" #формирует FDQN имя хоста, без hostname будет сгенрировано случаное имя.
  platform_id = "standard-v3"
  zone        = "ru-central1-a" #зона ВМ должна совпадать с зоной subnet!!!

  resources {
    cores         = 2
    memory        = 1
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

  scheduling_policy { preemptible = true }

  network_interface {
    subnet_id          = yandex_vpc_subnet.develop_a.id #зона ВМ должна совпадать с зоной subnet!!!
    nat                = true
    security_group_ids = [yandex_vpc_security_group.LAN.id, yandex_vpc_security_group.bastion.id]
  }
}


resource "yandex_compute_instance" "web_a" {
  name        = "web-a" #Имя ВМ в облачной консоли
  hostname    = "web-a" #формирует FDQN имя хоста, без hostname будет сгенрировано случаное имя.
  platform_id = "standard-v3"
  zone        = "ru-central1-a" #зона ВМ должна совпадать с зоной subnet!!!


  resources {
    cores         = 2
    memory        = 1
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

  scheduling_policy { preemptible = true }

  network_interface {
    subnet_id          = yandex_vpc_subnet.develop_a.id
    nat                = false
    security_group_ids = [yandex_vpc_security_group.LAN.id, yandex_vpc_security_group.web_sg.id]
  }
}

resource "yandex_compute_instance" "web_b" {
  name        = "web-b" #Имя ВМ в облачной консоли
  hostname    = "web-b" #формирует FDQN имя хоста, без hostname будет сгенрировано случаное имя.
  platform_id = "standard-v3"
  zone        = "ru-central1-b" #зона ВМ должна совпадать с зоной subnet!!!

  resources {
    cores         = var.test.cores
    memory        = 1
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

  scheduling_policy { preemptible = true }

  network_interface {
    subnet_id          = yandex_vpc_subnet.develop_b.id
    nat                = false
    security_group_ids = [yandex_vpc_security_group.LAN.id, yandex_vpc_security_group.web_sg.id]

  }
}

resource "yandex_compute_instance" "db_server" {
  name        = "db-server" #Имя ВМ в облачной консоли
  hostname    = "db-server" #формирует FDQN имя хоста, без hostname будет сгенрировано случаное имя.
  platform_id = "standard-v3"
  zone        = "ru-central1-b" #зона ВМ должна совпадать с зоной subnet!!!

  resources {
    cores         = var.test.cores
    memory        = 1
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

  scheduling_policy { preemptible = true }

  network_interface {
    subnet_id          = yandex_vpc_subnet.develop_b.id
    nat                = false
    security_group_ids = [yandex_vpc_security_group.LAN.id, yandex_vpc_security_group.web_sg.id]

  }
}

resource "local_file" "inventory" {
  content  = <<-XYZ
  [bastion]
  ${yandex_compute_instance.bastion.network_interface.0.nat_ip_address}

  [webservers]
  ${yandex_compute_instance.web_a.network_interface.0.ip_address}
  ${yandex_compute_instance.web_b.network_interface.0.ip_address}

  [webservers:vars]
  ansible_user=user
  ansible_ssh_common_args='-o ProxyCommand="ssh -p 22 -W %h:%p -q user@${yandex_compute_instance.bastion.network_interface.0.nat_ip_address}"'

  [dbservers]
  ${yandex_compute_instance.db_server.network_interface.0.ip_address}

  [dbservers:vars]
  ansible_user=user
  ansible_ssh_common_args='-o ProxyCommand="ssh -p 22 -W %h:%p -q user@${yandex_compute_instance.bastion.network_interface.0.nat_ip_address}"'

  XYZ
  filename = "./hosts.ini"
}

```
### Применяем команды

``` BASH
terraform init
terraform apply
```
### Результат

``` Text
Initializing the backend...

Initializing provider plugins...
- Reusing previous version of hashicorp/local from the dependency lock file
- Reusing previous version of yandex-cloud/yandex from the dependency lock file
- Using previously-installed hashicorp/local v2.9.0
- Using previously-installed yandex-cloud/yandex v0.129.0


Terraform has been successfully initialized!

You may now begin working with Terraform. Try running "terraform plan" to see
any changes that are required for your infrastructure. All Terraform commands
should now work.

If you ever set or change modules or backend configuration for Terraform,
rerun this command to reinitialize your working directory. If you forget, other
commands will detect it and remind you to do so if necessary.

yandex_compute_instance.db_server: Creating...
yandex_compute_instance.db_server: Still creating... [00m10s elapsed]
yandex_compute_instance.db_server: Still creating... [00m20s elapsed]
yandex_compute_instance.db_server: Still creating... [00m30s elapsed]
yandex_compute_instance.db_server: Creation complete after 40s [id=epduejrjtd1l0h4a2uku]
local_file.inventory: Creating...
local_file.inventory: Creation complete after 0s [id=8b1872bc6cbae092ee878ac6f83061aa43c382f5]

Apply complete! Resources: 2 added, 0 changed, 0 destroyed.

```
### Получаем новый файл hosts.ini

``` ini
[bastion]
130.193.39.195

[webservers]
10.0.1.4
10.0.2.34

[webservers:vars]
ansible_user=user
ansible_ssh_common_args='-o ProxyCommand="ssh -p 22 -W %h:%p -q user@130.193.39.195"'

[dbservers]
10.0.2.33

[dbservers:vars]
ansible_user=user
ansible_ssh_common_args='-o ProxyCommand="ssh -p 22 -W %h:%p -q user@130.193.39.195"'

```
### Проверяем подключение по SSH

``` BASH
ssh -J user@130.193.39.195 user@10.0.2.33
```
### Результат

``` Text
The authenticity of host '10.0.2.33 (<no hostip for proxy command>)' can't be established.
ED25519 key fingerprint is SHA256:ZFILwx4tJR4iOTqhO7Dv+NH6aGCYgjzT7eW1RXVBa+U.
This key is not known by any other names.
Are you sure you want to continue connecting (yes/no/[fingerprint])? yes
Warning: Permanently added '10.0.2.33' (ED25519) to the list of known hosts.
Welcome to Ubuntu 22.04.5 LTS (GNU/Linux 5.15.0-186-generic x86_64)

 * Documentation:  https://help.ubuntu.com
 * Management:     https://landscape.canonical.com
 * Support:        https://ubuntu.com/pro

 System information as of Tue Jul 21 12:44:04 UTC 2026

  System load:  0.09              Processes:             97
  Usage of /:   19.9% of 9.04GB   Users logged in:       0
  Memory usage: 16%               IPv4 address for eth0: 10.0.2.33
  Swap usage:   0%


Expanded Security Maintenance for Applications is not enabled.

0 updates can be applied immediately.

Enable ESM Apps to receive additional future security updates.
See https://ubuntu.com/esm or run: sudo pro status



The programs included with the Ubuntu system are free software;
the exact distribution terms for each program are described in the
individual files in /usr/share/doc/*/copyright.

Ubuntu comes with ABSOLUTELY NO WARRANTY, to the extent permitted by
applicable law.

To run a command as administrator (user "root"), use "sudo <command>".
See "man sudo_root" for details.

user@db-server:~$ exit
logout
Connection to 10.0.2.33 closed.
```
### Проверяем доступность подключения по SSH для ansible

``` BASH
ansible dbservers -i hosts.ini -m ping
```
### Результат

``` Text
[WARNING]: Host '10.0.2.33' is using the discovered Python interpreter at '/usr/bin/python3.10', but future installation of another Python interpreter could cause a different interpreter to be discovered. See https://docs.ansible.com/ansible-core/2.21/reference_appendices/interpreter_discovery.html for more information.
10.0.2.33 | SUCCESS => {
    "ansible_facts": {
        "discovered_interpreter_python": "/usr/bin/python3.10"
    },
    "changed": false,
    "ping": "pong"
}
```
### Создаем плейбук install_pg_and_check.yml

``` yml
---
- name: Install PostgreSQL and check services on dbservers
  hosts: dbservers
  become: true
  gather_facts: true

  tasks:
    - name: Update apt cache
      apt:
        update_cache: yes
        cache_valid_time: 3600

    - name: Install PostgreSQL
      apt:
        name: postgresql
        state: present

    - name: Ensure PostgreSQL service is running and enabled
      systemd:
        name: postgresql
        state: started
        enabled: true

    - name: Check PostgreSQL status via systemctl
      command: systemctl is-active postgresql
      register: pg_status
      changed_when: false

    - name: Debug PostgreSQL status
      debug:
        msg: "PostgreSQL status on {{ inventory_hostname }}: {{ pg_status.stdout }}"

    - name: Get PostgreSQL version
      command: psql --version
      register: pg_version
      changed_when: false

    - name: Debug PostgreSQL version
      debug:
        msg: "PostgreSQL version on {{ inventory_hostname }}: {{ pg_version.stdout }}"

```
### Устанавливаем БД через ansible

``` BASH
ansible-playbook -i hosts.ini install_pg_and_check.yml
```
### Результат

``` Text
PLAY [Install PostgreSQL and check services on dbservers] ******************************************************************************************

TASK [Gathering Facts] *****************************************************************************************************************************
[WARNING]: Host '10.0.2.33' is using the discovered Python interpreter at '/usr/bin/python3.10', but future installation of another Python interpreter could cause a different interpreter to be discovered. See https://docs.ansible.com/ansible-core/2.21/reference_appendices/interpreter_discovery.html for more information.
ok: [10.0.2.33]

TASK [Update apt cache] ****************************************************************************************************************************
changed: [10.0.2.33]

TASK [Install PostgreSQL] **************************************************************************************************************************
changed: [10.0.2.33]

TASK [Ensure PostgreSQL service is running and enabled] ********************************************************************************************
ok: [10.0.2.33]

TASK [Check PostgreSQL status via systemctl] *******************************************************************************************************
ok: [10.0.2.33]

TASK [Debug PostgreSQL status] *********************************************************************************************************************
ok: [10.0.2.33] => {
    "msg": "PostgreSQL status on 10.0.2.33: active"
}

TASK [Get PostgreSQL version] **********************************************************************************************************************
ok: [10.0.2.33]

TASK [Debug PostgreSQL version] ********************************************************************************************************************
ok: [10.0.2.33] => {
    "msg": "PostgreSQL version on 10.0.2.33: psql (PostgreSQL) 14.23 (Ubuntu 14.23-0ubuntu0.22.04.1)"
}

PLAY RECAP *****************************************************************************************************************************************
10.0.2.33                  : ok=8    changed=2    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
```
### Проверяем результат

``` BASH
ssh -J user@130.193.39.195 user@10.0.2.33 "systemctl is-active postgresql"
ssh -J user@130.193.39.195 user@10.0.2.33 "psql --version"
```
### Результат

``` Text
active
psql (PostgreSQL) 14.23 (Ubuntu 14.23-0ubuntu0.22.04.1)
```