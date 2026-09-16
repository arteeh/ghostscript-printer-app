# FSDK Core Driver Payload Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Expose the core CUPS, Ghostscript, cups-filters, libppd, and Foomatic driver payload from the FSDK appliance and prove one real conversion reaches a socket-backed printer.

**Architecture:** Reuse FSDK's existing printing artifacts without rebuilding or duplicating them. Build only pyppd and the Foomatic XML compiler that FSDK does not ship, generate the same three self-extracting PPD archives as the current OCI contract, and compose those archives with FSDK's filters plus their measured runtime dependencies. Verify the exported image, not BuildStream source text.

**Tech Stack:** BuildStream 2, freedesktop-sdk 26.08rc.1, cups-filters 2.0.1, Foomatic DB 20240504, foomatic-db-engine 4.1.0, pyppd 1.1.0, Python 3, xz, Podman.

## Global Constraints

- FSDK remains the only owner of CUPS, Ghostscript, cups-filters, libppd, and the Foomatic database.
- Repository elements may build only missing tooling and appliance-specific generated payloads.
- Keep `/usr/lib/ghostscript-printer-app` as the existing symlink to `/usr/lib/cups`; do not duplicate filters.
- Keep PPD drivers under `/usr/share/ppd`, matching the existing launcher `PPD_PATHS` contract.
- Generated pyppd archives must run with the same packaged Python major/minor used to create them and with packaged xz.
- Do not publish this incomplete image.

---

### Task 1: Build the missing PPD tooling

**Files:**
- Create: `elements/printer-app/pyppd.bst`
- Create: `elements/printer-app/foomatic-db-engine.bst`
- Create: `patches/foomatic-db-engine/xml-database-without-dbi.patch`

**Interfaces:**
- Consumes: FSDK Python, Perl, XML::Parser, curl, file, gzip, cups-filters, and Foomatic database artifacts.
- Produces: build-time `/usr/bin/pyppd` and `/usr/bin/foomatic-compiledb` commands.

- [x] **Step 1: Add the pyppd element**

Create `elements/printer-app/pyppd.bst`:

```yaml
kind: pyproject
description: Build the pyppd self-extracting PPD archive generator.

build-depends:
  - freedesktop-sdk.bst:public-stacks/buildsystem-python-setuptools.bst

depends:
  - freedesktop-sdk.bst:components/python3.bst
  - freedesktop-sdk.bst:components/xz.bst

sources:
  - kind: git_repo
    url: github:OpenPrinting/pyppd.git
    track: release-1-1-0
    ref: release-1-1-0-0-g29ccf6cf85781315a696774e7458a2f1f61aac57
```

- [x] **Step 2: Make Foomatic's XML-only path independent of DBI**

Create `patches/foomatic-db-engine/xml-database-without-dbi.patch` that removes the unconditional `use DBI;` from `lib/Foomatic/DB.pm` and adds `require DBI;` only inside the MySQL and SQLite branches of `connect_to_mysql_db()`. The XML database path used by `foomatic-compiledb` must not require an unavailable SQL driver.

- [x] **Step 3: Add the Foomatic engine element**

Create `elements/printer-app/foomatic-db-engine.bst` with immutable commit `e4e7b9cd28ba160428f82bc5234559d1f50e5c42`, the DBI patch queue, and these build dependencies:

```yaml
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
```

Use these commands:

```yaml
config:
  build-commands:
    - ./make_configure
    - PERL_INSTALLDIRS=vendor ./configure --prefix=/usr --libdir="%{libdir}"
    - make -j1
  install-commands:
    - make DESTDIR="$PWD/full-install" install
    - install -D -m 0755 full-install/usr/sbin/foomatic-compiledb "%{install-root}/usr/bin/foomatic-compiledb"
    - mkdir -p "%{install-root}/usr/lib" && cp -a full-install/usr/lib/perl5 "%{install-root}/usr/lib/"
```

- [x] **Step 4: Verify both tools build**

Run:

```bash
just bst build printer-app/pyppd.bst printer-app/foomatic-db-engine.bst
just bst artifact list-contents printer-app/pyppd.bst printer-app/foomatic-db-engine.bst
```

Expected: the artifacts contain `/usr/bin/pyppd` and `/usr/bin/foomatic-compiledb`; no second CUPS library is introduced.

- [x] **Step 5: Commit the tooling**

```bash
git add elements/printer-app/pyppd.bst elements/printer-app/foomatic-db-engine.bst patches/foomatic-db-engine/xml-database-without-dbi.patch
git commit -m "build: add core PPD generation tools" -m "Assisted-by: github-copilot/gpt-5.6-sol via pi"
```

### Task 2: Generate the core PPD archives

**Files:**
- Create: `elements/printer-app/core-payload.bst`

**Interfaces:**
- Consumes: FSDK cups-filters PPDs and Foomatic XML/manufacturer data plus the Task 1 generators.
- Produces: executable `/usr/share/ppd/cups-filters-ppds`, `/usr/share/ppd/foomatic-ppds`, and `/usr/share/ppd/manufacturer-ppds` archives.

- [x] **Step 1: Stage source payloads and generators**

Create a `manual` element with build dependencies on `printer-app/pyppd.bst`, `printer-app/foomatic-db-engine.bst`, `freedesktop-sdk.bst:components/cups-filters.bst`, `freedesktop-sdk.bst:components/foomatic-db.bst`, and `freedesktop-sdk.bst:public-stacks/runtime-gnu.bst`.

- [x] **Step 2: Generate the cups-filters archive**

The build commands must copy `/usr/share/ppd/cupsfilters` to `payload/cupsfilters` and run:

```bash
pyppd -v -o cups-filters-ppds payload/cupsfilters
```

- [x] **Step 3: Generate the Foomatic archives**

Copy `/usr/share/foomatic` to `payload/foomatic`, remove PostScript manufacturer PPDs and the unsupported driver XML files carried by the current Snap contract:

```text
bjc800j.xml c2070.xml drv_x125.xml lm1100.xml lpstyl.xml ml85p.xml
pbm2l2030.xml pbm2l7k.xml pbm2lwxl.xml pentaxpj.xml ppmtomd.xml
```

Then run:

```bash
FOOMATICDB="$PWD/payload/foomatic" foomatic-compiledb -j "%{max-jobs}" -t ppd -d payload/foomatic-ppds
pyppd -v -o foomatic-ppds payload/foomatic-ppds
pyppd -v -o manufacturer-ppds payload/foomatic/db/source/PPD
```

- [x] **Step 4: Install only generated archives**

Install the three executable archives with mode `0755` beneath `%{install-root}/usr/share/ppd`. Do not carry the Foomatic compiler, raw XML database, or pyppd package into this artifact.

- [x] **Step 5: Build and inspect the payload artifact**

Run:

```bash
just bst build printer-app/core-payload.bst
just bst artifact list-contents printer-app/core-payload.bst
```

Expected: exactly the three executable archive files appear under `/usr/share/ppd`.

- [x] **Step 6: Commit the generated-payload element**

```bash
git add elements/printer-app/core-payload.bst
git commit -m "build: generate core PPD archives" -m "Assisted-by: github-copilot/gpt-5.6-sol via pi"
```

### Task 3: Compose the runtime payload and verify its closure

**Files:**
- Modify: `elements/printer-app/core-stack.bst`
- Create: `tests/core-payload.sh`
- Modify: `Justfile`

**Interfaces:**
- Consumes: `printer-app/core-payload.bst` and FSDK runtime components.
- Produces: `just verify-payload`, proving driver archives, filters, interpreters, HTTPS, and shared-library closure inside the exported image.

- [x] **Step 1: Write the failing image-level payload check**

Create `tests/core-payload.sh`. It must run `just build`, then assert from the image that:

```text
/usr/lib/ghostscript-printer-app -> /usr/lib/cups
/usr/lib/cups/backend/dnssd
/usr/lib/cups/backend/ipp
/usr/lib/cups/backend/ipps
/usr/lib/cups/backend/lpd
/usr/lib/cups/backend/snmp
/usr/lib/cups/backend/socket
/usr/lib/cups/backend/usb
/usr/lib/cups/filter/foomatic-rip
/usr/lib/cups/filter/gstoraster
/usr/lib/cups/filter/pdftops
/usr/lib/cups/filter/rastertoescpx
/usr/lib/cups/filter/rastertopclx
/usr/lib/cups/filter/rastertoepson
/usr/lib/cups/filter/rastertohp
/usr/lib/cups/filter/rastertolabel
/usr/bin/ghostscript-printer-app
/usr/bin/gs
/usr/share/ghostscript-printer-app/testpage.ps
/usr/share/ppd/cups-filters-ppds
/usr/share/ppd/foomatic-ppds
/usr/share/ppd/manufacturer-ppds
/usr/bin/python3
/usr/bin/xz
```

For each archive, run `list`, capture its first URI, run `cat <URI>`, and require the extracted text to contain `*PPD-Adobe:`. Run this check now; it must fail because the payload is not yet composed.

- [x] **Step 2: Add runtime components**

Add these dependencies to `core-stack.bst`:

```yaml
- printer-app/core-payload.bst
- freedesktop-sdk.bst:components/cups-filters.bst
- freedesktop-sdk.bst:components/mutool.bst
- freedesktop-sdk.bst:components/python3.bst
- freedesktop-sdk.bst:components/xz.bst
```

Keep the existing Ghostscript, CUPS, libppd, and libcupsfilters dependencies.

- [x] **Step 3: Verify HTTP and HTTPS**

The payload test starts the real image on host networking, waits for `<title>Ghostscript Printer Application</title>` over HTTP, and requires the same title over HTTPS with `curl --insecure`.

- [x] **Step 4: Verify ELF closure**

Inside the image, run `ldd` for the application and each core filter listed in Step 1. Fail if any output contains `not found`.

- [x] **Step 5: Add the verification command**

Add to `Justfile`:

```just
verify-payload:
    tests/core-payload.sh
```

- [x] **Step 6: Run and commit the runtime checks**

Run:

```bash
just verify-payload
```

Expected: all payload, archive, HTTPS, and ELF checks pass.

```bash
git add Justfile elements/printer-app/core-stack.bst tests/core-payload.sh
git commit -m "test: verify core driver payload" -m "Assisted-by: github-copilot/gpt-5.6-sol via pi"
```

### Task 4: Prove a deterministic print conversion

**Files:**
- Modify: `tests/core-payload.sh`
- Modify: `ghostscript-printer-app.c`
- Modify: `elements/freedesktop-sdk.bst`
- Modify: `patches/freedesktop-sdk/0001-customize-cups-for-printer-application.patch`
- Create: `patches/libcupsfilters/avoid-global-option-lock-after-fork.patch`
- Create: `tests/socket-sink.py`

**Interfaces:**
- Consumes: running Printer Application, the generated Generic PCL 6/PCL XL Foomatic driver, repository test page, and a host Python socket sink.
- Produces: non-empty PCL XL output captured from a real submitted job.

- [x] **Step 1: Add the socket-backed printer test**

Start a one-shot host sink before the container:

```bash
python3 tests/socket-sink.py "$sink_port" "$output_file" &
sink_pid=$!
```

After HTTP/HTTPS readiness, add a Generic PCL 6/PCL XL printer and invoke its built-in test-page action:

```bash
ghostscript-printer-app -u "ipp://127.0.0.1:${port}/ipp/system" \
  -d core-test \
  -m generic--pcl-6-pcl-xl-printer--pxlcolor-recommended-en \
  -v "cups:socket://127.0.0.1:${sink_port}" add
curl --data 'action=print-test-page' \
  "http://127.0.0.1:${port}/core-test/"
```

The application must request the installed `testpage.ps`. Patch FSDK's libcupsfilters 2.2.1 so `cfFilterExternal()` merges borrowed option records without calling libcups' globally locked string pool after `cfFilterPOpen()` forks. Preserve case-insensitive replacement and the `cupsPrintQuality`/`print-quality` alias rule.

- [x] **Step 2: Assert conversion output**

Poll until `${output_file}` is non-empty, wait for the sink and print job to complete, then require the PJL/PCL stream to start with `ESC%-12345X`. A successful CLI return without captured output is a failure.

- [x] **Step 3: Re-run all slice gates**

Run:

```bash
just validate
just verify-core
just verify-payload
just verify-cups-patch-chain
actionlint .github/workflows/*.yml
bash -n files/container-entrypoint.sh tests/core-appliance.sh tests/core-payload.sh tests/cups-patch-chain.sh
git diff --check
```

Expected: every command succeeds.

- [ ] **Step 4: Resolve and publish the slice**

Set `.scratch/fsdk-container-modernization/issues/03-serve-core-ppd-filter-payload.md` to `resolved`, record exact successful commands and commit IDs, commit this completed plan, push `feat/fsdk-core-payload`, and open a pull request with base `feat/fsdk-core-app`. Do not publish an OCI release.
