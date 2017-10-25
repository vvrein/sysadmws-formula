{% if (pillar['app'] is defined) and (pillar['app'] is not none) %}
  {%- if (pillar['app']['php-fpm_apps'] is defined) and (pillar['app']['php-fpm_apps'] is not none) %}
    {%- if (pillar['certbot_staging'] is defined) and (pillar['certbot_staging'] is not none) and (pillar['certbot_staging']) %}
      {%- set certbot_staging = "--staging" %}
    {%- else %}
      {%- set certbot_staging = " " %}
    {%- endif %}
    {%- if (pillar['app_only_one'] is defined) and (pillar['app_only_one'] is not none) %}
      {%- set app_selector = pillar['app_only_one'] %}
    {%- else %}
      {%- set app_selector = 'all' %}
    {%- endif %}
    {%- for phpfpm_app, app_params in pillar['app']['php-fpm_apps'].items() -%}
      {%- if
             (app_params['enabled'] is defined) and (app_params['enabled'] is not none) and (app_params['enabled']) and
             (app_params['user'] is defined) and (app_params['user'] is not none) and
             (app_params['group'] is defined) and (app_params['group'] is not none) and
             (app_params['app_root'] is defined) and (app_params['app_root'] is not none) and

             (app_params['nginx'] is defined) and (app_params['nginx'] is not none) and
             (app_params['nginx']['vhost_config'] is defined) and (app_params['nginx']['vhost_config'] is not none) and
             (app_params['nginx']['root'] is defined) and (app_params['nginx']['root'] is not none) and
             (app_params['nginx']['server_name'] is defined) and (app_params['nginx']['server_name'] is not none) and
             (app_params['nginx']['access_log'] is defined) and (app_params['nginx']['access_log'] is not none) and
             (app_params['nginx']['error_log'] is defined) and (app_params['nginx']['error_log'] is not none) and

             (app_params['pool'] is defined) and (app_params['pool'] is not none) and
             (app_params['pool']['pool_config'] is defined) and (app_params['pool']['pool_config'] is not none) and
             (app_params['pool']['php_version'] is defined) and (app_params['pool']['php_version'] is not none) and
             (app_params['pool']['pm'] is defined) and (app_params['pool']['pm'] is not none) and

             (app_params['shell'] is defined) and (app_params['shell'] is not none) and

             (
               (app_selector == 'all') or
               (app_selector == phpfpm_app)
             )
      %}
php-fpm_apps_group_{{ loop.index }}:
  group.present:
    - name: {{ app_params['group'] }}

php-fpm_apps_user_{{ loop.index }}:
  user.present:
    - name: {{ app_params['user'] }}
    - gid: {{ app_params['group'] }}
    - optional_groups:
      - adm
    - home: {{ app_params['app_root'] }}
    - createhome: True
    - password: '!'
    - shell: {{ app_params['shell'] }}
    - fullname: {{ 'application ' ~ phpfpm_app }}

php-fpm_apps_user_ssh_dir_{{ loop.index }}:
  file.directory:
    - name: {{ app_params['app_root'] ~ '/.ssh' }}
    - user: {{ app_params['user'] }}
    - group: {{ app_params['group'] }}
    - mode: 700
    - makedirs: True

        {%- if (app_params['app_auth_keys'] is defined) and (app_params['app_auth_keys'] is not none) %}
php-fpm_apps_user_ssh_auth_keys_{{ loop.index }}:
  file.managed:
    - name: {{ app_params['app_root'] ~ '/.ssh/authorized_keys' }}
    - user: {{ app_params['user'] }}
    - group: {{ app_params['group'] }}
    - mode: 600
    - contents: {{ app_params['app_auth_keys'] | yaml_encode }}
        {%- endif %}

        {%- if
               (app_params['git_source'] is defined) and (app_params['git_source'] is not none) and
               (app_params['git_source']['enabled'] is defined) and (app_params['git_source']['enabled'] is not none) and (app_params['git_source']['enabled']) and
               (app_params['git_source']['git'] is defined) and (app_params['git_source']['git'] is not none) and
               (app_params['git_source']['rev'] is defined) and (app_params['git_source']['rev'] is not none) and
               (app_params['git_source']['target'] is defined) and (app_params['git_source']['target'] is not none) and
               (app_params['git_source']['branch'] is defined) and (app_params['git_source']['branch'] is not none)
        %}
          {%- if
                 (app_params['git_source']['key'] is defined) and (app_params['git_source']['key'] is not none) and
                 (app_params['git_source']['key_pub'] is defined) and (app_params['git_source']['key_pub'] is not none)
          %}
php-fpm_apps_user_ssh_id_{{ loop.index }}:
  file.managed:
    - name: {{ app_params['app_root'] ~ '/.ssh/id_git' }}
    - user: {{ app_params['user'] }}
    - group: {{ app_params['group'] }}
    - mode: '0600'
    - source: 'salt://{{ app_params['git_source']['key'] }}'

php-fpm_apps_user_ssh_id_pub_{{ loop.index }}:
  file.managed:
    - name: {{ app_params['app_root'] ~ '/.ssh/id_git.pub' }}
    - user: {{ app_params['user'] }}
    - group: {{ app_params['group'] }}
    - mode: '0600'
    - source: 'salt://{{ app_params['git_source']['key_pub'] }}'

php-fpm_apps_user_ssh_config_{{ loop.index }}:
  file.managed:
    - name: {{ app_params['app_root'] ~ '/.ssh/config' }}
    - user: {{ app_params['user'] }}
    - group: {{ app_params['group'] }}
    - source: 'salt://app/files/ssh_config'
    - template: jinja
    - defaults:
        identity_file: {{ app_params['app_root'] ~ '/.ssh/id_git' }}
    - mode: '0600'
          {%- endif %}

php-fpm_apps_app_git_checkout_{{ loop.index }}:
  git.latest:
    - name: {{ app_params['git_source']['git'] }}
    - rev: {{ app_params['git_source']['rev'] }}
    - target: {{ app_params['git_source']['target'] }}
    - branch: {{ app_params['git_source']['branch'] }}
    - force_reset: True
    - force_fetch: True
    - user: {{ app_params['user'] }}
          {%- if
                 (app_params['git_source']['key'] is defined) and (app_params['git_source']['key'] is not none) and
                 (app_params['git_source']['key_pub'] is defined) and (app_params['git_source']['key_pub'] is not none)
          %}
    - identity: {{ app_params['app_root'] ~ '/.ssh/id_git' }}
          {%- endif %}
        {%- endif %}

        {%- if
               (app_params['files'] is defined) and (app_params['files'] is not none) and
               (app_params['files']['src'] is defined) and (app_params['files']['src'] is not none) and
               (app_params['files']['dst'] is defined) and (app_params['files']['dst'] is not none)
        %}
php-fpm_apps_app_files_{{ loop.index }}:
  file.recurse:
    - name: {{ app_params['files']['dst'] }}
    - source: {{ 'salt://' ~ app_params['files']['src'] }}
    - clean: False
    - user: {{ app_params['user'] }}
    - group: {{ app_params['group'] }}
    - dir_mode: 755
    - file_mode: 644
        {%- endif %}

        {%- if
               (app_params['setup_script'] is defined) and (app_params['setup_script'] is not none) and
               (app_params['setup_script']['cwd'] is defined) and (app_params['setup_script']['cwd'] is not none) and
               (app_params['setup_script']['name'] is defined) and (app_params['setup_script']['name'] is not none)
        %}
php-fpm_apps_app_setup_script_run_{{ loop.index }}:
  cmd.run:
    - cwd: {{ app_params['setup_script']['cwd'] }}
    - name: {{ app_params['setup_script']['name'] }}
    - runas: {{ app_params['user'] }}
        {%- endif %}

        {%- if
               (app_params['nginx']['auth_basic'] is defined) and (app_params['nginx']['auth_basic'] is not none) and
               (app_params['nginx']['auth_basic']['user'] is defined) and (app_params['nginx']['auth_basic']['user'] is not none) and
               (app_params['nginx']['auth_basic']['pass'] is defined) and (app_params['nginx']['auth_basic']['pass'] is not none)
        %}
php-fpm_apps_app_apache_utils_{{ loop.index }}:
  pkg.installed:
    - pkgs:
      - apache2-utils

php-fpm_apps_app_htaccess_user_{{ loop.index }}:
  webutil.user_exists:
    - name: '{{ app_params['nginx']['auth_basic']['user'] }}'
    - password: '{{ app_params['nginx']['auth_basic']['pass'] }}'
    - htpasswd_file: '{{ app_params['app_root'] }}/.htpasswd'
    - force: True
    - runas: {{ app_params['user'] }}

          {%- set auth_basic_block = 'auth_basic "Restricted Content"; auth_basic_user_file ' ~ app_params['app_root'] ~ '/.htpasswd;' %}
        {%- else %}
          {%- set auth_basic_block = ' ' %}
        {%- endif %}

        {%- if (app_params['nginx']['ssl'] is defined) and (app_params['nginx']['ssl'] is not none) %}
php-fpm_apps_app_nginx_ssl_dir_{{ loop.index }}:
  file.directory:
    - name: '/etc/nginx/ssl/{{ phpfpm_app }}'
    - user: root
    - group: root
    - makedirs: True
        {%- endif %}

        {%- set server_name_301 = app_params['nginx'].get('server_name_301', phpfpm_app ~ '.example.com') %}
        {%- if
               (app_params['nginx']['ssl'] is defined) and (app_params['nginx']['ssl'] is not none) and
               (app_params['nginx']['ssl']['certs_dir'] is defined) and (app_params['nginx']['ssl']['certs_dir'] is not none) and
               (app_params['nginx']['ssl']['ssl_cert'] is defined) and (app_params['nginx']['ssl']['ssl_cert'] is not none) and
               (app_params['nginx']['ssl']['ssl_key'] is defined) and (app_params['nginx']['ssl']['ssl_key'] is not none) and
               (app_params['nginx']['ssl']['ssl_chain'] is defined) and (app_params['nginx']['ssl']['ssl_chain'] is not none)
        %}
php-fpm_apps_app_nginx_ssl_certs_copy_{{ loop.index }}:
  file.recurse:
    - name: '/etc/nginx/ssl/{{ phpfpm_app }}'
    - source: {{ 'salt://' ~ app_params['nginx']['ssl']['certs_dir'] }}
    - user: root
    - group: root
    - dir_mode: 700
    - file_mode: 600

php-fpm_apps_app_nginx_vhost_config_{{ loop.index }}:
  file.managed:
    - name: '/etc/nginx/sites-available/{{ phpfpm_app }}.conf'
    - user: root
    - group: root
    - source: 'salt://{{ app_params['nginx']['vhost_config'] }}'
    - template: jinja
    - defaults:
        server_name: {{ app_params['nginx']['server_name'] }}
        server_name_301: '{{ server_name_301 }}'
        nginx_root: {{ app_params['nginx']['root'] }}
        access_log: {{ app_params['nginx']['access_log'] }}
        error_log: {{ app_params['nginx']['error_log'] }}
        php_version: {{ app_params['pool']['php_version'] }}
        app_name: {{ phpfpm_app }}
        app_root: {{ app_params['app_root'] }}
        ssl_cert: {{ app_params['nginx']['ssl']['ssl_cert'] }}
        ssl_key: {{ app_params['nginx']['ssl']['ssl_key'] }}
        ssl_chain: {{ app_params['nginx']['ssl']['ssl_chain'] }}
        ssl_cert_301: '/etc/nginx/ssl/{{ phpfpm_app }}/301_fullchain.pem'
        ssl_key_301: '/etc/nginx/ssl/{{ phpfpm_app }}/301_privkey.pem'
        auth_basic_block: '{{ auth_basic_block }}'

          {%- if not salt['file.file_exists']('/etc/nginx/ssl/' ~ phpfpm_app ~ '/301_fullchain.pem') %}
php-fpm_apps_app_nginx_ssl_link_1_{{ loop.index }}:
  file.symlink:
    - name: '/etc/nginx/ssl/{{ phpfpm_app }}/301_fullchain.pem'
    - target: '/etc/ssl/certs/ssl-cert-snakeoil.pem'
          {%- endif %}

          {%- if not salt['file.file_exists']('/etc/nginx/ssl/' ~ phpfpm_app ~ '/301_privkey.pem') %}
php-fpm_apps_app_nginx_ssl_link_2_{{ loop.index }}:
  file.symlink:
    - name: '/etc/nginx/ssl/{{ phpfpm_app }}/301_privkey.pem'
    - target: '/etc/ssl/private/ssl-cert-snakeoil.key'
          {%- endif %}

          {%- if
                 (app_params['nginx']['ssl']['certbot_for_301'] is defined) and (app_params['nginx']['ssl']['certbot_for_301'] is not none) and (app_params['nginx']['ssl']['certbot_for_301']) and
                 (app_params['nginx']['ssl']['certbot_email'] is defined) and (app_params['nginx']['ssl']['certbot_email'] is not none) and
                 (pillar['certbot_run_ready'] is defined) and (pillar['certbot_run_ready'] is not none) and (pillar['certbot_run_ready'])
          %}
php-fpm_apps_app_certbot_dir_{{ loop.index }}:
  file.directory:
    - name: '{{ app_params['app_root'] }}/certbot/.well-known'
    - user: {{ app_params['user'] }}
    - group: {{ app_params['group'] }}
    - makedirs: True

php-fpm_apps_app_certbot_run_{{ loop.index }}:
  cmd.run:
    - cwd: /root
    - name: '/opt/certbot/certbot-auto -n certonly --webroot {{ certbot_staging }} --reinstall --allow-subset-of-names --agree-tos --cert-name {{ phpfpm_app }} --email {{ app_params['nginx']['ssl']['certbot_email'] }} -w {{ app_params['app_root'] }}/certbot -d "{{ server_name_301|replace(" ", ",") }}"'

php-fpm_apps_app_certbot_replace_symlink_1_{{ loop.index }}:
  cmd.run:
    - cwd: /root
    - name: 'test -f /etc/letsencrypt/live/{{ phpfpm_app }}/fullchain.pem && ln -s -f /etc/letsencrypt/live/{{ phpfpm_app }}/fullchain.pem /etc/nginx/ssl/{{ phpfpm_app }}/301_fullchain.pem || true'

php-fpm_apps_app_certbot_replace_symlink_2_{{ loop.index }}:
  cmd.run:
    - cwd: /root
    - name: 'test -f /etc/letsencrypt/live/{{ phpfpm_app }}/privkey.pem && ln -s -f /etc/letsencrypt/live/{{ phpfpm_app }}/privkey.pem /etc/nginx/ssl/{{ phpfpm_app }}/301_privkey.pem || true'

php-fpm_apps_app_certbot_cron_{{ loop.index }}:
  cron.present:
    - name: '/opt/certbot/certbot-auto renew --renew-hook "service nginx configtest && service nginx restart"'
    - identifier: 'certbot_cron'
    - user: root
    - minute: 10
    - hour: 2
    - dayweek: 1
          {%- endif %}

        {%- elif
               (app_params['nginx']['ssl'] is defined) and (app_params['nginx']['ssl'] is not none) and
               (app_params['nginx']['ssl']['certbot'] is defined) and (app_params['nginx']['ssl']['certbot'] is not none) and (app_params['nginx']['ssl']['certbot']) and
               (app_params['nginx']['ssl']['certbot_email'] is defined) and (app_params['nginx']['ssl']['certbot_email'] is not none)
        %}
php-fpm_apps_app_nginx_vhost_config_{{ loop.index }}:
  file.managed:
    - name: '/etc/nginx/sites-available/{{ phpfpm_app }}.conf'
    - user: root
    - group: root
    - source: 'salt://{{ app_params['nginx']['vhost_config'] }}'
    - template: jinja
    - defaults:
        server_name: {{ app_params['nginx']['server_name'] }}
        server_name_301: '{{ server_name_301 }}'
        nginx_root: {{ app_params['nginx']['root'] }}
        access_log: {{ app_params['nginx']['access_log'] }}
        error_log: {{ app_params['nginx']['error_log'] }}
        php_version: {{ app_params['pool']['php_version'] }}
        app_name: {{ phpfpm_app }}
        app_root: {{ app_params['app_root'] }}
        ssl_cert: '/etc/nginx/ssl/{{ phpfpm_app }}/fullchain.pem'
        ssl_key: '/etc/nginx/ssl/{{ phpfpm_app }}/privkey.pem'
        auth_basic_block: '{{ auth_basic_block }}'

          {%- if not salt['file.file_exists']('/etc/nginx/ssl/' ~ phpfpm_app ~ '/fullchain.pem') %}
php-fpm_apps_app_nginx_ssl_link_1_{{ loop.index }}:
  file.symlink:
    - name: '/etc/nginx/ssl/{{ phpfpm_app }}/fullchain.pem'
    - target: '/etc/ssl/certs/ssl-cert-snakeoil.pem'
          {%- endif %}

          {%- if not salt['file.file_exists']('/etc/nginx/ssl/' ~ phpfpm_app ~ '/privkey.pem') %}
php-fpm_apps_app_nginx_ssl_link_2_{{ loop.index }}:
  file.symlink:
    - name: '/etc/nginx/ssl/{{ phpfpm_app }}/privkey.pem'
    - target: '/etc/ssl/private/ssl-cert-snakeoil.key'
          {%- endif %}

          {%- if (pillar['certbot_run_ready'] is defined) and (pillar['certbot_run_ready'] is not none) and (pillar['certbot_run_ready']) %}
php-fpm_apps_app_certbot_dir_{{ loop.index }}:
  file.directory:
    - name: '{{ app_params['app_root'] }}/certbot/.well-known'
    - user: {{ app_params['user'] }}
    - group: {{ app_params['group'] }}
    - makedirs: True

php-fpm_apps_app_certbot_run_{{ loop.index }}:
  cmd.run:
    - cwd: /root
    - name: '/opt/certbot/certbot-auto -n certonly --webroot {{ certbot_staging }} --reinstall --allow-subset-of-names --agree-tos --cert-name {{ phpfpm_app }} --email {{ app_params['nginx']['ssl']['certbot_email'] }} -w {{ app_params['app_root'] }}/certbot -d "{{ app_params['nginx']['server_name']|replace(" ", ",") }}"'

php-fpm_apps_app_certbot_replace_symlink_1_{{ loop.index }}:
  cmd.run:
    - cwd: /root
    - name: 'test -f /etc/letsencrypt/live/{{ phpfpm_app }}/fullchain.pem && ln -s -f /etc/letsencrypt/live/{{ phpfpm_app }}/fullchain.pem /etc/nginx/ssl/{{ phpfpm_app }}/fullchain.pem || true'

php-fpm_apps_app_certbot_replace_symlink_2_{{ loop.index }}:
  cmd.run:
    - cwd: /root
    - name: 'test -f /etc/letsencrypt/live/{{ phpfpm_app }}/privkey.pem && ln -s -f /etc/letsencrypt/live/{{ phpfpm_app }}/privkey.pem /etc/nginx/ssl/{{ phpfpm_app }}/privkey.pem || true'

php-fpm_apps_app_certbot_cron_{{ loop.index }}:
  cron.present:
    - name: '/opt/certbot/certbot-auto renew --renew-hook "service nginx configtest && service nginx restart"'
    - identifier: 'certbot_cron'
    - user: root
    - minute: 10
    - hour: 2
    - dayweek: 1
          {%- endif %}
        {%- endif %}

        {%- set php_admin = app_params['pool'].get('php_admin', '; no other admin vals') %}
php-fpm_apps_app_pool_config_{{ loop.index }}:
  file.managed:
    - name: '/etc/php/{{ app_params['pool']['php_version'] }}/fpm/pool.d/{{ phpfpm_app }}.conf'
    - user: root
    - group: root
    - source: 'salt://{{ app_params['pool']['pool_config'] }}'
    - template: jinja
    - defaults:
        app_name: {{ phpfpm_app }}
        user: {{ app_params['user'] }}
        group: {{ app_params['group'] }}
        php_version: {{ app_params['pool']['php_version'] }}
        pm: {{ app_params['pool']['pm'] | yaml_encode }}
        php_admin: {{ php_admin | yaml_encode }}

php-fpm_apps_pool_log_dir_{{ loop.index }}:
  file.directory:
    - name: '/var/log/php/{{ app_params['pool']['php_version'] }}-fpm/'
    - user: root
    - group: adm
    - mode: 775
    - makedirs: True

php-fpm_apps_pool_log_file_{{ loop.index }}:
  file.managed:
    - name: '/var/log/php/{{ app_params['pool']['php_version'] }}-fpm/{{ phpfpm_app }}.error.log'
    - user: {{ app_params['user'] }}
    - group: {{ app_params['group'] }}
    - mode: 664

php-fpm_apps_pool_logrotate_file_{{ loop.index }}:
  file.managed:
    - name: '/etc/logrotate.d/php{{ app_params['pool']['php_version'] }}-fpm-{{ phpfpm_app }}'
    - user: root
    - group: root
    - mode: 644
    - contents: |
        /var/log/php/{{ app_params['pool']['php_version'] }}-fpm/{{ phpfpm_app }}.error.log {
          rotate 31
          daily
          missingok
          create 664 {{ app_params['user'] }} {{ app_params['group'] }}
          compress
          delaycompress
          su root adm
        }

      {%- endif %}
    {%- endfor %}
  {%- endif %}
{%- endif %}

php-fpm_apps_info_warning:
  test.configurable_test_state:
    - name: state_warning
    - changes: False
    - result: True
    - comment: |
        WARNING: State configures nginx virtual hosts, BUT it doesn't reload or restart nginx, php-fpm.
        WARNING: It is done so not to break running production sites on the host.
        WARNING: You should state.apply this state first, then check configs, reload or restart nginx, pfp-fpm manually.
        WARNING: After that there will be /.well-known/ location ready to serve certbot request.
        WARNING: For the second time you can run:
        WARNING: state.apply ... pillar='{"certbot_run_ready": True}'
        WARNING: This will activate certbot execution and active its certs in nginx.
        WARNING: After that you can check and reload again.
        WARNING: Also, not to be temp banned by LE when making test runs, you can run:
        WARNING: state.apply ... pillar='{"certbot_run_ready": True, "certbot_staging": True}'
        WARNING: This will add --staging option to certbot. Certificate will be not trusted, but LE will allow much more tests.
        NOTICE:  You can run only one app with pillar:
        NOTICE:  state.apply ... pillar='{"app_only_one": "<app_name>"}'
