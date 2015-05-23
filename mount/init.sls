disk_mount__pkg_e2fsprogs:
  pkg:
    - name: e2fsprogs
    - installed
{% set slsrequires =salt['pillar.get']('disk:mount:slsrequires', False) %}
{% if slsrequires is defined and slsrequires %}
    - require:
{% for slsrequire in slsrequires %}
      - {{slsrequire}}
{% endfor %}
{% endif %}

{% for mount , mount_data in salt['pillar.get']('disk:mount:mounts', {}).items() %}
{% if mount_data.device is defined and mount_data.device and mount_data.fstype is defined and mount_data.fstype %}

disk_mount__blockdev_{{mount_data.device}}:
  cmd.run:
    - name: test -z "`lsblk -o fstype {{mount_data.device}}|tail -1`" && mkfs.{{mount_data.fstype}} {% if mount_data.mkfsopts is defined and mount_data.mkfsopts %} {{mount_data.mkfsopts}} {% endif %} {{mount_data.device}} && sync && udevadm settle && lsblk -o fstype {{mount_data.device}} |tail -1|grep {{mount_data.fstype}}
    - unless: lsblk -o fstype {{mount_data.device}} |tail -1|grep {{mount_data.fstype}}
    - require:
      - pkg: disk_mount__pkg_e2fsprogs
{% if mount_data.requires is defined and mount_data.requires %}
{% for mountrequire in mount_data.requires %}
      - {{mountrequire}}
{% endfor %}
{% endif %}
    - timeout: 600
    - require_in:
      - mount: disk_mount__mount_{{mount}}

{#
disk_mount__blockdev_{{mount_data.device}}:
  blockdev.formatted:
    - name: {{mount_data.device}}
    - fs_type: {{mount_data.fstype}}
{% if mount_data.inodesize is defined and mount_data.inodesize %}
    - inode_size: {{mount_data.inodesize}}
{% endif %} 
    - require:
      - pkg: disk_mount__pkg_e2fsprogs
{% if mount_data.requires is defined and mount_data.requires %}
{% for mountrequire in mount_data.requires %}
      - {{mountrequire}}
{% endfor %}
{% endif %} 
    - timeout: 600
    - require_in:
      - mount: disk_mount__mount_{{mount}}
#}

disk_mount__mount_{{mount}}:
  mount.mounted:
    - name: {{mount}}
    - device: {{mount_data.device}}
    - fstype: {{mount_data.fstype}}
{% if mount_data.opts is defined and mount_data.opts %}
    - opts: {{mount_data.opts}}
{% endif %} 
    - mkmnt: True

{% endif %} 
{% endfor %}
