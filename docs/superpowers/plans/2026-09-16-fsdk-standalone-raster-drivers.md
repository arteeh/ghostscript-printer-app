# FSDK Standalone Raster Drivers Implementation Plan

> **For agentic workers:** Execute this plan task-by-task and keep each driver independently buildable.

**Goal:** Add the c2050, cjet, min12xxw, and pnm2ppa legacy raster converters to the FSDK appliance, preserve the editable pnm2ppa configuration, and prove each executable produces deterministic printer-language output.

**Architecture:** Add one focused BuildStream element per upstream source package, pinned to the Debian packaging tag commit already used by the existing OCI manifest. Apply the Debian patch series from each source tree before building. Install only runtime executables plus an immutable pnm2ppa configuration template, compose the four elements into `core-stack.bst`, and initialize the writable pnm2ppa configuration under the existing `/var/lib/ghostscript-printer-app` volume without overwriting user changes.

**Tech Stack:** BuildStream 2, freedesktop-sdk 26.08rc.1, GNU make/autotools, Ghostscript, Bash, Podman.

## Constraints

- Preserve the current OCI driver versions: c2050 `debian/0.3-7`, cjet `debian/0.8.9-11`, min12xxw `debian/0.0.9-11`, and pnm2ppa `debian/1.13-14`.
- Pin each source to its peeled immutable commit, not a moving tag alone.
- Reuse FSDK build and runtime components; do not stage Debian packages or toolchains into the image.
- Install converter commands under `/usr/bin`, matching the Foomatic PPD command lines.
- Compile pnm2ppa against `/var/lib/ghostscript-printer-app/pnm2ppa/pnm2ppa.conf`, but ship the pristine seed at `/usr/share/ghostscript-printer-app/pnm2ppa.conf`.
- Initialize the writable pnm2ppa configuration only when absent.
- Do not publish an OCI release from this incomplete migration slice.

---

### Task 1: Add pinned driver elements

**Files:**
- Create: `elements/printer-app/c2050.bst`
- Create: `elements/printer-app/cjet.bst`
- Create: `elements/printer-app/min12xxw.bst`
- Create: `elements/printer-app/pnm2ppa.bst`
- Modify: `include/aliases.yml`

- [ ] **Step 1: Add the Salsa source alias**

Add `salsa: https://salsa.debian.org/` so all four git sources use a named mirrorable alias.

- [ ] **Step 2: Add c2050**

Use `salsa:printing-team/c2050.git`, tag `debian/0.3-7`, ref `e2ee50d2da58e552b1ac70ae0b4d8913436921e1`. Build with FSDK's make toolchain and install only `/usr/bin/c2050`.

- [ ] **Step 3: Add cjet**

Use `salsa:printing-team/cjet.git`, tag `debian/0.8.9-11`, ref `2de422f1b08cdf8d18a2e2ea8ae0b14751702fba`. Apply the source tree's ordered `debian/patches/series`, build with make, and install only `/usr/bin/cjet`.

- [ ] **Step 4: Add min12xxw**

Use `salsa:printing-team/min12xxw.git`, tag `debian/0.0.9-11`, ref `9a1fae0987e757c8d04e728eaec6e7adc1efca89`. Apply the Debian patch series, regenerate autotools files, configure for `/usr`, and install only `/usr/bin/min12xxw`.

- [ ] **Step 5: Add pnm2ppa**

Use `salsa:printing-team/pnm2ppa.git`, tag `debian/1.13-14`, ref `ca990cac53fb605d827f707e5f2d0c490639705c`. Apply the Debian patch series, set the default model to 710, regenerate autotools files, and configure with `--sysconfdir=/var/lib/ghostscript-printer-app/pnm2ppa`. Install `/usr/bin/pnm2ppa`, `/usr/bin/calibrate_ppa`, and the seed config at `/usr/share/ghostscript-printer-app/pnm2ppa.conf`.

- [ ] **Step 6: Build and inspect each element**

Run:

```bash
just bst build printer-app/c2050.bst printer-app/cjet.bst printer-app/min12xxw.bst printer-app/pnm2ppa.bst
just bst artifact list-contents printer-app/c2050.bst printer-app/cjet.bst printer-app/min12xxw.bst printer-app/pnm2ppa.bst
```

Expected: each artifact contains only its intended runtime executable(s), with the pnm2ppa artifact also containing the immutable configuration template.

### Task 2: Compose and initialize the drivers

**Files:**
- Modify: `elements/printer-app/core-stack.bst`
- Modify: `files/container-entrypoint.sh`

- [ ] **Step 1: Add the driver artifacts to the runtime stack**

Add all four driver elements to `core-stack.bst`. Keep compiler, autotools, patch, and source data in build dependencies only.

- [ ] **Step 2: Initialize pnm2ppa state once**

Create `$state_dir/pnm2ppa` during startup. If `$state_dir/pnm2ppa/pnm2ppa.conf` is absent, copy the immutable template there. Never replace an existing file.

- [ ] **Step 3: Verify persistence across restart**

Start the image with a temporary state volume, verify the seeded config contains `version 710`, append a marker, restart with the same volume, and require the marker to remain.

### Task 3: Exercise driver behavior and runtime closure

**Files:**
- Create: `tests/standalone-raster-drivers.sh`
- Modify: `Justfile`

- [ ] **Step 1: Add executable and ELF checks**

Assert that `c2050`, `cjet`, `min12xxw`, `pnm2ppa`, and `calibrate_ppa` exist in the exported image. Run `ldd` for each ELF and fail on `not found`. Assert compiler and build tools are absent from the runtime.

- [ ] **Step 2: Exercise c2050 and cjet**

Generate deterministic raster/PCL input from the packaged PostScript test page using Ghostscript, pipe it through each converter, and require non-empty output with the expected protocol prefix or marker.

- [ ] **Step 3: Exercise min12xxw and pnm2ppa**

Generate valid page-sized PBM input and run `min12xxw` for model 1200W. Pipe `calibrate_ppa --center` into `pnm2ppa --bw` using the persisted configuration path. Require successful exits and non-empty outputs.

- [ ] **Step 4: Add the verification command**

Add `verify-raster-drivers` to `Justfile` and run the script against the assembled OCI image.

- [ ] **Step 5: Run all slice gates**

Run:

```bash
just validate
just verify-core
just verify-payload
just verify-raster-drivers
just verify-cups-patch-chain
actionlint .github/workflows/*.yml
bash -n files/container-entrypoint.sh tests/*.sh
git diff --check
```

Expected: every command succeeds.

### Task 4: Review and publish the slice

- [ ] **Step 1: Review the full diff**

Review from `feat/fsdk-core-payload` through the working tree for source pinning, architecture portability, runtime-only composition, pnm2ppa persistence, and meaningful driver execution.

- [ ] **Step 2: Resolve and publish**

Set `.scratch/fsdk-container-modernization/issues/04-restore-standalone-raster-drivers.md` to `resolved`, record successful commands and commit IDs, commit the completed plan, push `feat/fsdk-raster-drivers`, and open a pull request with base `feat/fsdk-core-payload`.
