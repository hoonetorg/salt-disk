# vim: sts=2 ts=2 sw=2 et ai
{% from "disk/map.jinja" import disk with context %}

disk_part__pkg_partprogs:
  pkg.installed:
    - pkgs: {{disk.pkgs.part}}
{% if disk.get('part', {} ).get('slsrequires', False) %}
    - require:
{% for slsrequire in disk.get('part', {} ).get('slsrequires', []) %}
      - {{slsrequire}}
{% endfor %}
{% endif %}


{% for device, device_data in disk.get('part', {} ).get('devices', {}).items() %}
  {# if device|regex_search('disk/by-') not in [ None ] #}
  {% if device|regex_match('^/dev/disk/by-') not in [ None ] %}
    {% set part_prefix = '-part' %}
  {% else %}
    {% set part_prefix = '' %}
  {% endif %}
#debug: device: '{{device}}' part_prefix: '{{part_prefix}}'
disk_part__create_part_table_{{ device }}:
  module.run:
    - name: parted.mklabel
    - device: {{ device }}
    - label_type: {{ device_data.label_type|default('gpt') }} 
    - unless: partprobe  {{ device }} && parted -s {{ device }} print
    - python_shell: True
    - require:
      - pkg: disk_part__pkg_partprogs

  {% for part, part_data in device_data.items() %}
disk_part__create_part_{{ device }}_{{ part }}:
  cmd.run:
    - name: 'sgdisk -n {{ part }}:{{ part_data.start }}:{{ part_data.end }} -c {{ part }}:"{{ part_data.name }}" -t {{ part }}:{{ part_data.type }} {{ device }} && partprobe {{ device }}'
    - unless: partprobe {{device }} && lsblk {{ device }}{{ part_prefix }}{{ part }}
    - require:
      - module: disk_part__create_part_table_{{ device }}
    {% for partrequire in part_data.get('requires', []) %}
      - {{partrequire}}
    {% endfor %}
  {% endfor %}

{% endfor %}

