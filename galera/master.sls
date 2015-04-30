{%- from "galera/map.jinja" import master with context %}
{%- if master.enabled %}

{%- if grains.os_family == "Debian2" %}

galera_debconf:
  debconf.set:
  - name: mariadb-galera-server
  - data:
      'mysql-server/root_password': {'type':'string','value':'{{ server.admin.password }}'}
      'mysql-server/root_password_again': {'type':'string','value':'{{ server.admin.password }}'}
  - require_in:
    - pkg: galera_packages

{%- endif %}

galera_packages:
  pkg.installed:
  - names: {{ master.pkgs }}

galera_log_dir:
  file.directory:
  - name: /var/log/mysql
  - makedirs: true
  - mode: 755
  - require:
    - pkg: galera_packages

{%- if not salt['cmd.run']('test -e /root/.galera_bootstrap') %}

galera_bootstrap_temp_config:
  file.managed:
  - name: {{ master.config }}
  - source: salt://mysql/files/my.cnf.bootstrap
  - mode: 644
  - template: jinja
  - require: 
    - pkg: galera_packages

galera_bootstrap_start_service:
  service.running:
  - name: mysql
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

galera_packages_bootstrap_stop_service:
  service.dead:
  - name: mysql
  - require:
    - cmd: mysql_bootstrap_update_maint_password

galera_bootstrap_init_config:
  file.managed:
  - name: {{ master.config }}
  - source: salt://mysql/conf/my.cnf
  - mode: 644
  - template: jinja
  - require: 
    - service: galera_bootstrap_stop_service

galera_bootstrap_temp_config:
  file.touch:
  - require:
    - file: galera_bootstrap_init_config
  - watch_in:
    - service: galera_service

{%- endif %}

galera_service:
  service.running:
  - name: {{ master.service }}
  - enable: true
  - reload: true

{%- endif %}