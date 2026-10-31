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

- **RDNA2 (6700 XT):** production is Qwen3.6-35B-A3B IQ4_XS on ROCm with
  DSpark + n-gram and 64 GiB dual-channel RAM. The
  [Qwen3.6 measurements](rdna2/benchmarks/qwen36.md) cover the RAM upgrade,
  speculation, backend comparisons and the rdna-boosts fork. The
  [Qwen3.8 Flash Next experiment](rdna2/benchmarks/qwen38.md) is not deployed.
  Bonsai 27B fits with 110K context but is slower; see
  [bonsai-vs-qwen.md](rdna2/results/bonsai-vs-qwen.md).
- **RDNA3 (7900 XTX):** not yet bought as of the 2026-10-25 record. Bring-up
  steps are in [rdna3/bringup.md](rdna3/bringup.md); the engine search space is
  in [rdna3/engine-design.md](rdna3/engine-design.md). Whether the existing
  IQ4_XS and serving context fit fully in 24 GB remains to be measured.

## Two tracks

1. **Inference** — get the best local LLM out of each card (llama.cpp forks,
   ExLlamaV3, tinygrad, vLLM). See `projects/` and the per-arch `benchmarks/`.
2. **Firmware and scheduling** — the longer bet: tinygrad's Worm persistent
   scheduler and reimplementing on-card firmware (PSP code execution is the
   gate). See `docs/worm.md` and `firmware/`.
