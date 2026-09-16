kind: manual
description: Build the minimal JBIG85 shared library required by SpliX.

sources:
  - kind: git_repo
    url: https://www.cl.cam.ac.uk/~mgk25/git/jbigkit
    track: v2.1
    ref: v2.1-0-g60bd8bd6579c12e5e3a24782bd49af2046a9738a

build-depends:
  - freedesktop-sdk.bst:public-stacks/buildsystem-make.bst

config:
  build-commands:
    - cc $CFLAGS -fPIC -Ilibjbig -c libjbig/jbig85.c -o jbig85.o
    - cc $CFLAGS -fPIC -Ilibjbig -c libjbig/jbig_ar.c -o jbig_ar.o
    - cc $LDFLAGS -shared -Wl,-soname,libjbig85.so.0 -o libjbig85.so.0 jbig85.o jbig_ar.o
  install-commands:
    - install -D -m 0644 libjbig85.so.0 "%{install-root}%{libdir}/libjbig85.so.0"
    - ln -s libjbig85.so.0 "%{install-root}%{libdir}/libjbig85.so"
    - install -D -m 0644 libjbig/jbig85.h "%{install-root}/usr/include/jbig85.h"
    - install -D -m 0644 libjbig/jbig_ar.h "%{install-root}/usr/include/jbig_ar.h"
