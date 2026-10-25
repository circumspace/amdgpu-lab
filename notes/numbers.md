# Measured and quoted numbers

tok/s, single user, unless noted.

## 7900 XTX (third-party and estimates — none measured by us)

| Model / quant | Setup | Decode | Prefill | Source |
|---|---|---|---|---|
| Qwen3.8-27B, SelfRef FP4, MTP, 131k ctx | SelfRef Vulkan fork | 74 prose / 106 JSON / 130 code | 868 @32k | fork author |
| Qwen3.8-27B, Q4_K_M | near-stock llama.cpp | ~55 | – | our estimate from SelfRef's +33–38% claim |
| Qwen3.6-27B IQ4_XS, 16K, no spec | salvatoretrimarchi build | 41.7 | 1,076 | repo |
| Qwen3.8-27B EXL3 4.0bpw, MTP d3, 128K, 8-bit cache | ExLlamaV3 ROCm + TabbyAPI | 82.9 (81–92; 86.1 @d3) | ~935; 106K prompt in 113.5s | registry PR #329, peak 21,134 MiB |
| Qwen3.6-27B dense | ROCm | ~25 fresh, 15 @90k | – | XDA (Vulkan ~30% faster) |
| Qwen3.6-35B-A3B | ROCm / Vulkan | 56–78 / 67–105 | – | TurboLLM, llama.cpp #10879 |
| Qwen3.6-35B-A3B | ROCm + MTP | ~130 | – | one report |

Our Qwen3.6-35B-A3B-fully-on-XTX estimates vary by session (60–130); low confidence.

Reference, RTX 3090 + HyperQwen, Qwen3.8-27B: 127 decode, 95–100 @150k, 381 edits, ~1,440 prefill (250 W).

## Measured by us — RX 6700 XT (RDNA2), for baseline context

Production: Qwen3.6-35B-A3B heretic MTP IQ4_XS, `--n-cpu-moe 24`, upstream b11804 ROCm.

| Test | tok/s |
|---|---|
| Prompt read, 3.8k / 117k | 979 / 443 |
| Write, short / 117k | 28.2 / 21.4 |
| File rewrite | 173–183 |
| Fresh code | ~44 |

- **ROCm vs Vulkan (2026-10-11, RDNA2):** ROCm read 2.2× faster, generated +57%. (Only in transcript e4ee00ec; a later session wrongly thought no Vulkan test had run.)
- **rdna-boosts r120:** generation ~even; 117k read −19%; VRAM floor 66 MB. Rejected.
- **rdna-boosts r126 (llama-bench, fetch-ahead off):** +38% @d0, +30–37% to 24K, −1% @80K, −10% @120K. But **in the real server**: read −5% @3.8K / −16% @117K, generation −3–5%, only rewrites gained. With the band clamp on, the r123 bug makes rewrites 16–23% slower than upstream. **Rejected for benchmark-host.**
- **Adaptive MTP PR #27210:** +6–10% fresh code, 81% draft acceptance; without ngram-mod rewrites collapse to 48. Rejected.
- **ngram-mod with experts in RAM:** −3–7% fresh code, ~3× faster rewrites. Kept.

Note: these are RDNA2 results. RDNA3's WMMA paths are untested and must get their own A/B — RDNA2 rejections do not carry over.

### bonsai27b, measured on the 6700 XT (2026-10-25)

Ternary-Bonsai-27B Q2_0 (6.66 GiB, dense 27B, all layers on GPU), PrismML fork
62061f91, Vulkan/RADV, `llama-bench -ngl 99 -fa 1 -r 3`. Container:
`localhost/bonsai-vulkan`, `--device /dev/dri`. Production stopped for the run.

| test | t/s |
|---|---|
| pp512 | 164.96 |
| pp2048 | 155.23 |
| tg128 @ d0 | 13.78 |
| pp512 @ d8192 | 134.92 |
| pp2048 @ d8192 | 133.45 |
| tg128 @ d8192 | 21.12 |

RADV reports NAVI22, fp16 yes, no matrix cores (expected for RDNA2).

Reads:
- **The whole dense 27B fits in 6.66 GiB** with no CPU offload — the opposite of
  the production MoE, which spills experts to RAM. Leaves ~5 GiB for context.
- The 21.12 at d8192 was a first-run warmup artifact, not a trend; steady decode
  is ~14 t/s (see the 30-min sweep).

### 30-min sweep, 6700 XT (2026-10-25)

Clock pinned high (`power_dpm_force_performance_level=high`), q8_0 KV for depth.

| phase | result |
|---|---|
| decode @ high power, d0 | tg128 **13.78** — identical to auto power |
| prefill, d0 | pp512 163.8 |
| decode @ 32K / 64K | tg64 15.6 / 13.75 |
| prefill @ 32K / 64K | pp512 105 / 77 |
| 110K context fit (q8_0 KV) | **loads, 10.91 GiB VRAM** |
| DSpark drafter | not measured — fork renamed `--draft-max` to `--spec-draft-n-max`; retry pending |

Corrected reads:
- **Clock-sag was the wrong diagnosis.** Forcing the card high left decode at
  13.78, unchanged. Steady decode is ~14 t/s regardless of power state or depth.
- **Decode barely feels depth** (13.75 at 64K), matching prism's claim. Prefill
  degrades with depth as expected.
- **110K context fits fully on-GPU** at 10.91/12 GiB with q8_0 KV — the repo's
  claim holds on a 6700 XT.
- Decode (~14 t/s) is well below the production MoE's 28–44 t/s. The DSpark
  drafter is the remaining lever, and prism's own ledger warns its Q2_0+Vulkan
  pairing is unproven. Restore power with `…=auto` after testing.
