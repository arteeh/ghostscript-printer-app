kind: manual
description: Build PAPPL for the Ghostscript Printer Application.

sources:
  - kind: git_repo
    url: github:michaelrsweet/pappl.git
    track: v1.4.*
    ref: v1.4.12-0-g6db8e137557ad84662e78d24fdb2a591c621f4ac
  - kind: patch_queue
    path: patches/pappl

build-depends:
  - freedesktop-sdk.bst:public-stacks/buildsystem-autotools.bst

depends:
  - freedesktop-sdk.bst:components/avahi-libs.bst
  - freedesktop-sdk.bst:components/cups.bst
  - freedesktop-sdk.bst:components/gnutls.bst
  - freedesktop-sdk.bst:components/jpeg.bst
  - freedesktop-sdk.bst:components/libpng.bst
  - freedesktop-sdk.bst:components/libusb.bst

config:
  configure-commands:
    - |
      ./configure \
        --prefix=/usr \
        --libdir="%{libdir}" \
        --disable-libpam \
        --disable-static \
        --enable-shared \
        --enable-libjpeg \
        --enable-libpng \
        --enable-libusb \
        --with-dnssd=avahi \
        --with-tls=gnutls \
        --with-papplstatedir=/var/lib/ghostscript-printer-app \
        --with-papplsockdir=/run/ghostscript-printer-app
  build-commands:
    - make -j2
  install-commands:
    - make DESTDIR="%{install-root}" install
