#!/bin/bash
# Usage: run.sh
# The SWE-bench-Live MultiLang slice in tasks.jsonl, solved by mini-swe-agent on each llama-swap
# image in $ARMS at 64k context and graded with SWE-bench-Live's harness. Every task is checked
# with its reference patch first. Production is stopped for the whole run and restarted on exit.
set -u
HERE=$(cd "$(dirname "$0")" && pwd)
B=$HOME/llm/eval/llm-bench
set -a; . "$B/llm-bench.env"; set +a
. "$B/common.sh"
OUT=$RESULTS/swelive-$(date +%Y%m%d-%H%M)
mkdir -p "$OUT" "$HERE/ds"
cp "$HERE/tasks.jsonl" "$HERE/ds/test.jsonl"
export DOCKER_HOST=unix://$XDG_RUNTIME_DIR/podman/podman.sock
MINI=$HOME/llm/eval/swebench/.venv/bin/mini-extra
GRADE=$HERE/.venv/bin/python
: "${ARMS:=upstream=localhost/llm-swap:262-b11804 r126=localhost/llm-swap-rdna:262-r126,GGML_HIP_FA_BAND_FETCH_AHEAD=0,LLAMA_SPEC_NGRAM_MOD_BAND_CLAMP=0}"
PORT=${LLAMA_SWAP##*:}

cleanup() {
  podman rm -f llm-ab >/dev/null 2>&1
  systemctl --user start "$SWAP_UNIT"
  load "$MODEL" && log "production restored" || log "WARNING: production did not come back"
}
trap cleanup EXIT
trap 'exit 1' INT TERM HUP

grade() {
  (cd "$HERE/harness" && "$GRADE" -m evaluation.evaluation --dataset "$HERE/tasks.jsonl" --platform linux \
    --patch_dir "$1" --output_dir "$2" --workers 1 --overwrite 0) >> "$OUT/grade.log" 2>&1
}

wait_idle "${IDLE_MINUTES:-10}"
systemctl --user stop "$SWAP_UNIT"
log "production stopped; checking reference patches"
grade gold "$OUT/gold"
log "reference check done"

gpu_env=(); for e in $GPU_ENV; do gpu_env+=(-e "$e"); done
for spec in $ARMS; do
  label=${spec%%=*}; rest=${spec#*=}; img=${rest%%,*}
  extra=(); IFS=, read -ra kv <<< "${rest#"$img"}"; for e in "${kv[@]}"; do [ -n "$e" ] && extra+=(-e "$e"); done
  mkdir -p "$OUT/cfg-$label" "$OUT/$label"
  sed "s/-c 131072 /-c 65536 /" "$LLAMA_SWAP_CONFIG" > "$OUT/cfg-$label/config.yaml"
  podman rm -f llm-ab >/dev/null 2>&1
  podman run -d --name llm-ab --device /dev/dri --device /dev/kfd "${gpu_env[@]}" "${extra[@]}" --ulimit memlock=-1:-1 \
    -p "127.0.0.1:$PORT:8080" -v "$MODELS_DIR:/models:ro,z" -v "$OUT/cfg-$label:/config:ro,z" "$img" >/dev/null
  if ! load "$MODEL"; then log "$label did not load"; podman logs --tail 30 llm-ab > "$OUT/$label/load.log" 2>&1; continue; fi
  log "$label loaded, VRAM $(vram)/$(vram_total) MiB"
  printf 'model:\n  model_name: openai/%s\n  model_kwargs:\n    api_base: %s/v1\n' "$MODEL" "$LLAMA_SWAP" > "$OUT/$label/endpoint.yaml"
  peak=$(vram)
  (cd "$B/swebench" && "$MINI" swebench --subset "$HERE/ds" --split test -w 1 -o "$OUT/$label" \
    -c swebench.yaml -c local.yaml -c "$OUT/$label/endpoint.yaml") > "$OUT/$label/agent.log" 2>&1 &
  pid=$!
  while kill -0 $pid 2>/dev/null; do v=$(vram); [ "$v" -gt "$peak" ] && peak=$v; sleep 1; done
  log "$label agent done, peak VRAM $peak/$(vram_total) MiB"
  podman rm -f llm-ab >/dev/null 2>&1
done

for spec in $ARMS; do
  label=${spec%%=*}
  [ -s "$OUT/$label/preds.json" ] || { log "$label has no predictions"; continue; }
  log "grading $label"
  grade "$OUT/$label/preds.json" "$OUT/grade-$label"
done
log "SWELIVE DONE"
