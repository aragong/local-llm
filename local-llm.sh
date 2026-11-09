#!/usr/bin/env bash
# local-llm - gestiona el contenedor LLM (llama.cpp + pi) desde terminal.
#
# VS Code (devcontainer.json) y este script usan el MISMO contenedor (--name local-llm-dev):
# una sola GPU, un solo llama-server, un solo puerto. Si uno ya lo arrancó, el otro lo reutiliza.
set -euo pipefail

REPO="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
NAME=local-llm-dev
IMAGE=local-llm-dev
VOLUME=llm-models
PORT=${LOCAL_LLM_PORT:-9931}

exists()  { docker container inspect "$NAME" &>/dev/null; }
running() { [[ "$(docker container inspect -f '{{.State.Running}}' "$NAME" 2>/dev/null)" == true ]]; }
origin()  { [[ -n "$(docker container inspect -f '{{index .Config.Labels "devcontainer.local_folder"}}' "$NAME" 2>/dev/null)" ]] && echo "VS Code" || echo "terminal"; }
ask()     { read -r -p "$1 (y/n): " a; [[ "$a" =~ ^[Yy]$ ]]; }

show_help() {
    cat <<EOF
Uso: local-llm <opción>

  --start    Construir imagen (con caché), arrancar contenedor y descargar modelos que falten
  --stop     Detener y eliminar el contenedor (los modelos se conservan en el volumen)
  --restart  Reiniciar el contenedor
  --status   Estado del contenedor, puerto y modelos
  --logs     Seguir el log de llama-server
  --cleanup  Eliminar contenedor y, si confirmas, volumen e imagen
  pi         Abrir pi dentro del contenedor (lo arranca si hace falta)

Puerto del host: 9931 (cambiar con LOCAL_LLM_PORT=9932 local-llm --start)
EOF
}

start() {
    command -v docker >/dev/null || { echo "❌ Docker no está en PATH"; exit 1; }
    if running; then
        echo "✅ '$NAME' ya está corriendo (arrancado desde $(origin))"
        return
    fi
    if exists; then
        # Contenedor parado (p. ej. VS Code al cerrarse): se reutiliza tal cual.
        echo "▶️  Arrancando contenedor existente '$NAME' ($(origin))..."
        docker start "$NAME" >/dev/null
    else
        echo "📦 Construyendo imagen (rápido si no hay cambios)..."
        docker build -t "$IMAGE" -f "$REPO/.devcontainer/Dockerfile" "$REPO"
        docker volume create "$VOLUME" >/dev/null
        echo "🚀 Creando contenedor '$NAME' (localhost:$PORT → 9931)..."
        # llama-server escucha siempre en 9931 dentro del contenedor; solo cambia el puerto del host.
        docker run -d --init --name "$NAME" --gpus all \
            -v "$VOLUME":/models -p "127.0.0.1:$PORT:9931" \
            -e HF_TOKEN="${HF_TOKEN:-}" "$IMAGE" >/dev/null || {
            docker rm "$NAME" &>/dev/null || true
            echo "❌ No se pudo arrancar. ¿Puerto $PORT ocupado? Prueba: LOCAL_LLM_PORT=9932 local-llm --start"
            exit 1
        }
    fi
    echo "⬇️  Comprobando modelos..."
    docker exec "$NAME" download-models.sh
    echo "✅ Listo. pi: local-llm pi · API: $(docker port "$NAME" 9931 2>/dev/null || echo 'sin publicar (VS Code la reenvía)')"
}

stop() {
    exists || { echo "⚠️  '$NAME' no existe"; return; }
    docker rm -f "$NAME" >/dev/null
    echo "✅ Contenedor eliminado. Modelos conservados en el volumen '$VOLUME'."
}

status() {
    if running; then
        echo "🟢 '$NAME' corriendo (arrancado desde $(origin))"
        echo "   API host: $(docker port "$NAME" 9931 2>/dev/null || echo 'sin publicar (VS Code la reenvía)')"
        docker stats --no-stream --format '   CPU {{.CPUPerc}} · RAM {{.MemUsage}}' "$NAME"
        docker exec "$NAME" sh -c 'ls -lh /models/*.gguf 2>/dev/null | awk "{print \"   \" \$5, \$9}"; du -sh /models | sed "s/^/   total /"'
    elif exists; then
        echo "⏸️  '$NAME' detenido (creado desde $(origin))"
    else
        echo "🔴 '$NAME' no existe"
    fi
    docker volume inspect "$VOLUME" &>/dev/null && echo "💾 Volumen '$VOLUME': existe" || echo "💾 Volumen '$VOLUME': no existe"
}

logs() {
    running || { echo "⚠️  '$NAME' no está corriendo"; exit 1; }
    docker exec "$NAME" tail -n 50 -f /tmp/llama-server.log
}

cleanup() {
    stop
    if docker volume inspect "$VOLUME" &>/dev/null && ask "¿Eliminar volumen '$VOLUME' y borrar modelos?"; then
        docker volume rm "$VOLUME" >/dev/null && echo "✅ Volumen eliminado"
    fi
    if docker image inspect "$IMAGE" &>/dev/null && ask "¿Eliminar imagen '$IMAGE' (~4 GB, recompilar tarda 10-20 min)?"; then
        docker rmi "$IMAGE" >/dev/null && echo "✅ Imagen eliminada"
    fi
}

case "${1:-}" in
    --start)   start ;;
    --stop)    stop ;;
    --restart) running && docker restart "$NAME" >/dev/null && echo "✅ Reiniciado" || start ;;
    --status)  status ;;
    --logs)    logs ;;
    --cleanup) cleanup ;;
    pi)        running || start; docker exec -it "$NAME" pi ;;
    --help|-h) show_help ;;
    *)         show_help; exit 1 ;;
esac
