#!/usr/bin/env bash
set -uo pipefail
MODEL="$HOME/bonsai27b/models/Ternary-Bonsai-27B-Q2_0.gguf"
IMG="localhost/bonsai-vulkan:62061f910"
log(){ printf '\n== %s == %s\n' "$1" "$(date +%H:%M:%S)"; }

log "wait for image + model"
for _ in $(seq 1 240); do
  have_img=0; podman image exists "$IMG" && have_img=1
  sz=$(stat -c%s "$MODEL" 2>/dev/null || echo 0)
  dl=0; pgrep -f "curl.*Bonsai" >/dev/null && dl=1
  if [ "$have_img" = 1 ] && [ "$dl" = 0 ] && [ "$sz" -ge 6600000000 ]; then
    echo "ready: image yes, model $sz bytes"; break
  fi
  echo "waiting… img=$have_img dl=$dl size=$sz"; sleep 10
done
podman image exists "$IMG" || { echo "ABORT: image never built; leaving production up"; exit 1; }
[ "$(stat -c%s "$MODEL" 2>/dev/null || echo 0)" -ge 6600000000 ] || { echo "ABORT: model incomplete; leaving production up"; exit 1; }

log "stop production (llm-llama)"
systemctl --user stop llm-llama
restart_prod(){ log "restart production"; systemctl --user start llm-llama; sleep 3; systemctl --user is-active llm-llama; }
trap restart_prod EXIT
sleep 3
echo "VRAM used after stop:"; cat /sys/class/drm/card*/device/mem_info_vram_used 2>/dev/null | head -1 | awk "{printf \"%.2f GiB\n\", \$1/1073741824}"

log "sweep: llama-bench (Vulkan/RADV)"
podman run --rm --device /dev/dri --group-add keep-groups \
  -v "$MODEL":/model.gguf:ro "$IMG" \
  -m /model.gguf -ngl 99 -fa 1 -p 512,2048 -n 128 -d 0,8192 -r 3 2>&1

log "sweep done"
