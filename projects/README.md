# Projects inspected

Verdicts are for the 7900 XTX (gfx1100) unless noted. "Measured by us" means on
the current RDNA2 6700 XT; no 7900 XTX is in hand yet.

## Inference runtimes

| Project | What it is | Verdict |
|---|---|---|
| [stew675/llama-cpp-rdna-boosts](https://github.com/stew675/llama-cpp-rdna-boosts) | ROCm/HIP patch series on llama.cpp: adaptive MTP, WMMA flash attention, GDN prefill, BF16 KV, fused MoE, expert-cache "arena" | **Chosen base.** Pin a release, A/B vs upstream. Rejected on RDNA2 after measurement (below) |
| [SelfRef/llama.cpp-rdna](https://github.com/SelfRef/llama.cpp-rdna) | Vulkan fork for RDNA3/3.5 with its own FP4 quant (ROCmFP4-FAST), unreadable by stock llama.cpp | Untested. Best published numbers, but one maintainer, +4.3% perplexity. One comparison later, not the base |
| slavap / C2fifield rdna-boosts forks | Mirror forks; C2fifield re-enables mixed-quant KV | Untested, no reason over stew675 |
| nasone32/llama.cpp-RDNA3-7900xtx-opt | Unmerged PRs + older rdna-boosts, two-card focus | Skip. Stale since 2026-09-10 |
| salvatoretrimarchi/llama.cpp_build_7900XTX | Tuned build for Qwen3.6-27B IQ4_XS, no speculation | Reference only |
| lemonade-sdk/llamacpp-rocm | Prebuilt ROCm llama.cpp builds | Untested, KV-savings claim weakly sourced |
| [kamm3r/exl3-rdna3-recipe](https://github.com/kamm3r/exl3-rdna3-recipe) | ExLlamaV3 1.6.3 ROCm wheels + TabbyAPI, no patches | **Promising.** Measure next to llama.cpp. Needs a glibc container; second stack |
| tinygrad | Drives AMD without ROCm; tinybox used 6× 7900 XTX | Not benchmark-host's server: no OpenAI server for quantized GGUF / Qwen MoE. Experiment only |
| vLLM on ROCm | Runs, but AMD tuning targets MI300; poor GGUF | Not pursued. RDNA4 TP=2 has open deadlock vllm#40980 |
| syv-ai/HyperQwen | vLLM 0.31 for Qwen3.8-27B on one 24 GB NVIDIA | Rejected for AMD (CUDA-only). Became the case for a 3090 |
| stable-diffusion.cpp (leejet) | Vulkan + ROCm image gen | Untested. Needs the LLM unloaded on 12 GB |
| ik_llama.cpp | CPU-held experts | RDNA2-only interest; ROCm unsupported |
| EAGLE-4 | Speculative decoding | Rejected: needs SGLang/vLLM, MI355X/B300 only, source-available |

### rock8 — the AMD/ROCm path for Bonsai low-bit

[The-Monk/llama.cpp rock8-v1](https://github.com/The-Monk/llama.cpp/releases/tag/rock8-v1)
is an all-AMD RDNA HIP fork that ports the Bonsai low-bit stack the prism fork
only ships for CUDA/Metal: Q1_0/Q2_0 SWAR+dp4a decode kernels, a gated-delta-net
DPP wave reduction, RDNA4-only MXFP6/FP8 paths, and `tools/graft_mtp.py` to graft
an MTP head onto a Bonsai target. Source-only (build `-DGGML_HIP=ON`, ROCm clang).

- **Targets gfx1030;gfx1100;gfx1151;gfx1201** (RDNA2/3/3.5/4). This is the real
  AMD-native Bonsai path — it corrects the earlier "kernels are CUDA/Metal only"
  read (see [../docs/bonsai-method.md](../docs/bonsai-method.md)).
- **RDNA3 (7900 XTX, gfx1100): track and A/B on arrival.** Explicitly targeted;
  RDNA3 prefill gains quoted at +6–30%. A ROCm Bonsai path to compare against the
  RADV Vulkan one and against the IQ4_XS MoE.
- **RDNA2 (6700 XT, gfx1031): uncertain.** gfx1031 is **not** in the target list
  (gfx1030 is); "gfx103x" support is implied, not confirmed. May need gfx1031
  added or the gfx1030 override. And the gains are mostly prefill/spec — decode
  on a dense 27B stays bandwidth-bound, so it likely won't beat the MoE Qwen as a
  daily driver.
- Correctness quoted: Bonsai-27B Q2_0 g128 PPL 10.1465. Hackathon-stage, no
  prebuilt binaries. **MIT** — the LICENSE is kept at the `rock8-v1` tag (ggml
  authors); new kernels default to MIT, and any ported from Bonsai's Apache-2.0
  code are permissively compatible.

## Firmware and scheduling

| Project | What it is | Verdict |
|---|---|---|
| tinygrad Worm | Persistent GPU scheduler, all 96 CUs | The direction. See [../docs/worm.md](../docs/worm.md) |
| PSP reimplementation | Run our own code on the Platform Security Processor | Long bet; precondition for replacing any on-card firmware. See [../firmware/README.md](../firmware/README.md) |
| Zagitta/gpu-unlock | Firmware unlock | Doesn't apply: 7900 XTX and W7900 share ~123 TFLOPS FP16; only the power cap matters |

## RDNA2 playground (current 6700 XT, until the XTX arrives)

The 6700 XT is Navi 22, **gfx1031**. Some of these target Navi 21 (gfx1030) and
won't run unchanged. All single-commit, low-star, self-reported.

| Project | What it is | Runs on the 6700 XT? | Verdict |
|---|---|---|---|
| [leapdragon/rdna2-v620-architecture-guide](https://github.com/leapdragon/rdna2-v620-architecture-guide) | 12-chapter docs-only guide to RDNA2 LLM inference (ISA, ROCm/Triton stack, llama.cpp/vLLM deep dives, gotchas) | Reading, yes | **Read it.** Best background for the inference track. Author measures 27B at 40–50 t/s on 2× V620. Says gfx1031 "largely untested", so numbers don't transfer |
| [FaisalBiyari/vLLM-ALU-RDNA2](https://github.com/FaisalBiyari/vLLM-ALU-RDNA2) | vLLM 0.30 fork adding an RDNA2 attention backend + decode GEMMs | No — gfx1030 (W6800/V620) only, validated on 4-die TP4, fp16 27B | Note for later. Closest thing to working vLLM on RDNA2, but not for this card, and fp16 27B won't fit 12 GB. Revisit if vLLM matters |
| [Maxritz/ROCr-LLM-RDNA2](https://github.com/Maxritz/ROCr-LLM-RDNA2) | From-scratch GGUF engine driving the GPU via raw ROCr/HSA, hand-written gfx1031 kernels, no HIP | **Yes — targets the 6700 XT directly** | **The real playground piece.** ~23 t/s on Llama-1B Q8_0, author estimates a ~380 t/s memory-bound ceiling, gap is host round-trips. Same lesson as Worm: kill the round-trips. Research toy, not a server |
| [RamenFast/bonsai27b-vulkan](https://github.com/RamenFast/bonsai27b-vulkan) | install/run scripts for Ternary Bonsai-27B (1.71 bpw, 7.17 GB) on a llama.cpp fork via Mesa RADV Vulkan | **Yes — RX 6000 via RADV, tested on 6750 XT** | **Try it.** A 27B that fits 12 GB with room for ~110K context; 25–40 t/s claimed. Easy win on the current card, and a Vulkan/RADV data point for the XTX later |
