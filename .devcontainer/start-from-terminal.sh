#!/bin/bash
# Script para arrancar el devcontainer desde terminal (sin VS Code)

# Determinar ruta absoluta del script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$SCRIPT_DIR"

CONTAINER_NAME="llm-setup-dev"
VOLUME_NAME="llm-models"
IMAGE_NAME="llm-setup-dev"

# El Dockerfile está dentro de .devcontainer/
DOCKERFILE_PATH="$PROJECT_ROOT/Dockerfile"

echo "🐳 LLM-Setup DevContainer"
echo "========================"
echo "📍 Script location: $SCRIPT_DIR"
echo "📍 Project root: $PROJECT_ROOT"
echo "📍 Dockerfile: $DOCKERFILE_PATH"
echo ""

# Verificar si Docker está disponible
if ! command -v docker &> /dev/null; then
    echo "❌ Error: Docker no está instalado o no está en PATH"
    exit 1
fi

# Verificar Dockerfile existe
if [ ! -f "$DOCKERFILE_PATH" ]; then
    echo "❌ Error: No se encontró Dockerfile en: $DOCKERFILE_PATH"
    exit 1
fi

# Verificar si el volumen existe
if docker volume ls | grep -q "$VOLUME_NAME"; then
    echo "✅ Volumen '$VOLUME_NAME' ya existe (~13 GB de modelos)"
else
    echo "⚠️  Creando volumen para modelos..."
    docker volume create $VOLUME_NAME || {
        echo "❌ Error creando el volumen"
        exit 1
    }
fi

# Construir la imagen si no existe
echo "🔨 Verificando imagen Docker..."
if ! docker images | grep -q "$IMAGE_NAME"; then
    echo "📦 Construyendo imagen Docker desde '$DOCKERFILE_PATH'..."
    if ! docker build -t "$IMAGE_NAME" -f "$DOCKERFILE_PATH" "$PROJECT_ROOT"; then
        echo "❌ Error construyendo la imagen Docker"
        exit 1
    fi
    echo "✅ Imagen construida"
else
    echo "✅ Imagen ya existe"
fi

# Verificar si el contenedor está corriendo
if docker ps --format '{{.Names}}' | grep -q "^$CONTAINER_NAME$"; then
    echo "✅ Contenedor ya está corriendo"
    echo ""
    echo "📊 Estado:"
    docker stats --no-stream "$CONTAINER_NAME" --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}"
    echo ""
    echo "📋 Ver logs: docker logs -f $CONTAINER_NAME"
    exit 0
fi

# Verificar si el contenedor existe (podría estar detenido)
if docker ps -a --format '{{.Names}}' | grep -q "^$CONTAINER_NAME$"; then
    echo "⚠️  Contenedor existe pero no está corriendo. Reiniciando..."
    docker rm $CONTAINER_NAME 2>/dev/null || true
fi

# Arrancar el contenedor
echo ""
echo "🚀 Arrancando contenedor..."
echo "   Nombre: $CONTAINER_NAME"
echo "   Puerto: 9931 (llama-server)"
echo ""

if ! docker run -d \
    --name "$CONTAINER_NAME" \
    --gpus all \
    -v "$VOLUME_NAME":/models \
    -p 9931:9931 \
    -e HF_TOKEN="${HF_TOKEN:-}" \
    "$IMAGE_NAME"; then
    
    echo "❌ Error arrancando el contenedor"
    exit 1
fi

echo "✅ Contenedor arrancado!"
echo ""
echo "📊 Estado del contenedor:"
docker ps

echo ""
echo "📋 Acciones disponibles:"
echo "   - Ver logs: docker logs -f $CONTAINER_NAME"
echo "   - Detener: docker stop $CONTAINER_NAME"
echo "   - Reiniciar: docker restart $CONTAINER_NAME"
echo "   - Eliminar: docker rm $CONTAINER_NAME"
echo "   - Acceder a bash: docker exec -it $CONTAINER_NAME bash"
echo ""
echo "🔗 Acceder a la API:"
echo "   - curl localhost:9931/models"
echo "   - curl localhost:9931/v1/chat/completions (requiere autenticación)"
echo ""
echo "📝 Acceder a pi (desde dentro del contenedor):"
echo "   docker exec -it $CONTAINER_NAME bash"
echo "   Dentro: pi"
echo ""
echo "🎯 Modelos disponibles:"
echo "   - Gemma 4 12B it Q4_K_M"
echo "   - Qwen3.5 9B Q4_K_M"
echo ""
echo "💡 Para usar pi, abre una nueva terminal y ejecuta:"
echo "   docker exec -it $CONTAINER_NAME pi"
echo ""
