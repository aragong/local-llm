#!/usr/bin/env bash
# Descarga los GGUF a /models (volumen). Idempotente: salta los ya presentes, reanuda parciales.
set -euo pipefail

DEST=${MODELS_DIR:-/models}
MODELS=(
  "unsloth/Qwen3.5-9B-GGUF Qwen3.5-9B-Q4_K_M.gguf"                                  # ~5.7 GB
  "unsloth/DeepSeek-R1-Distill-Qwen-14B-GGUF DeepSeek-R1-Distill-Qwen-14B-Q4_K_M.gguf"  # ~9.0 GB
)

auth=()
[[ -n "${HF_TOKEN:-}" ]] && auth=(-H "Authorization: Bearer ${HF_TOKEN}")

for entry in "${MODELS[@]}"; do
  read -r repo file <<<"$entry"
  if [[ -f "$DEST/$file" ]]; then
    echo "ok   $file"
    continue
  fi
  echo "get  $repo/$file"
  curl -fL --retry 3 -C - "${auth[@]}" -o "$DEST/$file.part" \
    "https://huggingface.co/$repo/resolve/main/$file"
  mv "$DEST/$file.part" "$DEST/$file"
done
