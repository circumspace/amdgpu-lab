# Bonsai 27B vs production Qwen — 6700 XT

Both on the 6700 XT. Not apples-to-apples (Vulkan vs ROCm, dense vs MoE, ternary
vs IQ4_XS), but the verdict is clear on both axes.

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
driver. Its niche is a self-contained, RAM-free 27B. On the 24 GB 7900 XTX the
footprint edge largely evaporates, so Bonsai stays an experiment, not the plan.

## Custom ternary 35B — dropped

A ternary MoE 35B would fit fully in VRAM and could roughly 1.5–2× decode on the
6700 XT by killing the CPU-expert offload. But that gain lands only on the card
being retired: on the 7900 XTX the existing IQ4_XS fits in 24 GB with no spill,
so `--n-cpu-moe 0` gets the same no-spill win at full quality and zero new
tooling. Ternary would trade ~5% quality for a marginal edge, atop an
unreproducible proprietary quantizer with no shown MoE support. Not worth it.
