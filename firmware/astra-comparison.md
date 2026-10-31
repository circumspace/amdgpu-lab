# Sapphire Pulse RX 7900 XTX security firmware comparison

**Follow-up:** the encrypted payloads were decrypted and their signatures verified in the original research workspace. Instruction-level analysis identified overflow fixes and narrower register permissions. See [astra-findings.md](astra-findings.md) for the reported conclusions; this document retains the initial structural comparison and its then-unresolved questions.

## Result

Compared the older **113-3E4710U-O54** image with **113-3E4710U-W95** from Sapphire's official updater. The update changes four signed firmware payloads, internal VBIOS data, and 16 bytes in the VRAM table's DRAM-information region. The compressed UEFI GOP executable, including its signature, is byte-identical between these two versions.

This identifies changed components, not the undisclosed vulnerability. Two changed firmware payloads are encrypted, proprietary table fields remain unidentified, and no CVE attribution is established.

## Inputs and provenance

| | Older baseline | Official replacement |
|---|---|---|
| Part number | 113-3E4710U-O54 | 113-3E4710U-W95 |
| ATOMBIOS version | 022.001.002.034.000001 | 022.001.002.045.000001 |
| Embedded build date | 2024-01-16 | 2026-08-06 |
| File size | 2,097,152 bytes | 2,031,616 bytes |
| SHA256 | 7e98b1d98fe2122f52c144e7bc0dc6584a149ed2082e1ce8757c8d57f98c91d9 | bc35ec04bc906b9dd23c210500319a568134f5a6f579082ca6c3e6a9891743e6 |

- Old source: <https://modbios.io/v2/vgabios/sapphire-rx-7900-xtx-24576-1737819644>
- Old download: <https://modbios.io/v2/vgabios/sapphire-rx-7900-xtx-24576-1737819644/download>
- Official new package: <https://cdn.sapphiretech.global/assets/download_drivers/firmwares/Sapphire_RX7900XTX_FirmwareUpdater.EXE>
- Official announcement: <https://www.sapphiretech.com/en/drivers-download>

**MODBIOS marks the old image unverified.** Its computed hash matches the archive's published hash, but vendor authenticity has not been established. Its embedded part number is an explicit source version in Sapphire's IFWIOEMMap.xml, mapping O54 to W95.

This is the newest matching Pulse baseline found, not proof that every difference was introduced solely to fix the announced security issue. No firmware or updater executable was run; no hardware was flashed.

## Firmware components

Both files have two identical firmware slots, at [0x20000,0x100000) and [0x100000,0x1e0000). Each slot was independently compared. Entries were matched by full numeric GPU directory type rather than applying CPU-oriented component names.

Of 31 resolved slot-relative directory entries, **7 differ and 24 are byte-identical**. Some entries overlap, so they are not independent regions. Another entry, 0x144, uses physical addressing and is left explicitly unresolved by the parser.

| Directory type | Finding |
|---|---|
| 0x0001 | Signed, encrypted payload; ImageVersion **0x20183100 -> 0x201c3100**; signed-size field 11,456 -> 11,584 bytes |
| 0x0002 | Signed, encrypted payload; ImageVersion **0x20183100 -> 0x201c3100**; signed-size field 80,640 -> 84,672 bytes |
| 0x0040 | Signed, unencrypted payload; ImageVersion **0x22010253 -> 0x22010277**; 37,309 bytes differ in its allocated region |
| 0x005c | Signed, unencrypted payload; ImageVersion **0x22010253 -> 0x22010277**; signed-size field 16,128 -> 20,224 bytes |
| 0x0137 | Legacy ATOM VBIOS; 1,054 of 57,856 bytes differ |
| 0x0141 | 256-byte payload; 255 bytes differ; purpose not established |
| 0x0147 | Payload begins VBL_DATA_TABLE; 310 of 7,008 bytes differ; overlaps legacy VBIOS |

The signed/encrypted classifications come from the firmware headers, not from cryptographic signature verification. The SecPatchLevel fields in entries 0x0001 and 0x0002 remain **3**. This neither establishes nor rules out a security fix. Encryption prevents plaintext instruction-level comparison of these two payloads.

## GOP is unchanged from O54

The GOP option ROM starts at file offset 0x4e200. Both versions have the same image allocation and EFI compressed-image offset 0x60.

The **entire GOP ROM from offset 0x60 onward is byte-identical**, including the compressed executable and its signed-data container. The only five changed bytes are in the outer build label: `89350` -> `196940`. The internal driver remains **AMD GOP X64 Rel Driver Rev.3.7.13, Jul 21 2023**.

An initially located July 2023 O4X baseline contained GOP 3.7.12. Its executable changes are documented in `gop-analysis/REPORT.md`, but the O54 comparison establishes that they predate this release. They must not be presented as evidence of a new GOP or Secure Boot security fix.

## ATOM tables and DRAM information

Of 22 present ATOM data tables, 4 differ and 18 are byte-identical:

| Changed table | Difference |
|---|---|
| firmwareinfo | One byte at +0x4, updating the firmware revision |
| sw_datatable9 | Two bytes in base-image filename: `...PRD006B_E_000423.sbin` -> `...PRD006B_E_000496.sbin` |
| sw_datatable25 | 681 of 5,728 bytes differ; proprietary field semantics not established |
| vram_info v3.0 | 16 of 4,810 bytes differ, all inside the DRAM-information region [0xc8,0x7f8) |

Changed VRAM-table offsets:

- 0x3f7, 0x437, 0x477, 0x4b7: **0x04 -> 0x02**
- 0x50f, 0x54f, 0x58f, 0x5cf, 0x60f, 0x64f, 0x68f, 0x6cf, 0x70f, 0x74f, 0x78f, 0x7cf: **0x03 -> 0x02**

The individual DRAM field names and their performance/stability effects have not been established. The distinct memory-tuning region beginning at 0x7f8 is unchanged.

Unchanged named tables include **smc_dpm_info, smu_info, voltageobject_info, umc_info, gfx_info, dce_info, and displayobjectinfo**. All five present ATOM command tables are also identical. The conventional powerplayinfo table pointer is absent in both versions, so this does not establish that every possible power, clock, or fan parameter is unchanged.

## Reproduction and limitations

The following commands refer to the original research workspace. Its scripts,
inputs and test outputs are not included in this repository:

```sh
python3 sapphire-firmware-research/compare_ifwi.py \
  sapphire-firmware-research/old-candidates/pulse-113-3E4710U-O54-modbios-1737819644.rom \
  sapphire-firmware-research/rx7900xtx/471PWSHU.W95 \
  --old-directory 0x20000 --new-directory 0x20000

python3 -m unittest discover -s sapphire-firmware-research -p 'test_*.py' -v
```

The comparison parser uses only Python's standard library. It requires the directory to begin at the specified slot base, checks bounds, rejects duplicate entries, and marks unsupported address modes unavailable instead of comparing empty bytes. Eight tests pass. Repeating with bases 0x100000 validates the second slot independently.

Results: `pulse-O54-to-W95.json`, `pulse-O54-to-W95-secondary-slot.json`. Earlier baseline results: `COMPARISON-O4X.md`, `pulse-O4X-to-W95.json`. GOP tool provenance and disassembly: `gop-analysis/REPORT.md`.

Format references:

- Linux ATOM structures: <https://github.com/torvalds/linux/blob/master/drivers/gpu/drm/amd/include/atomfirmware.h>
- PSP address modes: <https://github.com/coreboot/coreboot/blob/main/src/vendorcode/amd/psp/psp_directory.h>
- Firmware-header names and offsets: diagnostic format strings embedded in the official Sapphire updater, extracted into `updater-strings.txt`.

This is a static comparison of one Sapphire Pulse model. It does not establish behavior for every RX 7000 card, hardware performance, a CVE, or the semantic contents of encrypted firmware.
