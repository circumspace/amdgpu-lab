# Open questions

- **Card purchase.** None recorded as of 2026-10-25. Target one used 7900 XTX,
  €800–900. A second only if wanted later (gives two models or two concurrent
  requests, not single-request speed).
- **PSU rating and case clearance.** Must be read off the hardware.
- **ROCm vs Vulkan on gfx1100.** Third-party evidence conflicts; settle it by
  measuring on the card.
- **Do rdna-boosts WMMA paths win on RDNA3?** RDNA2 rejections do not carry
  over; needs its own A/B.
- **Why do r126's llama-bench gains vanish in the server?**
- **Did the RAM upgrade and the r123 A/B run?** Unconfirmed.

## Pending stew r123 A/B — likely stale, verify before running

From memory and stew675#214 (closed). The procedure assumed r123; since then
r126 was tested and rejected, `mkp224o` was stopped and removed (PR #315), and
r126 needs `LLAMA_SPEC_NGRAM_MOD_BAND_CLAMP=0`. Re-scope before spending time.

Original steps:
1. Confirm 2/4 memory slots populated.
2. Use a ghcr `server-rocm-7.14.1` image built after 2026-10-24T10:25Z (the
   08:30Z build is r122-era). Pin by digest in a copy of
   `~/llm/swap/Containerfile.rdna`; build `localhost/llm-swap-rdna:262-r123`.
3. From `~/llm/eval/llm-bench`, with `llm-bench.env` sourced, as a
   `systemd-run --user` unit:
   `IDLE_MINUTES=0 PAUSE=mkp224o IMG=localhost/llm-swap-rdna:262-r123 VARIANTS="same ngram-auto arena-ncmoe30 arena-ncmoe34" ./speed/abtest.sh $HOME/llm/gateway/app.py`
4. Report decode, edit and deep-context numbers plus the `moe_cache_report`
   lines (arena MiB, `h=`, expert traffic per token). If no arena starts, lower
   `GGML_CUDA_SLAB_RESERVE_MIB`.

Also scheduled: a SWE-bench-Live run (6 languages, upstream vs r126, 64K) for
2026-10-26 01:00, results to `~/llm/eval/results/swelive-<date>/`.
