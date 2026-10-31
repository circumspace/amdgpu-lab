# benchmark-host bring-up plan

Target host: `benchmark-host`. The card is not yet bought (no purchase recorded as of
2026-10-25).

## Host facts

- Ryzen 5 5600X, MSI B550-A PRO (MS-7C56, BIOS A.I1), bare metal.
- Slot 1: PCIe 4.0 x16 from the CPU. PCI_E3: PCIe 3.0 x4 via chipset, disabled
  when M.2_2 is populated. (The board is **not** "2x PCIe 4.0" — an earlier
  pitch draft got this wrong.)
- OS: Omarchy (Arch), bare metal. SDDM/Hyprland disabled to free VRAM.
- Stack: rootless podman quadlets, llama-swap, Python gateway, `llm-llama`.
- Current GPU: RX 6700 XT Red Devil, 12 GB, run as gfx1030. To be sold, not
  kept as a second card.
- RAM: 64 GiB dual-channel at 3200 MT/s, measured 2026-10-28; see
  [RDNA2 Qwen3.6 results](../rdna2/benchmarks/qwen36.md).
- PSU: unknown, unreadable from software. User must read the label: ≥800 W for
  one 7900 XTX, ~1,000 W for two, 2–3 separate 8-pin cables.

## Before the card arrives

- Read the PSU rating off the label.
- Check case clearance for a 2.5–3.5-slot card up to ~340 mm.

## Bring-up, in order

1. Remove `HSA_OVERRIDE_GFX_VERSION`; try `--n-cpu-moe 0` and measure VRAM
   headroom with the intended context, drafter and number of slots.
2. Baseline on the official ROCm image.
3. A/B ROCm vs Vulkan — RDNA3 is unsettled, and third-party reports conflict
   (victoralcazardev: ROCm 2–3.5× faster; llama.cpp #20934: Vulkan ~20% faster).
4. Test, each on its own A/B: a pinned rdna-boosts release; SelfRef FP4
   (optional); ExLlamaV3 + TabbyAPI; The-Monk rock8 (HIP Bonsai low-bit, gfx1100)
   if a Bonsai-class model is still of interest.
5. Tune `-ub 2048`, draft depth, KV q8/q4, reasoning-effort medium + budget.
6. Check `power1_cap`: the card reportedly defaults to 291 W, not 355 W, on
   Linux.
7. Check whether the official image sets `GGML_HIP_ROCWMMA_FATTN`.
8. Quality checks: recall, mini50, SWE-bench-Live tasks or private PR replays.

## Target model

Qwen3.8-27B. Prefer a heretic GGUF that keeps the MTP layer (HauhauCS or cygnal)
at Q5_K_M/Q6_K; ThinkingCap-Qwen3.8-27B (RCO 4.2bpw) is an alternative. Compact
around 90K.

Production on the 6700 XT uses upstream llama.cpp (`draft-dspark,ngram-mod`,
`n-max 256`). Compare it against the candidate configurations on the XTX.
