---
# install_docker_and_registry.yml
- name: Install Docker and Local Registry
  hosts: localhost
  become: true
  tasks:
    - name: Install prerequisites
      apt:
        name:
          - apt-transport-https
          - ca-certificates
          - curl
          - software-properties-common
        state: present

    - name: Add Docker GPG key
      apt_key:
        url: https://download.docker.com/linux/debian/gpg
        state: present

    - name: Add Docker repository
      apt_repository:
        repo: deb [arch=arm64] https://download.docker.com/linux/debian bookworm stable
        state: present

    - name: Update apt cache
      apt:
        update_cache: yes

    - name: Install Docker
      apt:
        name: docker-ce
        state: latest

    - name: Create Docker group and add ansible user
      user:
        name: ansible
        groups: docker
        append: yes

    - name: Start Docker service
      service:
        name: docker
        state: started
        enabled: true

    - name: Deploy local Docker registry
      docker_container:
        name: registry
        image: registry:2
        ports:
          - "5555:5000"
        state: started

---
# add_docker_users.yml
- name: Add users to Docker group
  hosts: localhost
  become: true
  tasks:
    - name: Add specified users to Docker group
      user:
        name: "{{ item }}"
        groups: docker
        append: yes
      loop:
        - ansible
        - arduino
        - omada
        - venus

---
# install_docker_hosts.yml
- name: Install Docker on specified hosts
  hosts: all
  become: true
  tasks:
    - name: Install prerequisites
      apt:
        name:
          - apt-transport-https
          - ca-certificates
          - curl
          - software-properties-common
        state: present

    - name: Add Docker GPG key
      apt_key:
        url: https://download.docker.com/linux/debian/gpg
        state: present

    - name: Add Docker repository
      apt_repository:
        repo: deb [arch=amd64] https://download.docker.com/linux/debian bookworm stable
        state: present

    - name: Update apt cache
      apt:
        update_cache: yes

    - name: Install Docker
      apt:
        name: docker-ce
        state: latest

    - name: Ensure Docker service is started
      service:
        name: docker
        state: started
        enabled: true

---
# setup_docker_swarm.yml
- name: Setup Docker Swarm
  hosts: all
  become: true
  tasks:
    - name: Initialize Swarm on the manager
      shell: |
        docker swarm init --advertise-addr {{ ansible_host }}
      when: inventory_hostname == 'ansible-Con-troller'

    - name: Retrieve manager token
      command: docker swarm join-token manager -q
      register: manager_token
      delegate_to: ansible-Con-troller
      when: inventory_hostname == 'ansible-Con-troller'

    - name: Retrieve worker token
      command: docker swarm join-token worker -q
      register: worker_token
      delegate_to: ansible-Con-troller
      when: inventory_hostname == 'ansible-Con-troller'

    - name: Join managers to the swarm
      shell: |
        docker swarm join --token {{ manager_token.stdout }} {{ hostvars['ansible-Con-troller'].ansible_host }}:2377
      when: inventory_hostname in ['Main-Con-troller', 'Main-Con-sole', 'Main-Con-nection']

    - name: Join workers to the swarm
      shell: |
        docker swarm join --token {{ worker_token.stdout }} {{ hostvars['ansible-Con-troller'].ansible_host }}:2377
      when: inventory_hostname in ['Swarm-Client-01', 'Swarm-Client-02']

---
# install_mail_and_cron_jobs.yml
- name: Install mail support and configure cron jobs
  hosts: all
  become: true
  tasks:
    - name: Install mailutils
      apt:
        name: mailutils
        state: present

    - name: Create cron job for user home directory backups
      cron:
        name: "Backup home directories"
        user: "{{ item }}"
        minute: "1"
        hour: "3"
        job: "tar -czf /var/backups/{{ item }}_home_$(date +\%F).tar.gz /home/{{ item }}"
      loop:
        - ansible
        - arduino
        - omada
        - venus

---
# deploy_nginx_website.yml
- name: Deploy Nginx Website
  hosts: localhost
  become: true
  tasks:
    - name: Install Nginx
      apt:
        name: nginx
        state: present

    - name: Configure Nginx
      copy:
        src: ./website/nginx_config.conf
        dest: /etc/nginx/sites-available/default
      notify: Restart Nginx

    - name: Deploy index.html
      copy:
        src: ./website/index.html
        dest: /var/www/html/index.html

    - name: Ensure Nginx is running
      service:
        name: nginx
        state: started
        enabled: true

  handlers:
    - name: Restart Nginx
      service:
        name: nginx
        state: restarted
