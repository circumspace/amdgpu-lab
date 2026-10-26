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

Agent benchmark on fresh multi-language tasks: [swebench-live.md](swebench-live.md).

## Where generation time goes (2026-10-26)

Production flags, upstream b11804, single-channel RAM.

- **GPU busy while generating:** 18–53 % in passive snapshots, at 73–134 W.
  Reading a 117K prompt holds 99 % at 185 W. The GPU waits on the 24 CPU-held
  expert layers for much of each token.
- **`HSA_ENABLE_SDMA=0`:** generation level within ±5 %, prompt reading
  2–4 % slower. The small CPU↔GPU copies per token are not a measurable cost.
- **HIP graphs** (`GGML_CUDA_GRAPH_DEBUG=1`, needs `--verbose`; `-lv 4` shows
  nothing): reused for 99 % of launches on fresh code, 97 % on chat, 96 % on
  rewrites. Resets follow the changing draft-verify batch sizes.
- **`--no-cache-idle-slots` with `-np 2 -kvu`:** a 117K conversation held in one
  slot slowed fresh code in the other from 42 to 26 tok/s. Removed from prod.
- **DSpark** (RedHatAI drafter, Q8_0, `--spec-draft-n-ubatch 256`,
  `--spec-ngram-mod-n-match 64`): level with MTP + n-gram on chat, fresh code
  and rewrites; ~190 MiB more VRAM free. Rejected for benchmark-host.
- **Expert cache** (`--moe-cache-mib 512`, 2026-10-19, q4_0 KV): slower than no
  cache on every probe; no hit-rate stats captured. Not retried.

Custom HIP kernels for RDNA2 would only speed up the GPU share, roughly half of
generation at best, on a card being retired. Kernel-time breakdowns belong on
the 7900 XTX, where the whole model is GPU-resident.
