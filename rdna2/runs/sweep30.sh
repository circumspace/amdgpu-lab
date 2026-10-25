#!/usr/bin/env bash
set -uo pipefail
MODEL="$HOME/bonsai27b/models/Ternary-Bonsai-27B-Q2_0.gguf"
DRAFT="$HOME/bonsai27b/models/Ternary-Bonsai-27B-dspark-Q4_1.gguf"
IMG="localhost/bonsai-vulkan:62061f910"
PNODE="$(ls /sys/class/drm/card*/device/power_dpm_force_performance_level 2>/dev/null | head -1)"
VRAM="$(ls /sys/class/drm/card*/device/mem_info_vram_used 2>/dev/null | head -1)"
PORT=18200
log(){ printf '\n== %s == %s\n' "$1" "$(date +%H:%M:%S)"; }
vram(){ awk '{printf "%.2f GiB", $1/1073741824}' "$VRAM" 2>/dev/null; }

log "wait for drafter + model"
for _ in $(seq 1 60); do
  [ -s "$DRAFT" ] && ! pgrep -f "dspark-Q4_1" >/dev/null && [ "$(stat -c%s "$DRAFT")" -ge 1900000000 ] && break
  echo "waiting drafter: $(stat -c%s "$DRAFT" 2>/dev/null || echo 0)"; sleep 10
done
[ -s "$MODEL" ] || { echo "ABORT: model missing"; exit 1; }

log "power state"
POW="unforced(auto)"
for _ in $(seq 1 18); do
  cur="$(cat "$PNODE" 2>/dev/null)"
  [ "$cur" = high ] && { POW="forced-high"; break; }
  echo "power=$cur, waiting for 'high' (run the sudo command)…"; sleep 10
done
echo "power: $POW ($(cat "$PNODE" 2>/dev/null))"

log "stop production"
systemctl --user stop llm-llama
trap 'printf "\n== restart production ==\n"; systemctl --user start llm-llama; sleep 3; systemctl --user is-active llm-llama' EXIT
sleep 3; echo "VRAM after stop: $(vram)"

DEV=(--device /dev/dri --group-add keep-groups)
log "PHASE 1 — decode @ high power (llama-bench, no draft)"
timeout 300 podman run --rm "${DEV[@]}" -v "$MODEL":/m.gguf:ro "$IMG" \
  -m /m.gguf -ngl 99 -fa 1 -p 512 -n 128 -d 0 -r 3 2>&1 | grep -E "tg128|pp512|model|---"

log "PHASE 2 — speculative decode (llama-server + DSpark drafter)"
podman rm -f bsrv >/dev/null 2>&1
timeout 600 podman run -d --name bsrv "${DEV[@]}" \
  -v "$MODEL":/m.gguf:ro -v "$DRAFT":/d.gguf:ro -p 127.0.0.1:$PORT:8080 \
  --entrypoint /usr/local/bin/llama-server "$IMG" \
  -m /m.gguf -md /d.gguf -ngl 99 -ngld 99 -fa 1 -c 8192 \
  --draft-max 16 --draft-min 0 --host 0.0.0.0 --port 8080 >/dev/null
ok=0; for _ in $(seq 1 40); do sleep 3; curl -s -m 2 http://127.0.0.1:$PORT/health 2>/dev/null | grep -q ok && { ok=1; break; }; done
if [ "$ok" = 1 ]; then
  echo "server up, VRAM (main+draft): $(vram)"
  for PR in "Write a haiku about winter." "Refactor this to use a dict comprehension: result={}\nfor k,v in items:\n  if v>0: result[k]=v*2"; do
    curl -s -m 180 http://127.0.0.1:$PORT/completion -H "Content-Type: application/json" \
      -d "{\"prompt\":$(python3 -c "import json,sys;print(json.dumps(sys.argv[1]))" "$PR"),\"n_predict\":200,\"temperature\":0}" \
      | python3 -c "import json,sys
d=json.load(sys.stdin); t=d.get('timings',{})
print('  decode %.1f t/s | predicted %s | draft_n=%s accepted=%s' % (t.get('predicted_per_second',0), t.get('predicted_n'), t.get('draft_n','?'), t.get('draft_n_accepted','?')))"
  done
  podman logs bsrv 2>&1 | grep -iE "draft acceptance|n_draft|accept" | tail -3
else echo "server never healthy"; podman logs bsrv 2>&1 | tail -8; fi
podman rm -f bsrv >/dev/null 2>&1

log "PHASE 3 — decode vs depth (q8_0 KV, llama-bench)"
timeout 1200 podman run --rm "${DEV[@]}" -v "$MODEL":/m.gguf:ro "$IMG" \
  -m /m.gguf -ngl 99 -fa 1 -ctk q8_0 -ctv q8_0 -p 512 -n 64 -d 32768,65536 -r 1 2>&1 | grep -E "tg|pp|model|---"

log "PHASE 4 — 110K fit check (q8_0 KV)"
podman rm -f bfit >/dev/null 2>&1
timeout 300 podman run -d --name bfit "${DEV[@]}" -v "$MODEL":/m.gguf:ro -p 127.0.0.1:$PORT:8080 \
  --entrypoint /usr/local/bin/llama-server "$IMG" \
  -m /m.gguf -ngl 99 -fa 1 -c 114688 -ctk q8_0 -ctv q8_0 --host 0.0.0.0 --port 8080 >/dev/null
ok=0; for _ in $(seq 1 50); do sleep 3; curl -s -m 2 http://127.0.0.1:$PORT/health 2>/dev/null | grep -q ok && { ok=1; break; }; done
if [ "$ok" = 1 ]; then echo "110K context loaded OK; VRAM: $(vram)"; else echo "110K did NOT fit / load; last log:"; podman logs bfit 2>&1 | tail -6; fi
podman rm -f bfit >/dev/null 2>&1

log "SWEEP30 DONE"
