# RDNA3 inference engine — north star

The goal is the best single-user (batch-1) inference on the RX 7900 XTX
(gfx1100), reusing what the forks already give us. **Not a new engine** — a
curated llama.cpp HIP build whose configuration is chosen by measurement, the
same loop that got RDNA2 far. The engine is the measurement loop; the code is its
search space.

## The ceiling, and the only three levers

Batch-1 decode is memory-bandwidth-bound: the rate is capped by
`~960 GB/s ÷ resident footprint per token`. No engine beats that. The only levers:

1. **Shrink the footprint** (quantization) — raises the ceiling and frees VRAM.
2. **Skip forward passes** (speculative decoding) — fewer target runs per token.
3. **Cut launch/overhead** (kernel fusion, launch geometry, eventually a
   persistent kernel).

Prefill is compute-bound and separate: it wants WMMA and good launch geometry.

## Composition search space (reuse map)

| Dimension | Reuse | New work |
|---|---|---|
| Base engine | upstream llama.cpp, ROCm/HIP backend (all forks derive from it) | settle ROCm vs Vulkan on gfx1100 empirically |
| Weights | IQ4_XS (safe), EXL3 (ExLlamaV3), or rotated low-bit via rock8 | the open rotation-quant pipeline below |
| Low-bit kernels | [rock8](https://github.com/The-Monk/llama.cpp/releases/tag/rock8-v1) Q1_0/Q2_0 SWAR+dp4a, gfx1100 (MIT) | RDNA3 tile/launch tuning |
| Prefill | rdna-boosts WMMA flash attention; rock8 GDN fusion + wide-FWHT blocks | WMMA tile shapes for gfx1100 |
| Speculative | MTP (Qwen3.6 built-in) + ngram-mod (upstream) + DSpark/Markov drafter (rock8 `graft_mtp.py`) | draft depth/acceptance tuning; keep drafter resident in freed VRAM |
| KV cache | q4_0 + kv-mean-center (public); or q8_0 | — |
| Serving | llama-swap + the existing gateway | — |

## The novel piece: an open rotation-quant pipeline

Bonsai's quality comes from Hadamard-rotation incoherence quant (QuaRot /
SpinQuant family); prism's quantizer is closed, but the **technique is open**.
QuaRot/SpinQuant are PyTorch, run on the XTX via ROCm, and emit Hadamard-basis
rotated weights — exactly what rock8's AMD kernels consume. So:

```
Qwen3.6 FP16 → QuaRot/SpinQuant (rotate + calibrate, on-GPU) → rotated low-bit
             → rock8 HIP kernels (gfx1100)
```

This is Bonsai-class sub-4-bit **without** the proprietary quantizer. Feasibility
hinges on the rotated-weight format matching rock8's expectation; that's the first
thing to verify in v2. See [../docs/bonsai-method.md](../docs/bonsai-method.md).

## The method: measurement-driven, with RDNA2's guardrails

The config above is a search space, not a plan. Each candidate
(quant × KV type × spec params × WMMA/GDN flags × `--n-cpu-moe`) runs through the
existing harness; the engine is the config that survives. The harness transfers
unchanged — it tests the server through the API, so the architecture is
irrelevant to it: `llm-bench` / `abtest.sh`, the KLD pipeline, SWE-bench-Live.

Acceptance criteria, learned the hard way on RDNA2:

- **Real server, not microbenchmarks.** r126 was +38% on `llama-bench` and
  regressed in the server. Score the running server on real workloads.
- **Score per workload class** — prompt-read, short-write, fresh-code,
  file-rewrite, deep-context — because a change helps one and hurts another
  (ngram-mod: −3–7% fresh code, 3× rewrites).
- **Quality gate is a hard filter**, beside speed: KLD vs baseline +
  recall/mini50/SWE-bench-Live. A fast config that degrades output is rejected.
- **Pin the variables and measure assumptions.** Image by digest, env flags
  explicit. power=high taught us this — it did nothing; assuming would have lied.

RDNA2 *data* does not transfer (rejections don't carry to gfx1100); the *method,
harness, and guardrails* do — which is most of the value. Runs accumulate into
`rdna3/benchmarks/` and `rdna3/results/` so the insight compounds.

## Tiers

- **v1 — proven win, low effort.** Upstream HIP + IQ4_XS with `--n-cpu-moe 0`
  (whole MoE in 24 GB, no CPU spill) + MTP/ngram-mod speculative + rdna-boosts
  WMMA flash attention. Likely most of the gain, at full quality.
- **v2 — frontier, medium effort.** QuaRot → rock8 rotated low-bit, freeing VRAM
  for a resident drafter + large KV; GDN fusion for the hybrid layers.
- **v3 — research.** Persistent / megakernel to kill batch-1 launch overhead
  (Worm's lesson); high risk, likely tinygrad not llama.cpp.
  See [../docs/worm.md](../docs/worm.md).

## Iteration speed on the XTX

The harness itself runs far faster here, which changes how the loop is used:

- ~2.5× bandwidth, more compute, WMMA, and no CPU-expert spill — the slow parts
  (deep-context KLD/perplexity, cold prefills) collapse.
- 24 GB runs two variants at once, so A/B stops serializing.
- The payoff is not just speed but **scope**: the fuller eval suite and more
  repeats become affordable, so confidence rises, not just throughput.
- Fixed costs (model swap, scoring, SWE-bench harness, quantizer runs) don't
  scale with the GPU.

## Prerequisites and open questions

- The card (not yet bought), PSU, case clearance — see
  [open-questions.md](open-questions.md).
- ROCm vs Vulkan on gfx1100 — unsettled, decided by v1 measurement.
- Whether rdna-boosts WMMA and rock8 actually win on gfx1100 — untested.
- Whether QuaRot's rotated weights load into rock8's kernels — the v2 gate.
- Gated on v1 numbers justifying the v2/v3 effort.
