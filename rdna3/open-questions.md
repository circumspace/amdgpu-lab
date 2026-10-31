# Open questions

- **Card purchase.** None recorded as of 2026-10-25. Target one used 7900 XTX,
  €800–900. A second is a separate decision.
- **PSU rating and case clearance.** Must be read off the hardware.
- **Full GPU residency.** Does Qwen3.6 IQ4_XS fit in 24 GB with the intended
  128k context, drafter, two slots and safe VRAM headroom? Measure on the card.
- **ROCm vs Vulkan on gfx1100.** RDNA2 ROCm results do not resolve conflicting
  third-party RDNA3 reports; measure on the card.
- **RDNA boosts on RDNA3.** Compare a pinned release against matched upstream,
  including full-prompt prefill, deep context, decode, output checks and VRAM.
  On RDNA2 the latest matched test improved shallow chunk-prefill but regressed
  at 120k; it was not a full-server benchmark. See
  [Qwen3.6 results](../rdna2/benchmarks/qwen36.md).
- **Speculation on RDNA3.** Re-test DSpark and n-gram draft lengths and MTP.
  Seven-token DSpark drafts lost on RDNA2; that result does not transfer to
  RDNA3.
- **Qwen3.8 Flash Next.** Retest VRAM, speed, tools, vision and broader agent
  quality on the XTX. The [RDNA2 trial](../rdna2/benchmarks/qwen38.md) used a
  Q2 model with CPU-offloaded experts and has only small quality samples.

The second RAM DIMM was installed: the 2026-10-28 measurements used 64 GiB
dual-channel at 3200 MT/s. The pending r123 plan is superseded by the measured
r126 and later matched-upstream comparisons; their RDNA2 verdicts are not a
substitute for an RDNA3 test.
