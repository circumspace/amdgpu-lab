# What changed in Sapphire's RX 7900 XTX security firmware

## Executive result

**The encrypted firmware was successfully decrypted.** Comparing the recovered code reveals concrete security hardening in the PSP stage-2 bootloader: integer-overflow rejection, narrower register-access permissions, and more complete supervisor-call buffer validation. The update also includes initialization changes unrelated to any proven vulnerability.

This comparison is **Pulse 113-3E4710U-O54 -> 113-3E4710U-W95**, BIOS .034 -> .045. The older image comes from an archive marked unverified; the new image comes from Sapphire's official updater. The source part number is explicitly supported by Sapphire's upgrade map. Input provenance is in `COMPARISON.md` and `old-candidates/pulse-O54-provenance.md`.

No firmware was executed, no hardware was accessed, and nothing was flashed.

## Decryption and validation

The public PSPTool constant named `UNWRAPPED_IKEK_ZEN_PLUS` works on the two encrypted components in both images. Its CPU-oriented name was not treated as evidence of GPU compatibility; actual decryption was tested.

The scheme is:

1. AES-128-ECB unwrap the per-image MEK stored at header offset 0x80.
2. AES-128-CBC decrypt the body using that MEK and the IV at header offset 0x20.
3. Require the SHA-256 of the entire recovered body to equal the digest already stored at header offsets 0xd0..0xef.

**All four recovered bodies match exactly.** Independent ARM-vector, CP15/VBAR, and ARM/Thumb control-flow checks corroborate the result. The alternative published Zen key fails all four digest checks. This is verified plaintext, not a plausible-looking entropy reduction.

Recovered files are in `decryption/output/{old,new}-000{1,2}.plaintext.bin`. They contain bodies only. Complete hashes, source revision, algorithm, negative controls, tests, and reproduction commands are in [decryption/REPORT.md](decryption/REPORT.md).

### Signature cross-check

All four original encrypted type-1/type-2 images also pass **RSA-4096 PSS with SHA-384** verification over their original header and ciphertext. Type 1 verifies directly against the public key embedded in Sapphire's official new package. Type 2 verifies against a keystore key, and that keystore's signature verifies against the same package's primary key. The old and new key material is identical.

This establishes that the compared old payloads carry valid signatures under the key supplied by the official update, rather than trusting an archive label or body hash alone. It does not establish an independently anchored AMD certificate chain or authenticate every byte of the old board ROM. Reproduction and trust limits are in [signature-analysis/REPORT.md](signature-analysis/REPORT.md).

## Security-relevant changes and their purpose

### 1. Prevent 32-bit buffer-range wraparound

In the PSP stage-2 SVC sanitizer, the old predicate was equivalent to:

```c
address >= 0x80000 && uint32_t(address + length) <= 0x94000
```

The new predicate additionally requires:

```c
uint32_t(address + length) > address
```

**Why it matters:** the old calculation can wrap. For address 0xfffffff0 and length 0x20, the end becomes 0x10, which incorrectly passes the old upper-bound test. The new check rejects that case. It also rejects zero-length buffers.

This function is used by firmware supervisor-call parameter sanitizers. The dispatcher checks sanitizer status before performing the operation. The decoded function moves from old VA 0xa644 to new VA 0xa79c. Exact instructions and predicate test cases: [psp2-analysis/REPORT.md](psp2-analysis/REPORT.md), section 1.

This demonstrates a flawed validation predicate and its correction. It is not a demonstrated exploit, and direct host or remote reachability was not established.

### 2. Stop an allowed register address granting doubleword access

The old register allowlist accepted widths up to **8 bytes** at six starting addresses. The new list stores an individual maximum width per entry; all six limits are **4 bytes**.

The affected SVC paths are confirmed:

- SVC 0x70 reads a register into an output buffer.
- SVC 0x71 writes to a register.
- SVC 0x72 performs a fixed-width 4-byte read/modify/write and remains allowed.

The old helpers explicitly implement both `ldrd` and `strd`, so this changes effective read/write permissions from **1/2/4/8 bytes to 1/2/4 bytes**.

**Why it matters:** permission to access one starting register no longer implicitly permits a doubleword operation extending into the adjacent register. The six allowed addresses are unchanged. Symbolic register names, exploitability, and CVE identity were not established.

Evidence: old validator VA 0x823c, new VA 0x8380; [psp2-analysis/REPORT.md](psp2-analysis/REPORT.md), section 2.

### 3. Reject wrapped 64-bit flash-metadata offsets

A separate ISH metadata validator computes a 64-bit end offset and already requires the end to be within a 2 MiB image and the entry length to equal 32 bytes. The new code also requires:

```c
end >= offset
```

**Why it matters:** a near-maximum 64-bit offset plus 32 can wrap to a small number and pass the old end-bound check. The new unsigned comparison rejects that arithmetic overflow. Normal entries ending at the image boundary remain valid.

Evidence: old VA 0x11264, new VA 0x11818; [psp2-analysis/REPORT.md](psp2-analysis/REPORT.md), section 3. Full host-flashing reachability was not established.

### 4. Validate more of nested SVC arguments

Examples from the decoded sanitizer:

- SVC 0xd0 now checks an 8-byte descriptor, a 40-byte format-string region, and `%s` argument buffers through a bounded scanner.
- SVC 0x86 and 0x97 validate a 24-byte structure instead of only 4 bytes.
- Additional pointer/length pairs are validated in nested descriptors.
- A component-copy path rejects a reported size above 0x98 before copying.

**Why it matters:** validating only a pointer-sized prefix does not validate the complete structure or the buffers it references. These changes extend checks to data the service subsequently uses.

This is not a proof that every path is safe. One examined local path records a validation error and then continues dereferencing before the overall operation returns; the report documents that limitation rather than claiming complete remediation.

## Other changes, separate from the security conclusions

### Stage-1 boot state and sequencing

New type-1 code clears a retained state marker when neither of two mapped hardware status registers has bit 1 set. Previously the two recognized marker values could bypass an initialization branch without this new gate. There are also additional status tests and delay/control-sequencing changes. This is consistent with tighter retained-state handling, but the register names and vendor rationale remain unknown.

Evidence: [psp1-analysis/REPORT.md](psp1-analysis/REPORT.md).

### Hardware initialization

The unencrypted components add a six-instance command/check/retry sequence with failure propagation. A channel-completion wait changes from one register's full value to another register's status field and increases its polling budget tenfold. Some configuration layouts and register routing also change.

These are real behavior changes, plausibly concerning hardware initialization reliability. They are not labelled security fixes without an identified trust boundary or vulnerability.

Evidence: [arm-analysis/REPORT.md](arm-analysis/REPORT.md).

### Display presets and DRAM fields

The previously unidentified 681-byte ATOM-table difference is **only a permutation of 159 display-PHY preset records**. Every complete record and electrical setting is unchanged.

The 16 changed DRAM bytes are identifiable as **tCCDL** fields. However, the traced converter uses tCCDS instead when a flag is clear. That flag is clear in all 16 edited rows, and tCCDS remains 2. Therefore these edits do not alter the three examined converted fields in this path. No VRAM performance benefit is established.

The GOP executable and its signature remain byte-identical to O54; only the outer build label changes.

Evidence: [table-analysis/REPORT.md](table-analysis/REPORT.md) and the ARM report's timing-conversion section.

## What can and cannot be concluded

**Established:** actual firmware code fixes address arithmetic and access-scope mistakes at PSP service boundaries. Those are defensible technical reasons to describe W95 as security hardening, rather than merely a cosmetic BIOS update.

**Not established:** the CVE, which specific change prompted Sapphire's notice, a demonstrated attack chain, remote/host reachability, severity, or the complete vendor rationale. The comparison spans two releases, so it also contains unrelated accumulated changes.

Tests exercise parser boundaries, decryption known-answer/digest checks, exact firmware bytes and tables, and reconstructed range predicates. They do not execute firmware or simulate the GPU. Reports distinguish direct instruction-level findings from interpretation and unresolved details.
