kind: makemaker
description: Build XML::SAX::Base for Foomatic XML parsing.

build-depends:
  - freedesktop-sdk.bst:public-stacks/buildsystem-make.bst

depends:
  - freedesktop-sdk.bst:components/perl.bst

sources:
  - kind: cpan
    name: XML::SAX::Base
    suffix: authors/id/G/GR/GRANTM/XML-SAX-Base-1.09.tar.gz
    sha256sum: 66cb355ba4ef47c10ca738bd35999723644386ac853abbeb5132841f5e8a2ad0
