disk_lvm__pkg_lvm2:
  pkg:
    - name: {{disk.pkgs.lvm}}
    - installed
{% set slsrequires = disk.lvm.slsrequires|default(False) %}
{% if slsrequires is defined and slsrequires %}
    - require:
{% for slsrequire in slsrequires %}
      - {{slsrequire}}
{% endfor %}
{% endif %}

disk_lvm__file_/etc/lvm/lvm.conf:
  augeas.change:
    - name: /etc/lvm/lvm.conf
    - context: /files/etc/lvm/lvm.conf
    - changes:
      - set global/dict/use_lvmetad/int 1

disk_lvm__cmd_start_lvm2-lvmetad.service:
  cmd.run:
    - name: systemctl start lvm2-lvmetad.service
    - unless: systemctl is-active lvm2-lvmetad.service
    - require:
      - pkg: disk_lvm__pkg_lvm2
      - augeas: disk_lvm__file_/etc/lvm/lvm.conf

disk_lvm__cmd_start_lvm2-monitor.service:
  cmd.run:
    - name: systemctl start lvm2-monitor.service
    - unless: systemctl is-active lvm2-monitor.service
    - require:
      - pkg: disk_lvm__pkg_lvm2
      - augeas: disk_lvm__file_/etc/lvm/lvm.conf

{% for vg , vg_data in disk.lvm.vgs.items()|default({})|sort %}
{% if vg_data.pvs is defined and vg_data.pvs and vg_data.lvs is defined and vg_data.lvs %}

{% for pv in vg_data.pvs|sort %}
disk_lvm__pv_{{pv}}:
  lvm.pv_present:
    - name: {{pv}}
    - require:
      - pkg: disk_lvm__pkg_lvm2
      - augeas: disk_lvm__file_/etc/lvm/lvm.conf
      - cmd: disk_lvm__cmd_start_lvm2-lvmetad.service
      - cmd: disk_lvm__cmd_start_lvm2-monitor.service
{% if vg_data.requires is defined and vg_data.requires %}
{% for vgrequire in vg_data.requires %}
      - {{vgrequire}}
{% endfor %}
{% endif %}

{% endfor %}

disk_lvm__vg_{{vg}}:
  lvm.vg_present:
    - name: {{vg}}
    - devices: {% for pv in vg_data.pvs|sort -%}{{ pv }}{% if loop.last %}{%else%},{% endif %}{% endfor %} 
    - require:
{% for pv in vg_data.pvs|sort %}
      - lvm: disk_lvm__pv_{{pv}}
{% endfor -%}

{% for lv , lv_data in vg_data.lvs.items()|sort %}
disk_lvm__lv_{{vg}}_{{lv}}:
  lvm.lv_present:
    - name: {{lv}}
    - vgname: {{vg}}
{% if lv_data.size is defined and lv_data.size %}
    - size: {{lv_data.size}}
{% endif %} 
{% if lv_data.extents is defined and lv_data.extents %}
    - extents: {{lv_data.extents}}
{% endif %} 
    - require:
      - lvm: disk_lvm__vg_{{vg}}


disk_lvm__cmd_vgchange_aey_{{vg}}_{{lv}}:
  cmd.run:
    - name: lvchange -aey {{vg}}/{{lv}}
    - unless: test -L /dev/{{vg}}/{{lv}}
    - require:
      - lvm: disk_lvm__lv_{{vg}}_{{lv}}
{% endfor %}

{% endif %} 
{% endfor %}
