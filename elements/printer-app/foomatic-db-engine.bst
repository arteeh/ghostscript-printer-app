kind: manual
description: Build the Foomatic XML database compiler.

sources:
  - kind: git_repo
    url: github:OpenPrinting/foomatic-db-engine.git
    track: master
    ref: e4e7b9cd28ba160428f82bc5234559d1f50e5c42
  - kind: patch_queue
    path: patches/foomatic-db-engine

build-depends:
  - freedesktop-sdk.bst:public-stacks/buildsystem-autotools.bst
  - freedesktop-sdk.bst:components/cups-filters.bst
  - freedesktop-sdk.bst:components/curl.bst
  - freedesktop-sdk.bst:components/file.bst
  - freedesktop-sdk.bst:components/foomatic-db.bst
  - freedesktop-sdk.bst:components/ghostscript.bst
  - freedesktop-sdk.bst:components/gzip.bst
  - freedesktop-sdk.bst:components/perl.bst
  - freedesktop-sdk.bst:components/perl-xml-parser.bst

config:
  build-commands:
    - ./make_configure
    - PERL_INSTALLDIRS=vendor ./configure --prefix=/usr --libdir="%{libdir}"
    - make -j1
  install-commands:
    - make DESTDIR="%{install-root}" install
