# vim: sts=2 ts=2 sw=2 et ai
{% from "disk/map.jinja" import disk with context %}
#{{disk|yaml}}
disk_encr__pkg_cryptsetup:
  pkg.installed:
    - pkgs: {{disk.pkgs.encr|yaml}}
{% set slsrequires = disk.encr.slsrequires|default(False) %}
{% if slsrequires is defined and slsrequires %}
    - require:
{% for slsrequire in slsrequires %}
      - {{slsrequire}}
{% endfor %}
{% endif %}

disk_encr__file_/etc/crypttab.d:
  file.directory:
    - name: /etc/crypttab.d
    - user: root
    - group: root
    - mode: 700
    - makedirs: True
    - require:
      - pkg: disk_encr__pkg_cryptsetup

{% for encrdisk , encrdisk_data in disk.encr.disks.items()|default({}) %}
{% if encrdisk_data.device is defined and encrdisk_data.device %}

disk_encr__file_/etc/crypttab.d/keyfile-{{encrdisk}}:
  file.managed:
    - name: /etc/crypttab.d/keyfile-{{encrdisk}}
    - contents: {{ salt['hashutil.base64_decodestring'](encrdisk_data.keyfile_base64)|yaml|indent(8) }}
    - contents_newline : False
    - show_diff: False
    - user: root
    - group: root
    - mode: 400
    - require:
      - file: disk_encr__file_/etc/crypttab.d

disk_encr__luks_create_{{encrdisk}}:
  cmd.run:
    - unless: "cryptsetup isLuks {{encrdisk_data.device}}"
    - name: "yes|cryptsetup luksFormat -c aes-xts-plain64 -s 512 -h sha512 -i 5000 --use-random --align-payload=2048 --key-slot=0 {{encrdisk_data.device}} /etc/crypttab.d/keyfile-{{encrdisk}}"
    - require:
      - file: disk_encr__file_/etc/crypttab.d/keyfile-{{encrdisk}}
{% if encrdisk_data.requires is defined and encrdisk_data.requires %}
{% for encrdiskrequire in encrdisk_data.requires %}
      - {{encrdiskrequire}}
{% endfor %}
{% endif %}

disk_encr__luks_addpw_{{encrdisk}}:
  cmd.run:
    - unless: "cryptsetup luksDump {{encrdisk_data.device}}|grep -q 'Key Slot 1: ENABLED'" 
    - name: "echo '{{ encrdisk_data.passwd|default(disk.defaultpasswd) }}' |cryptsetup luksAddKey --key-slot=1 --key-file=/etc/crypttab.d/keyfile-{{encrdisk}} {{encrdisk_data.device}}"
    - require:
      - file: disk_encr__file_/etc/crypttab.d/keyfile-{{encrdisk}}
      - cmd: disk_encr__luks_create_{{encrdisk}}

disk_encr__luks_open_{{encrdisk}}:
  cmd.run:
    - unless: "stat /dev/mapper/{{encrdisk}}"
    - name: cryptsetup luksOpen --allow-discards --key-slot=0 --key-file=/etc/crypttab.d/keyfile-{{encrdisk}} {{encrdisk_data.device}} {{encrdisk}}
    - require:
      - file: disk_encr__file_/etc/crypttab.d/keyfile-{{encrdisk}}
      - cmd: disk_encr__luks_create_{{encrdisk}}
    - require_in:
      - file: disk_encr__/etc/crypttab_{{encrdisk}}

disk_encr__/etc/crypttab_{{encrdisk}}:
  file.replace:
    - name: /etc/crypttab
    - pattern: ^\s*{{encrdisk}}\s+.*$
    - repl: "{{encrdisk}} {{encrdisk_data.device}} /etc/crypttab.d/keyfile-{{encrdisk}} luks,discard,key-slot=0"
    - count: 1
    - append_if_not_found: True
{% endif %} 
{% endfor %}
