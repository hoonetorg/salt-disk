# vim: sts=2 ts=2 sw=2 et ai
{% from "disk/map.jinja" import disk with context %}

disk_mount__pkg_fsprogs:
  pkg.installed:
    - pkgs: {{disk.pkgs.mount}}
{% set slsrequires = disk.mount.slsrequires|default(False) %}
{% if slsrequires is defined and slsrequires %}
    - require:
{% for slsrequire in slsrequires %}
      - {{slsrequire}}
{% endfor %}
{% endif %}


{% for mount , mount_data in disk.mount.mounts.items()|default({}) %}

{% if mount_data.get('fstype', False) %}

  {% if mount_data.fstype not in ['btrfs'] %}
    {% if mount_data.get('device', False) %}
disk_mount__blockdev_{{mount_data.device}}:
{# broken sometimes
  blockdev.formatted:
    - name: {{mount_data.device}}
    - fs_type: {{mount_data.fstype}}
      {% if mount_data.inodesize is defined and mount_data.inodesize %}
    - inode_size: {{mount_data.inodesize}}
      {% endif %} 
#}
  module.run:
    - name: cmd.run
    - cmd: test -z "`lsblk -o fstype {{mount_data.device}}|tail -1`" && mkfs.{{mount_data.fstype}} {% if mount_data.mkfsopts is defined and mount_data.mkfsopts %} {{mount_data.mkfsopts}} {% endif %} {{mount_data.device}} && sync && udevadm settle && lsblk -o fstype {{mount_data.device}} |tail -1|grep {{mount_data.fstype}}
    - unless: lsblk -o fstype {{mount_data.device}} |tail -1|grep {{mount_data.fstype}}
    - python_shell: True
    {% endif %}

  {% elif mount_data.fstype in ['btrfs']%}
    {% if mount_data.get('devices', False) %}
disk_mount__blockdev_{{mount_data.devices|join('_')}}:
  module.run:
    - name: btrfs.mkfs
    - devices: {{mount_data.devices|json}}
    - kwargs: {{mount_data.get('btrfs_opts', {})|json}}
    - unless: 
      {% for device in mount_data.devices %}
      - lsblk -o fstype {{device}} |tail -1|grep {{mount_data.fstype}}
      {% endfor %}
    - python_shell: True
    {% endif %}
  {# elif mount_data.fstype in ['other_multidevice_filesystem'] #}
  {% endif %}
    - require:
      - pkg: disk_mount__pkg_fsprogs
  {% if mount_data.requires is defined and mount_data.requires %}
    {% for mountrequire in mount_data.requires %}
      - {{mountrequire}}
    {% endfor %}
  {% endif %}
    - timeout: 600
    - require_in:
      - mount: disk_mount__mount_{{mount}}

disk_mount__mount_{{mount}}:
  mount.mounted:
    - name: {{mount}}
    - device: {{mount_data.mount_device|default(mount_data.get('device'))}}
    - fstype: {{mount_data.fstype}}
  {% if mount_data.fstype in ['btrfs'] %}
    - opts: {{mount_data.get('opts', ['defaults'])+['subvolid=0']}}
    - extra_mount_invisible_options: ['subvolid=0']
  {% else %} 
    {% if mount_data.get('opts', False) %}
    - opts: {{mount_data.opts|json}}
    {% endif %} 
  {% endif %} 
    - match_on:
      - name
      - device
    - mkmnt: True

  {%for subvolume, subvolume_data in mount_data.get('subvolumes', {}).items()|sort %}
disk_mount__subvol_create_{{mount}}_{{subvolume}}:
  cmd.run:
    - name: btrfs subvol create {{mount}}/{{subvolume}}
    - unless: btrfs subvol list {{mount}}|awk '{print $NF}'|grep -w {{subvolume}}
    - require:
      - mount: disk_mount__mount_{{mount}}

    {% if subvolume_data.get('mountpoint', False) %}
disk_mount__subvol_mount_{{mount}}_{{subvolume}}:
  mount.mounted:
    - name: {{subvolume_data.mountpoint }}
    - device: {{mount_data.mount_device|default(mount_data.get('device'))}}
    - fstype: {{mount_data.fstype}}
    - opts: {{subvolume_data.get('opts', mount_data.get('opts', ['defaults'])) + ['subvol=' + subvolume]}}
    - extra_mount_invisible_options: {{['subvol=' + subvolume]}}
    - match_on:
      - name
      - device
    - mkmnt: True
    - require:
      - cmd: disk_mount__subvol_create_{{mount}}_{{subvolume}}
    {% endif %}

  {% endfor %}

{% endif %} 
{% endfor %}
