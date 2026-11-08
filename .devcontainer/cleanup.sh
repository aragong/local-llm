#!/bin/bash
# Script para limpiar el entorno (detener contenedor y opcionalmente eliminar volumen)

CONTAINER_NAME="llm-setup-dev"
VOLUME_NAME="llm-models"

echo "🐳 LLM-Setup DevContainer - Limpieza"
echo "======================================"
echo ""

# Detener y eliminar contenedor
if docker ps --format '{{.Names}}' | grep -q "^$CONTAINER_NAME$"; then
    echo "✅ Deteniendo contenedor..."
    docker stop $CONTAINER_NAME
    echo "✅ Eliminando contenedor..."
    docker rm $CONTAINER_NAME
else
    echo "⚠️  El contenedor '$CONTAINER_NAME' no está corriendo"
    exit 1
fi

echo ""
echo "📊 Estado actual:"
echo ""
echo "💾 Volumen '$VOLUME_NAME': "
if docker volume ls | grep -q "$VOLUME_NAME"; then
    echo "   ✅ Volumen EXISTE (con modelos guardados)"
    echo "   📍 Tamaño: $(docker volume inspect $VOLUME_NAME --format '{{.Size}}' 2>/dev/null || echo "Desconocido")"
    echo "   📍 Uso: $(du -sh $VOLUME_NAME 2>/dev/null || echo "No montado")"
    echo ""
    echo "   💡 Para eliminar el volumen (y borrar todos los modelos ~13 GB):"
    echo "      docker volume rm $VOLUME_NAME"
else
    echo "   ⚠️  Volumen NO existe"
fi

echo ""
echo "🎯 Opciones siguientes:"
echo ""
echo "   1. Reiniciar el contenedor:"
echo "      ./devcontainer/start-from-terminal.sh"
echo ""
echo "   2. Eliminar el volumen (borrar modelos ~13 GB):"
echo "      docker volume rm $VOLUME_NAME"
echo ""
echo "   3. Quitar usuario de grupo docker (si añadiste antes):"
echo "      sudo gpasswd -r $USER"
echo ""
echo "   4. Limpiar imagen Docker:"
echo "      docker rmi $IMAGE_NAME"
echo ""
echo "   5. Quitar todo y empezar de cero:"
echo "      ./devcontainer/cleanup.sh --all"
echo ""
echo "📝 Nota: Los modelos se eliminan SOLAMENTE si usas --all"
echo ""
