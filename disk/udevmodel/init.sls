{% set pathsls = sls.replace('.','/') -%}

disk_udevmodel__pkg_hdparm:
  pkg:
    - name: hdparm
    - installed
{% set slsrequires =salt['pillar.get']('disk:udevmodel:slsrequires', False) %}
{% if slsrequires is defined and slsrequires %}
    - require:
{% for slsrequire in slsrequires %}
      - {{slsrequire}}
{% endfor %}
{% endif %}

disk_udevmodel__file_/usr/local/sbin:
  file.directory:
    - name: /usr/local/sbin
    - user: root
    - group: root
    - mode: 755
    - makedirs: True
    - require:
      - pkg: disk_udevmodel__pkg_hdparm

disk_udevmodel__file_/usr/local/sbin/diskmodel:
  file.managed:
    - name: /usr/local/sbin/diskmodel
    - user: root
    - group: root
    - mode: 755
    - require:
      - file: disk_udevmodel__file_/usr/local/sbin
    - source: salt://{{ pathsls }}/diskmodel

disk_udevmodel__file_/etc/udev/rules.d:
  file.directory:
    - name: /etc/udev/rules.d
    - user: root
    - group: root
    - mode: 755
    - makedirs: True
    - require:
      - file: disk_udevmodel__file_/usr/local/sbin/diskmodel

disk_udevmodel__file_/etc/udev/rules.d/60-persistent-diskmodel.rules:
  file.managed:
    - name: /etc/udev/rules.d/60-persistent-diskmodel.rules
    - user: root
    - group: root
    - mode: 644
    - require:
      - file: disk_udevmodel__file_/etc/udev/rules.d
    - watch_in:
      - cmd: disk_udevmodel__cmd_systemd-udevd.service
      - cmd: disk_udevmodel__cmd_systemd-udev-trigger.service
      - cmd: disk_udevmodel__cmd_systemd-udev-settle.service
    - source: salt://{{ pathsls }}/60-persistent-diskmodel.rules
 

disk_udevmodel__cmd_systemd-udevd.service:
  cmd.wait:
    - name: systemctl restart systemd-udevd.service
    - require:
      - file: disk_udevmodel__file_/etc/udev/rules.d/60-persistent-diskmodel.rules

disk_udevmodel__cmd_systemd-udev-trigger.service:
  cmd.wait:
    - name: systemctl restart systemd-udev-trigger.service
    - require:
      - file: disk_udevmodel__file_/etc/udev/rules.d/60-persistent-diskmodel.rules
      - cmd: disk_udevmodel__cmd_systemd-udevd.service

disk_udevmodel__cmd_systemd-udev-settle.service:
  cmd.wait:
    - name: systemctl restart systemd-udev-settle.service
    - require:
      - file: disk_udevmodel__file_/etc/udev/rules.d/60-persistent-diskmodel.rules
      - cmd: disk_udevmodel__cmd_systemd-udevd.service
      - cmd: disk_udevmodel__cmd_systemd-udev-trigger.service
