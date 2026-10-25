# benchmark-host — current host (RX 6700 XT, RDNA2)

The LLM host today. The 6700 XT is to be sold once the 7900 XTX lands; the host
itself stays. Bring-up for the new card is in
[../../rdna3/bringup.md](../../rdna3/bringup.md).

- **GPU:** PowerColor RX 6700 XT Red Devil, 12 GB (12,272 MiB), Navi 22, gfx1031
  run as gfx1030 via `HSA_OVERRIDE_GFX_VERSION=10.3.0`, 186 W cap.
- **CPU / board:** Ryzen 5 5600X, MSI B550-A PRO (MS-7C56, BIOS A.I1), bare metal.
- **PCIe:** slot 1 PCIe 4.0 x16 from the CPU; PCI_E3 is PCIe 3.0 x4 via chipset,
  disabled when M.2_2 is populated. (Not "2× PCIe 4.0".)
- **RAM:** 1× 32 GB DDR4 ECC (single channel, 2933). A second 32 GB stick bought
  2026-10-24; dual channel + 3200 planned at next reboot, not confirmed done.
- **Storage:** Samsung PM981 NVMe (PCIe 3.0 x4), M.2_1. ~264 GB free.
- **OS:** Omarchy (Arch), kernel 7.2.5, bare metal. SDDM/Hyprland disabled to
  free VRAM. Governor `performance`, THP `always`, Resizable BAR off.
- **Graphics stack:** Mesa + vulkan-radeon 26.2.5 (RADV). `/dev/dri/renderD128`
  for Vulkan; `/dev/kfd` for ROCm.
- **LLM stack:** rootless podman quadlets as user `local-user` — `llm-llama` (llama-swap
  + llama.cpp ROCm), `llm-gateway`, `llm-health`. GPU via `AddDevice=/dev/dri`
  + `/dev/kfd`, models mounted read-only.
- **Power control:** `power_dpm_force_performance_level` is root-only; forcing it
  high had no measurable effect on Bonsai decode.
