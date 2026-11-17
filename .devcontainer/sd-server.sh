#!/usr/bin/env sh
# sd-server (stable-diffusion.cpp): Web UI + API de imágenes en :7860 con FLUX.2 klein 4B precargado.
# Rutas del modelo: ENV FLUX_* en el Dockerfile.
# --offload-to-cpu: pesos en RAM, solo suben a la GPU al generar → en reposo no ocupa VRAM y convive con Qwen.
# Espera a los modelos: en el primer arranque download-models.sh aún no los ha bajado y sd-server saldría con error.
until [ -f "$FLUX_DIT" ] && [ -f "$FLUX_LLM" ] && [ -f "$FLUX_VAE" ]; do sleep 10; done
exec sd-server --model-dir /models/sd --listen-ip 0.0.0.0 --listen-port 7860 --offload-to-cpu \
    --diffusion-model "$FLUX_DIT" --llm "$FLUX_LLM" --vae "$FLUX_VAE" --cfg-scale 1.0 --steps 4
