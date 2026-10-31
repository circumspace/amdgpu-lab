# Bonsai quantization: what the whitepaper reveals

Source: PrismML, [Bonsai 27B whitepaper](https://github.com/PrismML-Eng/Bonsai-demo/blob/main/bonsai-27b-whitepaper.pdf)
(July 2026).

## The method is not disclosed

The weight transform is **proprietary Caltech IP** — the paper calls it "a
mathematically grounded framework rather than a collection of heuristics" and
gives no algorithm, loss, or procedure. The appendices are deployment, kernels,
and eval methodology only. **The quantizer cannot be reproduced from the paper.**

What the paper does establish:

- **Post-training transform, not from-scratch training.** Explicitly the
  opposite of BitNet: it "starts from an off-the-shelf pretrained model and moves
  it into a binary or ternary representation." Input is Qwen3.6-27B FP16; the
  transform is the secret.
- **End-to-end low-bit, no escape hatches.** Embeddings, attention projections,
  MLP projections, and LM head all at a true 1.71 bpw (ternary) / 1.125 (binary).
  Only the vision tower (4-bit HQQ) and a tiny tail of norms/scales stay higher.
  Their thesis is that conventional sub-4-bit quants only survive by keeping
  sensitive tensors at 4–8 bit; Bonsai does not.
- **Format**: {−1,0,+1} (or {−1,+1}), one FP16 scale per group of 128 (g128).
- **Quality**: ternary 80.49 avg = 94.6% of FP16 across 15 benchmarks (thinking
  mode); math/coding within a few points of baseline. This is the number a naive
  requant cannot touch.

## What IS public

- The **KV-mean-center** calibration only — K-cache centering for 4-bit KV, not
  weight quant (`PrismML-Eng/llama.cpp tools/kv-mean-center/`, Issue #54).
- The **inference kernels**: prism ships MLX and CUDA; the community adds a RADV
  Vulkan fork (what we built) and an AMD HIP/ROCm port with the low-bit kernels
  ([The-Monk rock8](https://github.com/The-Monk/llama.cpp/releases/tag/rock8-v1),
  gfx1030/1100/1151/1201). So the low-bit *inference* path exists on AMD; only the
  weight *quantizer* (the rotation + calibration) stays closed.

## Consequences for a DIY 35B Bonsai

- **Not feasible at their quality.** A ternary cast with the fork's stock TQ2_0 is
  exactly the "conventional sub-4-bit" path the paper shows collapsing (IQ2_XXS
  drops to 72.7% / AIME 57.5). The whole value is the undisclosed transform.
- **No MoE Bonsai exists.** The paper is dense-27B only; "architecture-agnostic"
  is a roadmap claim, not a release.

## Outreach hooks (from the paper's own roadmap)

- **"Agentic coding, next. A Bonsai 27B variant tuned for agentic coding is next
  on the roadmap and will follow shortly."** Directly matches the coding-assistant
  use case — ask about early access rather than the quantizer.
- "Broader hardware and architectures … architecture-agnostic" — a larger/MoE
  Bonsai is plausibly askable, framed as "would you make it," not "send the tool."

## DSpark drafter (relevant to our failed Vulkan test)

Measured gains are **CUDA-only**: ternary 98 → 131.8 t/s, 1.34×, accepted length
3.7 at draft depth 4. On Apple Silicon at batch 1 it is **not enabled** — the
verification pass doesn't amortize. Our Vulkan path is the same batch-1 regime, so
a drafter retry is low-value: by prism's own account the benefit is unproven off
CUDA.
