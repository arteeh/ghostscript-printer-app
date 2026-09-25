# OCI service advertisements

The final Ghostscript OCI layer owns removal of the inherited Avahi sample
`ssh.service` and `sftp-ssh.service` files. This appliance runs neither service.
The shared fsdk-containers printing base keeps owning Avahi (`avahi-printing`); PAPPL publishes IPP records
dynamically. Do not disable Avahi or remove its services directory to suppress
these two unrelated advertisements. `just verify-core` checks the final image
before startup, so entrypoint cleanup cannot hide a packaging regression.

On a Linux test host with Podman, a running host Avahi daemon, `avahi-browse`,
`timeout`, and curl, run `just verify-service-advertisements`. Use an isolated,
otherwise quiet LAN: changes in other machines' SSH/SFTP records deliberately
fail the baseline comparison. Multicast must be allowed. The test retains raw
resolved browse records and image identity in its printed evidence directory.
It uses two distinct synthetic queues, ports and state directories under host
networking, observes SSH/SFTP and IPP before startup, after startup and after
restarting one container, and requires both queues' IPP records to resolve.
It removes the containers and temporary state on exit. No print job is sent.

All four printer families need their own final-image evidence. This repository's
image test is not evidence for the other three images. Reuse the probe for each
built family image, specifying its executable, state path and a supported driver:

```sh
IMAGE=<built-image-or-digest> APP=<printer-app-executable> \
STATE_ROOT=/var/lib/<printer-app> DRIVER=<supported-driver-name> \
EVIDENCE_DIR=<family-evidence-directory> tests/service-advertisements.sh
```

The probe expects the PAPPL CLI and `PORT` convention, a shell in the image, and
a `cups:socket` synthetic backend. Verify those contracts for each family before
running it; adapt the queue setup if a family uses a different backend. Record
image digests and actual results separately for each of the four printer families. Until those runs exist, cross-family verification remains open
in issue #46. Other repositories should remove the two files at their final-image
packaging boundary rather than copy or override the shared base's `avahi-printing` element. Review of
this change establishes the Ghostscript packaging owner only; shared listener
coordination remains in #17 and ChairLift #330.

A baseline comparison cannot attribute identical records published by multiple
Avahi daemons. The final-image file assertions provide the complementary check
for these inherited records. This test does not prove physical printer discovery,
USB ownership, desktop UI behavior, or printed paper.
