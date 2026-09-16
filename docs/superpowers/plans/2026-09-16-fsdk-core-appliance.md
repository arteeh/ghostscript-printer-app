# FSDK Core Printer Application Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build and boot a local amd64 OCI appliance from freedesktop-sdk, PAPPL, pappl-retrofit, and the repository application while proving non-root lifecycle behavior.

**Architecture:** BuildStream owns the complete build graph and consumes the already-proven patched freedesktop-sdk junction as the single CUPS owner. Focused elements build PAPPL, pappl-retrofit, and the C application; a compose element produces the runtime closure; an OCI element adds numeric identity metadata and runs catatonit plus one Bash lifecycle launcher. The real exported image is the verification boundary.

**Tech Stack:** BuildStream 2, freedesktop-sdk 26.08rc.1, PAPPL 1.4.12, pappl-retrofit, OCI Builder, Podman, Bash, catatonit.

## Global Constraints

- Keep freedesktop-sdk's patched private CUPS base as the only `libcups.so*` owner.
- Do not change `ghostscript-printer-app.c` behavior or driver selection.
- Preserve the existing `Makefile` compile and install contract.
- Run the appliance as numeric identity `65532:65532` with matching passwd and group records.
- Keep `/var/lib/ghostscript-printer-app` as the single persistent state location.
- Use catatonit as PID 1 and one Bash launcher for D-Bus, Avahi, and the Printer Application.
- A required child exit must terminate the container; TERM and INT must stop all children.
- Keep Snap and Rockcraft behavior unchanged in this slice.
- Do not publish the incomplete core-only image.

---

### Task 1: Stabilize BuildStream tooling and graph

**Files:**
- Modify: `.gitignore`
- Modify: `Justfile`
- Modify: `project.conf`
- Create: `elements/printer-app/pappl.bst`
- Create: `elements/printer-app/pappl-retrofit.bst`
- Create: `elements/printer-app/application.bst`
- Create: `patches/pappl/printer-application.patch`

**Interfaces:**
- Consumes: `elements/freedesktop-sdk.bst`, the repository `Makefile`, and the four PAPPL compatibility modifications defined by the accepted specification.
- Produces: `printer-app/application.bst`, an application artifact built against PAPPL, pappl-retrofit, Ghostscript, CUPS, libppd, and libcupsfilters; `just validate`, `just build`, and `just export` commands.

- [x] **Step 1: Keep generated BuildStream configuration out of Git**

Add these generated paths to `.gitignore`:

```gitignore
.bst-re.conf
.build-out/
```

- [x] **Step 2: Define architecture and cache configuration**

Keep the existing `arch` option and add the exact OCI mapping and public cache configuration in `project.conf`:

```yaml
variables:
  abi: gnu
  gcc-triplet: "%{arch}-linux-%{abi}"
  lib: "lib/%{gcc-triplet}"
  libdir: "%{prefix}/%{lib}"
  (?):
    - arch == "x86_64":
        go-arch: "amd64"
    - arch == "aarch64":
        go-arch: "arm64"

artifacts:
  - url: https://gbm.gnome.org:11003
  - url: https://cache.projectbluefin.io:11001

source-caches:
  - url: https://gbm.gnome.org:11003
  - url: https://cache.projectbluefin.io:11001
```

- [x] **Step 3: Preserve the four PAPPL compatibility changes as one explicit patch**

`patches/pappl/printer-application.patch` must change exactly these upstream behaviors:

```diff
-DSOFLAGS = @DSOFLAGS@ $(CFLAGS)
+DSOFLAGS = @DSOFLAGS@ $(LDFLAGS) $(CFLAGS)
-PAPPL_MAX_VENDOR 32
+PAPPL_MAX_VENDOR 256
-"socket"
+"cups:socket"
-system->log_max_size = 1024 * 1024;
+system->log_max_size = 0;
```

The patch is a compatibility inventory, not a new fork: linked shared-library flags, the existing vendor-option ceiling, the retrofit CUPS URI scheme, and disabled log rotation.

- [x] **Step 4: Build PAPPL and pappl-retrofit against public FSDK elements**

`elements/printer-app/pappl.bst` must pin PAPPL `v1.4.12` at `6db8e137557ad84662e78d24fdb2a591c621f4ac`, apply `patches/pappl`, use GnuTLS and Avahi, and set:

```sh
--libdir=%{libdir}
--with-papplstatedir=/var/lib/ghostscript-printer-app
--with-papplsockdir=/run/ghostscript-printer-app
```

`elements/printer-app/pappl-retrofit.bst` must pin commit `1626b338fc8b92a99c2c1a483ac39c739d71b305` and depend on only public `cups.bst`, `libcupsfilters.bst`, and `libppd.bst` elements plus local PAPPL.

- [x] **Step 5: Build the repository application through its Makefile**

`elements/printer-app/application.bst` must stage `Makefile`, `ghostscript-printer-app.c`, the man page, service file, and test page, then run:

```sh
make clean
make -j2 VERSION=10.07.1-1 LDFLAGS="$LDFLAGS -ljpeg"
make DESTDIR="%{install-root}" VERSION=10.07.1-1 LDFLAGS="$LDFLAGS -ljpeg" unitdir= install
```

- [x] **Step 6: Verify graph and source patches**

Run:

```bash
just validate
just bst source checkout --force --directory /src/.bst/pappl-source printer-app/pappl.bst
```

Expected: `just validate` resolves `oci/ghostscript-printer-app.bst`; the checked-out PAPPL source contains vendor limit `256`, `cups:socket`, zero log rotation size, and `$(LDFLAGS)` in `DSOFLAGS`.

- [x] **Step 7: Commit the graph slice**

```bash
git add .gitignore Justfile project.conf elements/printer-app/application.bst elements/printer-app/pappl.bst elements/printer-app/pappl-retrofit.bst patches/pappl/printer-application.patch
git commit -m "build: add core FSDK printer application graph"
```

### Task 2: Compose and export the non-root OCI appliance

**Files:**
- Create: `elements/printer-app/runtime-files.bst`
- Create: `elements/printer-app/core-stack.bst`
- Create: `elements/printer-app/core-runtime.bst`
- Create: `elements/oci/ghostscript-printer-app.bst`
- Create: `files/container-entrypoint.sh`
- Modify: `Justfile`

**Interfaces:**
- Consumes: `printer-app/application.bst` and public FSDK runtime components.
- Produces: local image `ghcr.io/projectbluefin/ghostscript-printer-app:build` with user `65532:65532`, catatonit entrypoint, and writable runtime/state paths.

- [x] **Step 1: Install only appliance-owned runtime files**

`runtime-files.bst` installs the launcher at `/usr/libexec/ghostscript-printer-app/container-entrypoint` and creates the persistent state directories. The final OCI layer removes inherited root-owned daemon subdirectories, makes `/run` writable, and lets the launcher recreate these paths as UID `65532`:

```text
/run/dbus
/run/avahi-daemon
/run/ghostscript-printer-app
/var/lib/ghostscript-printer-app
/var/spool/ghostscript-printer-app
```

- [x] **Step 2: Define the core runtime closure**

`core-stack.bst` must contain the local application and runtime files plus these public FSDK runtime elements:

```yaml
- public-stacks/runtime-gnu.bst
- components/avahi.bst
- components/ca-certificates.bst
- components/catatonit.bst
- components/cups-daemon-only.bst
- components/dbus.bst
- components/ghostscript.bst
- components/libcupsfilters.bst
- components/libppd.bst
- components/tzdata.bst
```

`core-runtime.bst` composes that stack while excluding `debug`, `devel`, `doc`, `locale`, `static-blocklist`, `tests`, and `vm-only` domains.

- [x] **Step 3: Define OCI identity and process metadata**

`elements/oci/ghostscript-printer-app.bst` must add one matching passwd/group record for UID/GID `65532`, adjust FSDK D-Bus/Avahi policies to that identity, and emit this runtime configuration. The junction patch configures Avahi's compiled service user and group as `nonroot`; do not add a duplicate UID alias.

```yaml
User: '65532:65532'
Entrypoint: ['/usr/bin/catatonit', '--', '/usr/bin/bash', '/usr/libexec/ghostscript-printer-app/container-entrypoint']
Env:
  - 'HOME=/var/lib/ghostscript-printer-app'
  - 'PATH=/usr/bin:/usr/sbin'
```

Use OCI architecture `%{go-arch}` and keep the core-slice version labels `10.07.1-1` and `26.08rc.1`; canonical version generation belongs to issue 09.

- [x] **Step 4: Export through one local command**

`just build` must build the OCI element and call `just export`. `just export` must check out the OCI artifact, import it with Podman, remove the temporary checkout, and tag it as `ghcr.io/projectbluefin/ghostscript-printer-app:build`.

- [x] **Step 5: Build and inspect the real image**

Run:

```bash
just build
podman image inspect ghcr.io/projectbluefin/ghostscript-printer-app:build --format '{{json .Config}}'
podman run --rm --entrypoint /usr/bin/bash ghcr.io/projectbluefin/ghostscript-printer-app:build -c '
  set -e
  test "$(id -u):$(id -g)" = 65532:65532
  test "$(id -un)" = nonroot
  passwd_ok=0
  while IFS=: read -r name password uid gid gecos home shell; do
    [[ "$name:$uid:$gid" == "nonroot:65532:65532" ]] && passwd_ok=1
  done < /etc/passwd
  group_ok=0
  while IFS=: read -r name password gid members; do
    [[ "$name:$gid" == "nonroot:65532" ]] && group_ok=1
  done < /etc/group
  (( passwd_ok && group_ok ))
'
```

Expected: build and export succeed; image config reports the numeric user and catatonit entrypoint; passwd/group checks pass.

- [x] **Step 6: Commit the OCI slice**

```bash
git add Justfile elements/printer-app/runtime-files.bst elements/printer-app/core-stack.bst elements/printer-app/core-runtime.bst elements/oci/ghostscript-printer-app.bst files/container-entrypoint.sh
git commit -m "build: compose core FSDK OCI appliance"
```

### Task 3: Prove lifecycle behavior against the built image

**Files:**
- Modify: `files/container-entrypoint.sh`
- Modify: `elements/oci/ghostscript-printer-app.bst`
- Modify: `patches/freedesktop-sdk/0001-customize-cups-for-printer-application.patch`
- Create: `tests/core-appliance.sh`
- Modify: `Justfile`

**Interfaces:**
- Consumes: exported image `ghcr.io/projectbluefin/ghostscript-printer-app:build`.
- Produces: `just verify-core`, proving HTTP readiness, numeric non-root execution, persistent state initialization, clean TERM handling, and fail-fast behavior for required children.

- [x] **Step 1: Implement deterministic launcher startup and shutdown**

The launcher must:

```bash
set -euo pipefail
```

Validate `PORT` with Bash's numeric regular expression, initialize state directories and seed `cups/snmp.conf` only when absent, export the repository runtime-path contract, start D-Bus and wait for `/run/dbus/system_bus_socket`, start Avahi and wait for `/run/avahi-daemon/pid`, then start `ghostscript-printer-app`. Track every child PID. On TERM or INT, stop the application, Avahi, then D-Bus and retain TERM status `143`. Any unexpected required-child exit, including status `0`, must stop the remaining children and return nonzero.

- [x] **Step 2: Extend the smoke check to assert the observable contract**

`tests/core-appliance.sh` must build the image, start it without a `--user` override using host networking and a temporary state volume, require an application-specific HTTP title, then execute these checks:

```bash
response="$(curl --fail --silent --show-error "http://127.0.0.1:${port}/")"
[[ "$response" == *'<title>Ghostscript Printer Application</title>'* ]]
podman exec "$name" /usr/bin/bash -c 'test "$(id -u):$(id -g):$(id -un)" = 65532:65532:nonroot'
test -d "$state_dir/ppd"
test -d "$state_dir/spool"
test -d "$state_dir/cups/ssl"
test -s "$state_dir/cups/snmp.conf"
podman stop --time 15 "$name" >/dev/null
read -r running exit_status <<< "$(podman inspect "$name" --format '{{.State.Running}} {{.State.ExitCode}}')"
test "$running" = false
test "$exit_status" -eq 143
```

Exit status `143` proves catatonit and the launcher completed the TERM path; Podman's timeout fallback would report SIGKILL status `137`.

For child-failure propagation, start a second container, prove the edited persistent SNMP configuration survived, then terminate Avahi cleanly. The supervisor must still return nonzero because any required-child exit is a failure:

```bash
podman exec "$failure_name" /usr/bin/bash -c '
  for proc in /proc/[0-9]*; do
    read -r comm < "$proc/comm" || continue
    if [[ "$comm" == avahi-daemon ]]; then
      kill -TERM "${proc##*/}"
      exit 0
    fi
  done
  exit 1
'
for _ in $(seq 1 150); do
  running="$(podman inspect "$failure_name" --format '{{.State.Running}}')"
  [[ "$running" == false ]] && break
  sleep 0.1
done
read -r running status <<< "$(podman inspect "$failure_name" --format '{{.State.Running}} {{.State.ExitCode}}')"
test "$running" = false
test "$status" -ne 0
```

Also run the image once with `PORT=invalid` and assert exit status `64` plus `PORT must be numeric` on stderr.

- [x] **Step 3: Run the complete core acceptance command**

Run:

```bash
just verify-core
```

Expected: the actual image reaches its own HTTP interface as `nonroot` UID/GID `65532`, initializes and preserves the mounted state tree, exits with `143` on TERM rather than Podman's `137` timeout fallback, exits nonzero when Avahi exits cleanly, and rejects an invalid port with status `64`.

- [x] **Step 4: Re-run the CUPS ownership gate**

Run:

```bash
just verify-cups-patch-chain
```

Expected: one FSDK private CUPS base remains, canonical DNS-SD and USB-quirk patches are staged, and public CUPS split rules remain intact.

- [x] **Step 5: Commit the lifecycle slice**

```bash
git add Justfile files/container-entrypoint.sh tests/core-appliance.sh
git commit -m "test: verify core appliance lifecycle"
```

### Task 4: Close and publish the implementation slice

**Files:**
- Modify: `.scratch/fsdk-container-modernization/issues/02-boot-minimal-fsdk-printer-application.md` (local tracker; ignored by Git)
- Modify: `docs/superpowers/plans/2026-09-16-fsdk-core-appliance.md`

**Interfaces:**
- Consumes: passing `just validate`, `just verify-core`, and `just verify-cups-patch-chain` results.
- Produces: resolved local ticket, committed plan, and a pushed `feat/fsdk-core-app` branch in `projectbluefin/ghostscript-printer-app`.

- [x] **Step 1: Mark every plan checkbox complete only after its command passes**

Update this file's completed steps from `- [ ]` to `- [x]`; do not mark commands that were not executed successfully.

- [x] **Step 2: Resolve the local ticket**

Set issue 02 to:

```markdown
**Status:** resolved
```

Append an `## Answer` recording the implementing commit IDs and exact successful verification commands.

- [x] **Step 3: Commit the plan and final metadata**

```bash
git add docs/superpowers/plans/2026-09-16-fsdk-core-appliance.md
git commit -m "docs: record FSDK core appliance plan" -m "Assisted-by: github-copilot/gpt-5.6-sol via pi"
```

The `.scratch` ticket remains local because `.scratch/` is intentionally ignored.

- [x] **Step 4: Integrate the current Project Bluefin main branch**

Run:

```bash
git rebase main
```

Expected: the feature branch contains the three existing post-branch Rock payload fixes without changing this slice's FSDK contract.

- [x] **Step 5: Verify the branch tip from a clean worktree**

Run:

```bash
just validate
just verify-core
just verify-cups-patch-chain
git status --short
```

Expected: all three commands succeed and `git status --short` prints nothing.

- [ ] **Step 6: Push the feature branch to Project Bluefin**

```bash
git push --set-upstream origin feat/fsdk-core-app
```

Expected: `origin/feat/fsdk-core-app` is created or updated at the verified branch tip. Do not tag or publish the core-only image.
