{% if pillar["app"] is defined and "python" in pillar["app"] %}

  {%- if "pyenv" in pillar["app"]["python"] %}
    {%- set pyenv = pillar["app"]["python"]["pyenv"] %}
    {%- include "pyenv/pyenv.sls" with context %}
  {%- endif %}

  {%- for app_name, app in pillar["app"]["python"]["apps"].items() %}
    {%- if not "deploy_only" in pillar["app"]["python"] or app_name in pillar["app"]["python"]["deploy_only"] %}

      {%- set app_type = "python" %}
      {%- set loop_index = loop.index %}
      {%- include "app/user_and_source.sls" with context %}

      {%- if "virtualenv" in app %}
app_python_app_virtualenv_dir_{{ loop.index }}:
  file.directory:
    - name: {{ app["virtualenv"]["target"] }}
    - user: {{ app["user"] }}
    - group: {{ app["group"] }}
    - mode: 755
    - makedirs: True

app_python_app_virtualenv_python_version_{{ loop.index }}:
  file.managed:
    - name: {{ app["virtualenv"]["target"] ~ "/.python-version" }}
    - user: {{ app["user"] }}
    - group: {{ app["group"] }}
    - mode: 0644
    - contents:
      - {{ app["virtualenv"]["pyenv_version"] }}

app_python_app_virtualenv_pip_{{ loop.index }}:
  cmd.run:
    - cwd: /tmp
    - env:
        PYENV_VERSION: {{ app["virtualenv"]["pyenv_version"] }}
    - name: /usr/local/pyenv/shims/pip install virtualenv

app_python_app_virtualenv_bin_{{ loop.index }}:
  file.managed:
    - name: {{ app["app_root"] ~ "/virtualenv-" ~ app["virtualenv"]["pyenv_version"] }}
    - user: {{ app["user"] }}
    - group: {{ app["group"] }}
    - mode: 0755
    - contents: |
        #!/bin/sh
        export PYENV_VERSION={{ app["virtualenv"]["pyenv_version"] }}
        /usr/local/pyenv/shims/virtualenv "$@"

app_python_app_virtualenv_{{ loop.index }}:
  virtualenv.managed:
    - name: {{ app["virtualenv"]["target"] }}
    - python: /usr/local/pyenv/shims/python
    - user: {{ app["user"] }}
    - system_site_packages: False
    - venv_bin: {{ app["app_root"] ~ "/virtualenv-" ~ app["virtualenv"]["pyenv_version"] }}
    - env_vars:
        PYENV_VERSION: {{ app["virtualenv"]["pyenv_version"] }}

      {%- endif %}

      {%- include "app/setup_scripts.sls" with context %}

    {%- endif %}
  {%- endfor %}
{% endif %}

