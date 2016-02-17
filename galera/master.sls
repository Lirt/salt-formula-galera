{%- from "galera/map.jinja" import master with context %}
{%- if master.enabled %}

{%- if grains.os_family == 'RedHat' %}
xtrabackup_repo:
  pkg.installed:
  - sources:
    - percona-release: {{ master.xtrabackup_repo }}
  - require_in:
    - pkg: galera_packages
{%- endif %}

galera_packages:
  pkg.installed:
  - names: {{ master.pkgs }}
  - refresh: true

galera_log_dir:
  file.directory:
  - name: /var/log/mysql
  - makedirs: true
  - mode: 755
  - require:
    - pkg: galera_packages

galera_init_script:
  file.managed:
  - name: /etc/init.d/mysql
  - source: salt://galera/files/mysql
  - mode: 755
  - require: 
    - pkg: galera_packages

{%- if salt['cmd.run']('test -e /root/.galera_bootstrap; echo $?') != '0'  %}

galera_bootstrap_temp_config:
  file.managed:
  - name: {{ master.config }}
  - source: salt://galera/files/my.cnf.bootstrap
  - mode: 644
  - template: jinja
  - require: 
    - pkg: galera_packages
    - file: galera_init_script

galera_bootstrap_start_service:
  service.running:
  - name: {{ master.service }}
  - require: 
    - file: galera_bootstrap_temp_config

galera_bootstrap_set_root_password:
  cmd.run:
  - name: mysqladmin password "{{ master.admin.password }}"
  - require:
    - service: galera_bootstrap_start_service

mysql_bootstrap_update_maint_password:
  cmd.run:
  - name: mysql -u root -p{{ master.admin.password }} -e "GRANT ALL PRIVILEGES ON *.* TO 'debian-sys-maint'@'localhost' IDENTIFIED BY '{{ master.maintenance_password }}';"
  - require:
    - cmd: galera_bootstrap_set_root_password

galera_bootstrap_stop_service:
  service.dead:
  - name: {{ master.service }}
  - require:
    - cmd: mysql_bootstrap_update_maint_password

galera_bootstrap_init_config:
  file.managed:
  - name: {{ master.config }}
  - source: salt://galera/files/my.cnf.init
  - mode: 644
  - template: jinja
  - require: 
    - service: galera_bootstrap_stop_service

galera_bootstrap_start_service_final:
  service.running:
  - name: {{ master.service }}
  - require: 
    - file: galera_bootstrap_init_config

galera_bootstrap_finish_flag:
  file.touch:
  - name: /root/.galera_bootstrap
  - require:
    - service: galera_bootstrap_start_service_final
  - watch_in:
    - file: galera_config

{%- endif %}

galera_config:
  file.managed:
  - name: {{ master.config }}
  - source: salt://galera/files/my.cnf
  - mode: 644
  - template: jinja
  - require_in: 
    - service: galera_service

galera_service:
  service.running:
  - name: {{ master.service }}
  - enable: true
  - reload: true

{%- endif %}
