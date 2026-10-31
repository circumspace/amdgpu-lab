# Firmware

## Components on the 7900 XTX

| Block | What it runs |
|---|---|
| PSP (Platform Security Processor) | ARM core that boots first and verifies the signatures of all other firmware |
| SMU | Power, clocks, fans, voltage |
| MEC | Command processor for compute queues |
| ME, PFP | Command processor for graphics queues |
| RLC | Power gating and context save/restore for the graphics block |
| SDMA | Copy engines |
| VCN | Video encode and decode |

## Why PSP code execution matters

The PSP refuses unsigned firmware for every other block. Running our own code
on it is the precondition for replacing any of them. The stated goal on the
tinygrad side is to reimplement all firmware on the 7900 XTX, and PSP code
execution would be of strong interest to them.

Worm deliberately avoids this path for compute: it leaves the MEC alone and
gets its gains from a persistent kernel.

## Firmware analyses

AI-assisted analysis of a Sapphire Pulse firmware update, O54 -> W95
(BIOS .034 -> .045), imported from a separate ChatGPT research workspace. The
underlying tools, firmware files and detailed reports are not in this repository;
the findings have not been independently reproduced here:

- [astra-findings.md](astra-findings.md): the W95 payloads were decrypted and
  their RSA-4096 signatures verified. The PSP stage-2 changes are real security
  hardening: integer-overflow rejection in the SVC buffer sanitizer, register
  access narrowed from 8 bytes to 4, and wider validation of nested SVC
  arguments. No CVE, exploit chain or host reachability was shown.
- [astra-comparison.md](astra-comparison.md): the initial structural diff that
  located the seven changed firmware payloads. References to supporting reports
  name files in the original workspace, not files in this repository.

Relevance to the reimplementation goal: these are vendor images, decrypted and
verified but not executed. They map part of the PSP SVC surface, which is the
interface our own PSP code would have to satisfy or replace.
