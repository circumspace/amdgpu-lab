# radeon7900

Findings and a bring-up plan for running local LLMs on the AMD RX 7900 XTX
(gfx1100, RDNA3), targeting the `benchmark-host` host.

Private. Source of truth is Gitea (`circumspace/radeon7900`); no mirror.

## Layout

- `notes/` — background and imported analyses
  - `worm.md` — tinygrad's persistent-scheduler experiment
  - `firmware.md` — on-card firmware blocks and the PSP reimplementation goal
  - `astra-findings.md`, `astra-comparison.md` — Sapphire Pulse firmware diff
- `projects/` — external projects inspected, with a verdict each
- `plan/` — the benchmark-host bring-up plan and open questions

## Two tracks

1. **Inference now.** Get the best batch-1 decode out of the card with existing
   runtimes (llama.cpp forks, tinygrad, vLLM ROCm). Measured on `benchmark-host`.
2. **Firmware and scheduling.** The longer bet: a persistent GPU scheduler
   (Worm) and, further out, reimplementing on-card firmware. PSP code execution
   is the precondition for the firmware half.
