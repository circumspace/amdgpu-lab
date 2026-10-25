# RDNA3 (7900 XTX) — third-party and estimated numbers

tok/s, single user, unless noted. None measured by us — the card is not in hand.

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
