# RDNA2 (6700 XT) — Ternary Bonsai-27B, Vulkan/RADV

Ternary-Bonsai-27B Q2_0 (6.66 GiB, dense 27B, all layers on GPU), PrismML fork
62061f91, Vulkan/RADV. Container built from
[../runs/Containerfile.bonsai](../runs/Containerfile.bonsai); runs via
[../runs/sweep-run.sh](../runs/sweep-run.sh) and
[../runs/sweep30.sh](../runs/sweep30.sh). Production stopped for each run.
RADV reports NAVI22, fp16 yes, no matrix cores (expected for RDNA2).

## First sweep (`llama-bench -ngl 99 -fa 1 -r 3`)

| test | t/s |
|---|---|
| pp512 | 164.96 |
| pp2048 | 155.23 |
| tg128 @ d0 | 13.78 |
| tg128 @ d8192 | 21.12 (warmup artifact) |

## 30-min sweep (clock pinned high, q8_0 KV for depth)

| phase | result |
|---|---|
| decode @ high power, d0 | tg128 **13.78** — identical to auto power |
| prefill, d0 | pp512 163.8 |
| decode @ 32K / 64K | tg64 15.6 / 13.75 |
| prefill @ 32K / 64K | pp512 105 / 77 |
| 110K context fit (q8_0 KV) | **loads, 10.91 GiB VRAM** |
| DSpark drafter | not measured — fork renamed `--draft-max` to `--spec-draft-n-max` |

## Reads

- **The whole dense 27B fits in 6.66 GiB** with no CPU offload — the opposite of
  the production MoE. Leaves ~5 GiB for context.
- **Clock-sag was the wrong diagnosis.** Forcing the card high left decode at
  13.78, unchanged. Steady decode is ~14 t/s regardless of power state or depth.
- **Decode barely feels depth** (13.75 at 64K), matching prism's claim.
- **110K context fits fully on-GPU** at 10.91/12 GiB with q8_0 KV.
- Decode (~14 t/s) is well below the production MoE's 28–44 t/s. The DSpark
  drafter is the only remaining lever, and the whitepaper's 1.34× is CUDA-only —
  batch-1 Vulkan is unproven, so a retry is low-value. See the verdict in
  [../results/bonsai-vs-qwen.md](../results/bonsai-vs-qwen.md).
