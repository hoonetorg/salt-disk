{% set initial_passwd = pillar['initial_passwd'] %}

disk_encr__pkg_cryptsetup:
  pkg:
    - name: cryptsetup
    - installed
{% set slsrequires =salt['pillar.get']('disk:encr:slsrequires', False) %}
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

disk_encr__file_/etc/crypttab.d/keyfile:
  file.managed:
    - name: /etc/crypttab.d/keyfile
    - source: salt://files/keys/disks/keyfile
    - show_diff: False
    - user: root
    - group: root
    - mode: 400
    - require:
      - file: disk_encr__file_/etc/crypttab.d


{% for encrdisk , encrdisk_data in salt['pillar.get']('disk:encr:disks', {}).items() %}
{% if encrdisk_data.device is defined and encrdisk_data.device %}

disk_encr__luks_create_{{encrdisk}}:
  cmd.run:
    - unless: "cryptsetup isLuks {{encrdisk_data.device}}"
    - name: "yes|cryptsetup luksFormat -c aes-xts-plain64 -s 512 -h sha512 -i 5000 --use-random --align-payload=2048 --key-slot=0 {{encrdisk_data.device}} /etc/crypttab.d/keyfile"
    - require:
      - file: disk_encr__file_/etc/crypttab.d/keyfile
{% if encrdisk_data.requires is defined and encrdisk_data.requires %}
{% for encrdiskrequire in encrdisk_data.requires %}
      - {{encrdiskrequire}}
{% endfor %}
{% endif %}

disk_encr__luks_addpw_{{encrdisk}}:
  cmd.run:
    - unless: "cryptsetup luksDump {{encrdisk_data.device}}|grep -q 'Key Slot 1: ENABLED'" 
    - name: "echo '{{ initial_passwd }}' |cryptsetup luksAddKey --key-slot=1 --key-file=/etc/crypttab.d/keyfile {{encrdisk_data.device}}"
    - require:
      - file: disk_encr__file_/etc/crypttab.d/keyfile
      - cmd: disk_encr__luks_create_{{encrdisk}}

disk_encr__luks_open_{{encrdisk}}:
  cmd.run:
    - unless: "stat /dev/mapper/{{encrdisk}}"
    - name: cryptsetup luksOpen --allow-discards --key-slot=0 --key-file=/etc/crypttab.d/keyfile {{encrdisk_data.device}} {{encrdisk}}
    - require:
      - file: disk_encr__file_/etc/crypttab.d/keyfile
      - cmd: disk_encr__luks_create_{{encrdisk}}
    - require_in:
      - file: disk_encr__/etc/crypttab

{% endif %} 
{% endfor %}

disk_encr__/etc/crypttab:
  file.append:
    - name: /etc/crypttab
    - text:
{% for encrdisk , encrdisk_data in salt['pillar.get']('disk:encr:disks', {}).items() %}
{% if encrdisk_data.device is defined and encrdisk_data.device %}
      - "{{encrdisk}} {{encrdisk_data.device}} /etc/crypttab.d/keyfile    luks,discard,key-slot=0"
{% endif %} 
{% endfor %}
