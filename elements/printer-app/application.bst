kind: manual
description: Build the Ghostscript Printer Application executable.

sources:
  - kind: local
    path: Makefile
  - kind: local
    path: ghostscript-printer-app.c
  - kind: local
    path: ghostscript-printer-app.1
  - kind: local
    path: ghostscript-printer-app.service
  - kind: local
    path: testpage.ps

build-depends:
  - freedesktop-sdk.bst:public-stacks/buildsystem-autotools.bst

depends:
  - printer-app/pappl-retrofit.bst
  - freedesktop-sdk.bst:components/ghostscript.bst

config:
  build-commands:
    - make clean
    - make -j2 VERSION=10.07.1-1 LDFLAGS="$LDFLAGS -ljpeg"
  install-commands:
    - make DESTDIR="%{install-root}" VERSION=10.07.1-1 LDFLAGS="$LDFLAGS -ljpeg" unitdir= install
