# vim: sts=2 ts=2 sw=2 et ai
{% from "disk/map.jinja" import disk with context %}

disk_raid__pkg__mdadm:
  pkg.installed:
    - pkgs: {{disk.pkgs.raid}}
{% set slsrequires = disk.raid.slsrequires|default(False) %}
{% if slsrequires is defined and slsrequires %}
    - require:
{% for slsrequire in slsrequires %}
      - {{slsrequire}}
{% endfor %}
{% endif %}

{% set mdadmconf = "/etc/mdadm.conf" %}

{% for md , md_data in disk.raid.mds.items()|default({})|sort %}
{% if md_data.level is defined and md_data.level and md_data.metadata is defined and md_data.metadata and md_data.devices is defined and md_data.devices %}

disk_raid__create_{{md}}:
  cmd.run:
    - name: mdadm -C {{md}} -v -l {{md_data.level}} -e {{md_data.metadata}} {% if md_data.opts is defined and md_data.opts -%}{{md_data.opts}}{% endif %} -n {{md_data.devices|length}} {% for device in md_data.devices|sort -%}{{device}} {% endfor %}

    - require:
      - pkg: disk_raid__pkg__mdadm
{% if md_data.requires is defined and md_data.requires %}
{% for mdrequire in md_data.requires|sort %}
      - {{mdrequire}}
{% endfor %}
{% endif %}
    - unless: mdadm -E {% for device in md_data.devices|sort -%}{{device}} {% endfor %}


disk_raid__mdadm_conf_{{md}}:
  cmd.run:
    - name:  export MYUUID="`mdadm -Ebs {% for device in md_data.devices|sort -%}{{device}} {% endfor -%}|sed -r 's|.*[[:blank:]]+(UUID=[^[:blank:]]+)[[:blank:]]+.*$|\1|g'`" && ( egrep -qw "$MYUUID" {{mdadmconf}} && sed -i -r "/^.*$MYUUID.*$/d" {{mdadmconf}} || echo "" ) && echo "ARRAY {{md}} level=raid{{md_data.level}} num-devices={{md_data.devices|length}} $MYUUID" >> {{mdadmconf}}
    - unless:  export MYUUID="`mdadm -Ebs {% for device in md_data.devices|sort -%}{{device}} {% endfor -%}|sed -r 's|.*[[:blank:]]+(UUID=[^[:blank:]]+)[[:blank:]]+.*$|\1|g'`" && egrep -q "^[[:blank:]]*ARRAY[[:blank:]]+{{md}}[[:blank:]]+level=raid{{md_data.level}}[[:blank:]]+num-devices={{md_data.devices|length}}[[:blank:]]+$MYUUID" {{mdadmconf}} 
    - require: 
      - cmd: disk_raid__create_{{md}}

disk_raid__start_{{md}}:
  cmd.run:
    - name: mdadm -As {{md}}
    - unless: mdadm -D {{md}}
    - require:
      - cmd: disk_raid__create_{{md}}

disk_raid__started_{{md}}:
  cmd.run:
    - name: mdadm -D {{md}}
    - unless: mdadm -D {{md}}
    - require:
      - cmd: disk_raid__start_{{md}}
      - cmd: disk_raid__mdadm_conf_{{md}}

{% endif %}
{% endfor %}
