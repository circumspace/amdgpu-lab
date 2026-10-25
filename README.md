# amdgpu-lab

AMD GPU inference experiments: running local LLMs on Radeon, plus the firmware
and scheduler work around it. Private; source of truth is Gitea
(`circumspace/amdgpu-lab`), no mirror.

Per-architecture work lives under `rdna2/` and `rdna3/`; everything that spans
both sits at the top level.

## Layout

```
rdna2/                 RX 6700 XT (gfx1031) — current host
  specs/               host and card facts
  runs/                Containerfiles and sweep scripts (reproducible)
  benchmarks/          measured numbers
  results/             verdicts and comparisons
rdna3/                 RX 7900 XTX (gfx1100) — target card
  specs/               card facts
  benchmarks/          third-party numbers (none measured yet)
  bringup.md           ordered bring-up plan for benchmark-host
  open-questions.md    what's unresolved
projects/              external projects inspected, with a verdict each
firmware/              on-card firmware blocks; imported Astra PSP analysis
docs/                  cross-cutting notes — Worm scheduler, Bonsai method
```

## Status

- **RDNA2 (6700 XT):** production is Qwen3.6-35B-A3B IQ4_XS on ROCm. Bonsai 27B
  measured on Vulkan — fits a dense 27B + 110K context in VRAM but decodes at
  ~14 t/s, too slow to replace Qwen. See
  [rdna2/results/bonsai-vs-qwen.md](rdna2/results/bonsai-vs-qwen.md).
- **RDNA3 (7900 XTX):** not yet bought. Bring-up steps in
  [rdna3/bringup.md](rdna3/bringup.md); the north star for the engine —
  composition search space, the open QuaRot→rock8 rotation-quant pipeline, and
  the measurement-driven method — is in
  [rdna3/engine-design.md](rdna3/engine-design.md). The first win is running the
  existing IQ4_XS fully in 24 GB VRAM with no CPU-expert offload.

## Two tracks

1. **Inference** — get the best local LLM out of each card (llama.cpp forks,
   ExLlamaV3, tinygrad, vLLM). See `projects/` and the per-arch `benchmarks/`.
2. **Firmware and scheduling** — the longer bet: tinygrad's Worm persistent
   scheduler and reimplementing on-card firmware (PSP code execution is the
   gate). See `docs/worm.md` and `firmware/`.
