kind: stack
description: Core Ghostscript Printer Application appliance stack.

depends:
  - printer-app/application.bst
  - printer-app/core-payload.bst
  - printer-app/runtime-files.bst
  - printer-app/c2050.bst
  - printer-app/cjet.bst
  - printer-app/min12xxw.bst
  - printer-app/pnm2ppa.bst
  - freedesktop-sdk.bst:public-stacks/runtime-gnu.bst
  - freedesktop-sdk.bst:components/avahi.bst
  - freedesktop-sdk.bst:components/ca-certificates.bst
  - freedesktop-sdk.bst:components/catatonit.bst
  - freedesktop-sdk.bst:components/cups-daemon-only.bst
  - freedesktop-sdk.bst:components/cups-filters.bst
  - freedesktop-sdk.bst:components/dbus.bst
  - freedesktop-sdk.bst:components/ghostscript.bst
  - freedesktop-sdk.bst:components/libcupsfilters.bst
  - freedesktop-sdk.bst:components/libppd.bst
  - freedesktop-sdk.bst:components/mutool.bst
  - freedesktop-sdk.bst:components/python3.bst
  - freedesktop-sdk.bst:components/xz.bst
  - freedesktop-sdk.bst:components/tzdata.bst
