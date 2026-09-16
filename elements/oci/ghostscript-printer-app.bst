kind: script

build-depends:
  - freedesktop-sdk.bst:bootstrap/bash.bst
  - freedesktop-sdk.bst:bootstrap/coreutils.bst
  - freedesktop-sdk.bst:components/oci-builder.bst
  - freedesktop-sdk.bst:components/sed.bst
  - filename: printer-app/core-runtime.bst
    config:
      location: /layer

config:
  commands:
    - |
      install -d /layer/etc
      printf '%s\n' 'nonroot:x:65532:65532:Printer Application:/var/lib/ghostscript-printer-app:/usr/sbin/nologin' >> /layer/etc/passwd
      printf '%s\n' 'nonroot:x:65532:' >> /layer/etc/group
      if [ -f /layer/usr/share/dbus-1/system.conf ]; then
        sed -i 's/<user>messagebus<\/user>/<user>nonroot<\/user>/' /layer/usr/share/dbus-1/system.conf
      fi
      if [ -f /layer/usr/share/dbus-1/system.d/avahi-dbus.conf ]; then
        sed -i 's/<policy group="netdev">/<policy group="nonroot">/g; s/<policy user="root">/<policy user="nonroot">/g' /layer/usr/share/dbus-1/system.d/avahi-dbus.conf
      fi
      cd "%{install-root}"
      build-oci <<EOF
      mode: oci
      gzip: disabled
      images:
        - os: linux
          architecture: "%{go-arch}"
          layer: /layer
          config:
            User: '65532:65532'
            Entrypoint: ['/usr/bin/catatonit', '--', '/usr/bin/bash', '/usr/libexec/ghostscript-printer-app/container-entrypoint']
            Env:
              - 'HOME=/var/lib/ghostscript-printer-app'
              - 'PATH=/usr/bin:/usr/sbin'
            Labels:
              'org.opencontainers.image.title': 'ghostscript-printer-app'
              'org.opencontainers.image.description': 'Ghostscript Printer Application built from freedesktop-sdk'
              'org.opencontainers.image.source': 'https://github.com/projectbluefin/ghostscript-printer-app'
              'org.opencontainers.image.licenses': 'Apache-2.0'
              'org.opencontainers.image.version': '10.07.1-1'
              'io.projectbluefin.fsdk.version': '26.08rc.1'
      EOF
