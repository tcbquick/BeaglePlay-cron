---
    - name: Build a Docker containerized Debian application for backups
      hosts: all
      become: yes
      tasks:
        - name: Create a Dockerfile for backup application
          copy:
            dest: /home/{{ ansible_user }}/Dockerfile
            content: |
              FROM debian:latest
              RUN apt update && apt install -y cron
              COPY backup.sh /usr/local/bin/backup.sh
              RUN chmod +x /usr/local/bin/backup.sh
              RUN echo "1 3 * * * /usr/local/bin/backup.sh" | crontab -
              CMD ["cron", "-f"]
    
        - name: Create backup script
          copy:
            dest: /home/{{ ansible_user }}/backup.sh
            content: |
              #!/bin/bash
              tar -czf /backup/home_$(date +%F).tar.gz /home/*
    
        - name: Build Docker image
          command: docker build -t backup-app /home/{{ ansible_user }}
    
        - name: Run Docker container
          docker_container:
            name: backup-app
            image: backup-app
            state: started
            restart_policy: always
    
    - name: Install mail support for specific cron users
      hosts: all
      become: yes
      vars:
        cron_users:
          - ansible
          - arduino
          - omada
          - venus
      tasks:
        - name: Install mailutils package
          apt:
            name: mailutils
            state: present
    
        - name: Configure mail for cron users
          lineinfile:
            path: /etc/aliases
            line: "{{ item }}: root"
            create: yes
          with_items: "{{ cron_users }}"
    
        - name: Run newaliases
          command: newaliases
    