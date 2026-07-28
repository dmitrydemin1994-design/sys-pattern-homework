  # Домашнее задание к занятию "`Практическое задание с самопроверкой «Ansible. Часть 2»`" - `Демин Дмитрий Александрович`

  ### Задание 1

  Выполните действия, приложите файлы с плейбуками и вывод выполнения.

  Напишите три плейбука. При написании рекомендуем использовать текстовый редактор с подсветкой синтаксиса YAML.
  Плейбуки должны:

      1.Скачать какой-либо архив, создать папку для распаковки и распаковать скаченный архив. Например, можете использовать официальный сайт и зеркало Apache Kafka. При этом можно скачать как исходный код, так и бинарные файлы, запакованные в архив — в нашем задании не принципиально.

      2.Установить пакет tuned из стандартного репозитория вашей ОС. Запустить его, как демон — конфигурационный файл systemd появится автоматически при установке. Добавить tuned в автозагрузку.

      3.Изменить приветствие системы (motd) при входе на любое другое. Пожалуйста, в этом задании используйте переменную для задания приветствия. Переменную можно задавать любым удобным способом.




  #### Инвентарь (inventory):
  ``` ini
  [my_group]
  net2 ansible_host=192.168.0.218
  net1 ansible_host=192.168.0.194
  [my_group:vars]
  ansible_user=dmitry
  ansible_become=true
  ansible_python_interpreter=/usr/bin/python3
  ```

  #### Плейбук download_kafka.yml (Kafka: скачивание, распаковка, очистка):

  ``` yaml
  ---
  - name: Download and extract Apache Kafka archive
    hosts: my_group
    become: true
    vars:
      kafka_version: "3.8.1"
      kafka_url: "https://archive.apache.org/dist/kafka/{{ kafka_version }}/kafka_2.13-{{ kafka_version }}.tgz"
      kafka_dir: "/opt/kafka"
      kafka_archive: "/tmp/kafka_{{ kafka_version }}.tgz"
    tasks:
      - name: Ensure directory for Kafka exists
        file:
          path: "{{ kafka_dir }}"
          state: directory
          mode: "0755"
      - name: Download Kafka archive to target host
        get_url:
          url: "{{ kafka_url }}"
          dest: "{{ kafka_archive }}"
          mode: "0644"
          timeout: 300
      - name: Extract Kafka archive
        unarchive:
          src: "{{ kafka_archive }}"
          dest: "{{ kafka_dir }}"
          remote_src: true
          extra_opts: ["--strip-components=1"]
          creates: "{{ kafka_dir }}/bin/kafka-server-start.sh"
      - name: Clean up downloaded archive
        file:
          path: "{{ kafka_archive }}"
          state: absent
  ```

  #### Проверка Kafka:

  ``` text
  $ ssh dmitry@192.168.0.218 "ls -ld /opt/kafka && ls /opt/kafka | head -3"
  drwxr-xr-x 7 root root 4096 июл 20 07:33 /opt/kafka
  bin
  config
  libs
  $ ssh dmitry@192.168.0.194 "ls -ld /opt/kafka && ls /opt/kafka | head -3"
  drwxr-xr-x 7 root root 4096 июл 20 07:33 /opt/kafka
  bin
  config
  libs
  ```

  #### Лог: sys-pattern-homework/ansible/output_kafka.log

  #### Плейбук install_tuned.yml (tuned: установка, старт, автозагрузка):

  ``` yaml
  ---
  - name: Install and enable tuned service
    hosts: my_group
    become: true
    tasks:
      - name: Install tuned package
        apt:
          name: tuned
          state: present
          update_cache: yes
      - name: Start tuned service
        systemd:
          name: tuned
          state: started
          daemon_reload: yes
      - name: Enable tuned on boot
        systemd:
          name: tuned
          enabled: true
          daemon_reload: yes
  ```

  #### Проверка tuned:
  ``` text
  $ ssh dmitry@192.168.0.218 "systemctl is-enabled tuned; systemctl is-active tuned"
  enabled
  active
  $ ssh dmitry@192.168.0.194 "systemctl is-enabled tuned; systemctl is-active tuned"
  enabled
  active
  ```

  #### Лог: /home/dmitry/sys-pattern-homework/ansible/output_tuned.log

  #### Плейбук set_motd.yml (MOTD с переменной и подстановкой хоста):
  ``` yaml
  ---
  - name: Set custom MOTD message
    hosts: my_group
    become: true
    vars:
      motd_message: |
        Welcome to the Ansible lab!
        Host: {{ inventory_hostname }}
        Kafka is installed in /opt/kafka
        Tuned service is enabled.
    tasks:
      - name: Write custom MOTD
        copy:
          content: "{{ motd_message }}"
          dest: /etc/motd
          mode: "0644"
  ```

  #### Проверка MOTD:
  ``` text
  $ ssh dmitry@192.168.0.218 "cat /etc/motd"
  Welcome to the Ansible lab!
  Host: net2
  Kafka is installed in /opt/kafka
  Tuned service is enabled.
  $ ssh dmitry@192.168.0.194 "cat /etc/motd"
  Welcome to the Ansible lab!
  Host: net1
  Kafka is installed in /opt/kafka
  Tuned service is enabled.
  ```

  #### Лог: /home/dmitry/sys-pattern-homework/ansible/output_motd.log.

  ---

  ### Задание 2

  Выполните действия, приложите файлы с модифицированным плейбуком и вывод выполнения.

  Модифицируйте плейбук из пункта 3, задания 1. В качестве приветствия он должен установить IP-адрес и hostname управляемого хоста, пожелание хорошего дня системному администратору.


  #### Плейбук set_motd_v2.yml :
  ``` yaml
  ---
  - name: Set custom MOTD with hostname, IP and greeting
    hosts: my_group
    become: true
    gather_facts: true
    vars:
      motd_message: |
        Welcome to the Ansible lab!
        Host: {{ inventory_hostname }}
        IP: {{ ansible_default_ipv4.address }}
        Хорошего дня системному администратору!
    tasks:
      - name: Write custom MOTD
        copy:
          content: "{{ motd_message }}"
          dest: /etc/motd
          mode: "0644"
  ```

  #### Проверка результата:
  ``` text
  $ ssh dmitry@192.168.0.218 "cat /etc/motd"
  Welcome to the Ansible lab!
  Host: net2
  IP: 192.168.0.218
  Хорошего дня системному администратору!
  $ ssh dmitry@192.168.0.194 "cat /etc/motd"
  Welcome to the Ansible lab!
  Host: net1
  IP: 192.168.0.194
  Хорошего дня системному администратору!
  ```

  #### Лог: /home/dmitry/sys-pattern-homework/ansible/output_motd_v2.log

  ---

  ### Задание 3

  Выполните действия, приложите архив с ролью и вывод выполнения.

  Ознакомьтесь со статьёй «Ansible - это вам не bash», сделайте соответствующие выводы и не используйте модули shell или command при выполнении задания.

  Создайте плейбук, который будет включать в себя одну, созданную вами роль. Роль должна:

      1. Установить веб-сервер Apache на управляемые хосты.

      2. Сконфигурировать файл index.html c выводом характеристик каждого компьютера как веб-страницу по умолчанию для Apache. Необходимо включить CPU, RAM, величину первого HDD, IP-адрес. Используйте Ansible facts и jinja2-template. Необходимо реализовать handler: перезапуск Apache только в случае изменения файла конфигурации Apache.

      3. Открыть порт 80, если необходимо, запустить сервер и добавить его в автозагрузку.

      4. Сделать проверку доступности веб-сайта (ответ 200, модуль uri).


  #### Структура архива роли
  ``` text
  roles/
  └── apache_info
      ├── handlers/
      │   └── main.yml
      ├── tasks/
      │   └── main.yml
      └── templates/
          └── index.html.j2
  ```

  #### Плейбук playbook_apache.yml
  ``` yaml
  ---
  - name: Deploy Apache with system info page and validate HTTP 200
    hosts: my_group
    become: true
    roles:
      - apache_info

    tasks:
      - name: Verify Apache returns HTTP 200
        uri:
          url: "http://{{ ansible_default_ipv4.address }}"
          method: GET
          timeout: 10
          return_content: false
        register: apache_check
        failed_when: apache_check.status != 200
        tags:
          - verify
  ```

  #### Роль: roles/apache_info/tasks/main.yml
  ``` yaml
  ---
  - name: Install Apache web server
    apt:
      name: apache2
      state: present
      update_cache: yes

  - name: Create index.html from template
    template:
      src: index.html.j2
      dest: /var/www/html/index.html
      owner: www-data
      group: www-data
      mode: "0644"
    notify: Restart Apache if config changed

  - name: Ensure port 80 is allowed (UFW)
    ufw:
      rule: allow
      port: "80"
      proto: tcp
    when: ansible_os_family == "Debian"

  - name: Start and enable Apache
    systemd:
      name: apache2
      state: started
      enabled: true
      daemon_reload: yes
  ```

  #### Обработчик: roles/apache_info/handlers/main.yml
  ``` yaml
  ---
  - name: Restart Apache if config changed
    systemd:
      name: apache2
      state: restarted
      daemon_reload: yes
  ```

  #### Шаблон: roles/apache_info/templates/index.html.j2
  ``` html
  <!DOCTYPE html>
  <html>
    <head>
      <meta charset="UTF-8">
      <title>System Info — {{ inventory_hostname }}</title>
      <style>
        body { font-family: Arial, sans-serif; padding: 20px; }
        dt { font-weight: bold; }
        dd { margin-bottom: 10px; }
      </style>
    </head>
    <body>
      <h1>System Info: {{ inventory_hostname }}</h1>
      <dl>
        <dt>CPU Model</dt>
        <dd>{{ ansible_processor[1] | default('N/A') }}</dd>

        <dt>RAM (MB)</dt>
        <dd>{{ (ansible_memtotal_mb | int) }}</dd>

        <dt>First HDD Size (GB)</dt>
        <dd>{% set disks = ansible_devices.keys() | list %}
            {% if disks | length > 0 %}
              {% set first_disk = disks[0] %}
              {% set sectors = ansible_devices[first_disk].sectors | int %}
              {% set sector_size = ansible_devices[first_disk].sectorsize | int %}
              {{ ((sectors * sector_size) / 1024 / 1024 / 1024) | round(1) }} GB
            {% else %}
              N/A
            {% endif %}
        </dd>

        <dt>Primary IPv4 Address</dt>
        <dd>{{ ansible_default_ipv4.address | default('N/A') }}</dd>
      </dl>
      <p>Generated by Ansible + Jinja2</p>
    </body>
  </html>
  ```

  #### Проверка доступности (HTTP 200)

  ``` text
  ssh dmitry@192.168.0.218 "curl -s -o /dev/null -w '%{http_code}' http://localhost"
  200
  ssh dmitry@192.168.0.194 "curl -s -o /dev/null -w '%{http_code}' http://localhost"
  200
  ```

  #### Лог: /home/dmitry/sys-pattern-homework/ansible/output_apache.log