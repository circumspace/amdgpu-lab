# RDNA2 (6700 XT) — measured baselines

tok/s, single user. Host: benchmark-host (see [../specs/benchmark-host-6700xt.md](../specs/benchmark-host-6700xt.md)).

Production: Qwen3.6-35B-A3B heretic MTP IQ4_XS, `--n-cpu-moe 24`, upstream b11804 ROCm.

| Test | tok/s |
|---|---|
| Prompt read, 3.8k / 117k | 979 / 443 |
| Write, short / 117k | 28.2 / 21.4 |
| File rewrite | 173–183 |
| Fresh code | ~44 |

Decode is limited by the CPU-offloaded experts (`--n-cpu-moe 24`), not the quant.
On a 24 GB card the whole MoE fits in VRAM — drop the offload for a large decode
gain at full quality (see [../../rdna3/bringup.md](../../rdna3/bringup.md)).

## rdna-boosts A/B (stew675 fork)

- **ROCm vs Vulkan (2026-10-11):** ROCm read 2.2× faster, generated +57%.
- **r120:** generation ~even; 117k read −19%; VRAM floor 66 MB. Rejected.
- **r126 (llama-bench, fetch-ahead off):** +38% @d0, +30–37% to 24K, −1% @80K,
  −10% @120K. In the real server: read −5% @3.8K / −16% @117K, generation −3–5%,
  only rewrites gained; band clamp on, the r123 bug makes rewrites 16–23% slower.
  **Rejected for benchmark-host.**
- **Adaptive MTP PR #27210:** +6–10% fresh code, 81% draft acceptance; without
  ngram-mod rewrites collapse to 48. Rejected.
- **ngram-mod with experts in RAM:** −3–7% fresh code, ~3× faster rewrites. Kept.

RDNA2 rejections do not carry to RDNA3 — the WMMA paths need their own A/B.
