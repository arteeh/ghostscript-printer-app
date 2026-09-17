# OCI physical printer validation

`just verify` proves the automated appliance contract with synthetic jobs. It does not prove USB enumeration, network discovery, printer firmware behavior, ink or toner output, media handling, or device-specific color. Record those results only after testing real hardware.

## Automated baseline

Run:

```bash
just verify
```

The x86_64 image has a 500 MiB (524,288,000-byte) uncompressed ceiling. The implementation baseline measured 449,525,807 bytes on 2026-09-16. `tests/appliance-parity.sh` measures the local image through Podman and fails above that ceiling. The gate also checks OCI metadata, payload inventory, absence of development content, interpreter policy, and every ELF dependency.

The OCI driver contract is the complete list under [Contained Printer Drivers](../README.md#contained-printer-drivers-in-the-snap), not a sample. Despite the historical heading, the FSDK image must retain every listed Ghostscript/Foomatic driver and every named external driver family. The parity gate requires each legacy Ghostscript name as either a compiled Ghostscript device or an exact Foomatic PPD entry, then separately checks all external driver, filter, backend, and PPD-provider families.

## USB printer

1. Build the exact revision under test with `just build`.
2. Connect and power on the printer. Confirm the host sees it before starting the container.
3. Start the appliance with host networking, persistent state, and USB access:

   ```bash
   mkdir -p .state/physical-usb
   podman unshare chown -R 65532:65532 .state/physical-usb
   podman run --rm --name ghostscript-printer-app-usb \
     --network host \
     --device /dev/bus/usb \
     --group-add keep-groups \
     -e PORT=18080 \
     -v "$PWD/.state/physical-usb:/var/lib/ghostscript-printer-app:Z" \
     ghcr.io/projectbluefin/ghostscript-printer-app:build
   ```

4. Open `http://127.0.0.1:18080`, add the discovered USB device, and select its intended driver rather than a generic substitute.
5. Print the built-in test page. Confirm that the job completes, paper and resolution match the selected options, graphics and text are complete, and the device reports no protocol or filter error.
6. Restart the same command and confirm that the printer and any edited profile or configuration remain present.

If rootless device access is denied, fix host udev/group permissions. Do not validate with a privileged container because that hides the shipping access model.

## Network printer

1. Build the exact revision under test with `just build`.
2. Start the appliance without USB access:

   ```bash
   mkdir -p .state/physical-network
   podman unshare chown -R 65532:65532 .state/physical-network
   podman run --rm --name ghostscript-printer-app-network \
     --network host \
     -e PORT=18081 \
     -v "$PWD/.state/physical-network:/var/lib/ghostscript-printer-app:Z" \
     ghcr.io/projectbluefin/ghostscript-printer-app:build
   ```

3. Open `http://127.0.0.1:18081`. Confirm DNS-SD discovery when the printer advertises itself; otherwise add its `socket://`, `ipp://`, or `ipps://` address manually.
4. Select the intended driver and print the built-in test page.
5. Confirm completed job state, physical output, selected media/resolution, and absence of backend or filter errors.
6. Restart with the same state directory and repeat one print to prove persisted configuration.

## Result record

Record the image digest, commit, date, printer make/model, connection type, device URI, selected driver, tested options, restart result, and observed output. Mark USB and network separately. A synthetic CI pass must never be recorded as physical validation.
