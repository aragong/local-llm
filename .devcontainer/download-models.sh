#!/usr/bin/env bash
# Descarga los modelos a /models (volumen). Idempotente: salta los ya presentes, reanuda parciales.
# Formato: "<repo HF> <ruta en el repo> [subcarpeta destino]". Se guarda con el nombre base del fichero.
set -euo pipefail

DEST=${MODELS_DIR:-/models}
MODELS=(
  # LLM (llama.cpp)
  "unsloth/Qwen3.5-9B-GGUF Qwen3.5-9B-Q4_K_M.gguf"                                  # ~5.7 GB
  "unsloth/Qwen3.5-35B-A3B-GGUF Qwen3.5-35B-A3B-Q4_K_M.gguf"                        # ~22.0 GB
  # Imagen: FLUX.2 [klein] 4B (stable-diffusion.cpp). sd-server busca por carpetas de categoría.
  "unsloth/FLUX.2-klein-4B-GGUF flux-2-klein-4b-Q6_K.gguf sd/diffusion_models"       # ~3.4 GB
  "unsloth/Qwen3-4B-GGUF Qwen3-4B-Q6_K.gguf sd/text_encoders"                        # ~3.3 GB
  "Comfy-Org/Flux-2-Klein-4B split_files/vae/flux2-vae.safetensors sd/vae"           # ~0.3 GB
)

auth=()
[[ -n "${HF_TOKEN:-}" ]] && auth=(-H "Authorization: Bearer ${HF_TOKEN}")

for entry in "${MODELS[@]}"; do
  read -r repo path subdir <<<"$entry"
  dir="$DEST${subdir:+/$subdir}"
  file="$dir/$(basename "$path")"
  if [[ -f "$file" ]]; then
    echo "ok   ${file#"$DEST"/}"
    continue
  fi
  echo "get  $repo/$path"
  mkdir -p "$dir"
  curl -fL --retry 3 -C - "${auth[@]}" -o "$file.part" \
    "https://huggingface.co/$repo/resolve/main/$path"
  mv "$file.part" "$file"
done
