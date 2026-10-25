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

## Firmware and scheduling

| Project | What it is | Verdict |
|---|---|---|
| tinygrad Worm | Persistent GPU scheduler, all 96 CUs | The direction. See [../notes/worm.md](../notes/worm.md) |
| PSP reimplementation | Run our own code on the Platform Security Processor | Long bet; precondition for replacing any on-card firmware. See [../notes/firmware.md](../notes/firmware.md) |
| Zagitta/gpu-unlock | Firmware unlock | Doesn't apply: 7900 XTX and W7900 share ~123 TFLOPS FP16; only the power cap matters |
