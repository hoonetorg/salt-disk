{% set pathsls = sls.replace('.','/') -%}

disk_usbnosleep__pkg_sdparm:
  pkg:
    - name: sdparm
    - installed
{% set slsrequires =salt['pillar.get']('disk:usbnosleep:slsrequires', False) %}
{% if slsrequires is defined and slsrequires %}
    - require:
{% for slsrequire in slsrequires %}
      - {{slsrequire}}
{% endfor %}
{% endif %}

disk_usbnosleep__file_/etc/udev/rules.d:
  file.directory:
    - name: /etc/udev/rules.d
    - user: root
    - group: root
    - mode: 755
    - makedirs: True
    - require:
      - pkg: disk_usbnosleep__pkg_sdparm

disk_usbnosleep__file_/etc/udev/rules.d/60-persistent-usbstorage-sleep.rules:
  file.managed:
    - name: /etc/udev/rules.d/60-persistent-usbstorage-sleep.rules
    - user: root
    - group: root
    - mode: 644
    - require:
      - file: disk_usbnosleep__file_/etc/udev/rules.d
    - watch_in:
      - cmd: disk_usbnosleep__cmd_systemd-udevd.service
      - cmd: disk_usbnosleep__cmd_systemd-udev-trigger.service
      - cmd: disk_usbnosleep__cmd_systemd-udev-settle.service
    - source: salt://{{ pathsls }}/60-persistent-usbstorage-sleep.rules
 

disk_usbnosleep__cmd_systemd-udevd.service:
  cmd.wait:
    - name: systemctl restart systemd-udevd.service
    - require:
      - file: disk_usbnosleep__file_/etc/udev/rules.d/60-persistent-usbstorage-sleep.rules

disk_usbnosleep__cmd_systemd-udev-trigger.service:
  cmd.wait:
    - name: systemctl restart systemd-udev-trigger.service
    - require:
      - file: disk_usbnosleep__file_/etc/udev/rules.d/60-persistent-usbstorage-sleep.rules
      - cmd: disk_usbnosleep__cmd_systemd-udevd.service

disk_usbnosleep__cmd_systemd-udev-settle.service:
  cmd.wait:
    - name: systemctl restart systemd-udev-settle.service
    - require:
      - file: disk_usbnosleep__file_/etc/udev/rules.d/60-persistent-usbstorage-sleep.rules
      - cmd: disk_usbnosleep__cmd_systemd-udevd.service
      - cmd: disk_usbnosleep__cmd_systemd-udev-trigger.service
