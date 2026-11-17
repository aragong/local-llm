#!/usr/bin/env sh
# sd-server (stable-diffusion.cpp): Web UI + API de imágenes en :7860 con FLUX.2 klein 4B precargado.
# --offload-to-cpu: pesos en RAM, solo suben a la GPU al generar → en reposo no ocupa VRAM y convive con Qwen.
# Espera a los modelos: en el primer arranque download-models.sh aún no los ha bajado y sd-server saldría con error.
S=/models/sd
DIT=$S/diffusion_models/flux-2-klein-4b-Q6_K.gguf
LLM=$S/text_encoders/Qwen3-4B-Q6_K.gguf
VAE=$S/vae/flux2-vae.safetensors

until [ -f "$DIT" ] && [ -f "$LLM" ] && [ -f "$VAE" ]; do sleep 10; done
exec sd-server --model-dir "$S" --listen-ip 0.0.0.0 --listen-port 7860 --offload-to-cpu \
    --diffusion-model "$DIT" --llm "$LLM" --vae "$VAE" --cfg-scale 1.0 --steps 4
