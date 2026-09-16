kind: manual
description: Install the OCI appliance launcher and runtime filesystem.

sources:
  - kind: local
    path: files

build-depends:
  - freedesktop-sdk.bst:public-stacks/runtime-gnu.bst

config:
  install-commands:
    - install -D -m 755 container-entrypoint.sh "%{install-root}/usr/libexec/ghostscript-printer-app/container-entrypoint"
    - install -d -m 0777 "%{install-root}/run/dbus" "%{install-root}/run/avahi-daemon" "%{install-root}/run/ghostscript-printer-app"
    - install -d -m 0777 "%{install-root}/var/lib/ghostscript-printer-app" "%{install-root}/var/spool/ghostscript-printer-app"
