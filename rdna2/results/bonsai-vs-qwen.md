# Bonsai 27B vs production Qwen — 6700 XT

Both were measured on the 6700 XT with single-channel RAM. These historical
results are not apples-to-apples (Vulkan vs ROCm, dense vs MoE, ternary vs
IQ4_XS). For later dual-channel Qwen measurements see
[qwen36.md](../benchmarks/qwen36.md).

| | Bonsai 27B (Vulkan) | Qwen 35B-A3B (ROCm, production) |
|---|---|---|
| Decode, shallow | 13.8 t/s | 28.2 (short) · ~44 (fresh code) |
| Decode @ 32K / 64K | 15.6 / 13.75 | — (117K write: 21.4) |
| Prefill @ 0 / 32K / 64K | 164 / 105 / 77 | read 979 (3.8K) / 443 (117K) |
| File rewrite | not measured | 173–183 |
| VRAM | model + 110K ctx = 10.9/12 GiB | spills — 24 expert layers in RAM |
| Fits on-GPU | dense 27B + 110K, RAM free | needs `--n-cpu-moe 24` + ~15 GB RAM |

## Verdict

**Qwen wins decode decisively** (2–3×): its MoE activates only ~3B params/token,
while Bonsai reads all 27B. ~14 t/s is near Bonsai's 6700 XT ceiling and won't
move — clock pinning did nothing, and the drafter is a dead end on Vulkan.

**Bonsai wins footprint decisively**: a full dense 27B plus a 110K context
entirely in VRAM with RAM free. That is its whole case — not speed.

**For benchmark-host:** at ~14 t/s Bonsai is too slow to replace Qwen as the daily
driver. Its niche is a self-contained, RAM-free 27B. Re-test the footprint
tradeoff on the 24 GB 7900 XTX; full Qwen residency is not yet measured.

## Custom ternary 35B — dropped

A ternary MoE 35B might fit fully in VRAM and reduce CPU-expert offload on the
6700 XT; the claimed speedup is unmeasured. On a 7900 XTX, first test whether
the existing IQ4_XS and serving context fit without CPU spill. Ternary would
trade quality for a possible speed or memory advantage and requires additional
tooling; the quality tradeoff and MoE support remain unverified here.
