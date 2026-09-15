kind: junction

sources:
  - kind: git_repo
    url: gitlab:freedesktop-sdk/freedesktop-sdk.git
    track: freedesktop-sdk-26.08*
    ref: freedesktop-sdk-26.08rc.1-0-ge076d4978ee6945763486f6ebd755d189460e4e7
  - kind: local
    path: patches/cups
    directory: patches/ghostscript-printer-app/cups
  - kind: patch_queue
    path: patches/freedesktop-sdk

config:
  options:
    target_arch: "%{arch}"
    (?):
      - arch == "x86_64":
          bootstrap_build_arch: "x86_64"
      - arch == "aarch64":
          bootstrap_build_arch: "aarch64"
