# 📖 Guía de Uso - LLM-Setup DevContainer

## 🚀 Comandos Básicos

### Arrancar el contenedor
```bash
./devcontainer/start-from-terminal.sh
```

### Acceder a pi
```bash
docker exec -it llm-setup-dev pi
```

### Detener el contenedor
```bash
./devcontainer/stop-container.sh
```

## ⏸️ ¿Qué pasa si dejo de usarlo?

### ❌ El contenedor NO se detiene solo
**Importante:** El contenedor sigue corriendo en segundo plano hasta que tú lo detengas manualmente. Esto significa:

- ✅ El modelo sigue en VRAM
- ✅ Consume ~2-7 GB de RAM
- ✅ Consume ~6-15% de CPU
- ✅ El puerto 9931 sigue abierto
- ⚠️ **Consumo continuo de recursos**

### 🔒 ¿Qué pasa con los modelos?

Los modelos se guardan en un **volumen Docker persistente** llamado `llm-models`. Esto significa:

| Situación | ¿Se borran los modelos? |
|-----------|------------------------|
| Detener contenedor | ❌ NO |
| Reiniciar contenedor | ❌ NO |
| Eliminar contenedor | ❌ NO |
| Eliminar volumen | ✅ SÍ |

**Tu volumen `llm-models` (~13 GB) se conserva siempre que no lo elimines manualmente.**

## 🧹 Opciones de Limpieza

### 1️⃣ Detener temporalmente (recomendado)
```bash
./devcontainer/stop-container.sh
```
- ✅ El contenedor se detiene
- ⚠️ Los modelos siguen en el volumen
- ✅ Puedes volver a arrancar cuando quieras

### 2️⃣ Limpieza completa (borra todo)
```bash
./devcontainer/cleanup.sh --all
```
- ✅ Elimina el contenedor
- ✅ Elimina el volumen **y todos los modelos (~13 GB)**
- ⚠️ ¡Cuidado! No se pueden recuperar

### 3️⃣ Solo detener contenedor
```bash
docker stop llm-setup-dev
docker rm llm-setup-dev
```
- ✅ Contenedor eliminado
- ⚠️ Volumen con modelos intacto

## 📊 Monitorizar el estado

### Ver si el contenedor está corriendo
```bash
docker ps  # Solo los activos
docker ps -a  # Todos (activos y detenidos)
```

### Ver uso de recursos
```bash
docker stats llm-setup-dev
```

### Ver tamaño del volumen
```bash
docker volume inspect llm-models --format '{{.Size}}'
```

## 💡 Buenas prácticas

### ✅ Si quieres cerrar sesión pero conservar todo:
```bash
# Detener el contenedor
./devcontainer/stop-container.sh

# O detener desde terminal
docker stop llm-setup-dev
```
- Los modelos siguen en el volumen
- Cuando vuelvas, arranca de nuevo

### ✅ Si quieres liberar espacio:
```bash
# Detener contenedor
./devcontainer/stop-container.sh

# Eliminar volumen (¡borra los modelos!)
docker volume rm llm-models
```
- Liberará ~13 GB de espacio
- Necesitarás descargar modelos de nuevo

### ✅ Si quieres dejar el contenedor corriendo:
- ¡Deja que siga activo!
- Los modelos ya están listos para usar
- Solo consume recursos mientras esté activo

## 🔄 Volver a usarlo después de detener

```bash
# Si solo detuviste el contenedor
./devcontainer/start-from-terminal.sh

# Si eliminaste el volumen, necesitas:
docker volume create llm-models
./devcontainer/start-from-terminal.sh
```

## 📝 Resumen rápido

| Acción | Comando | ¿Se borran modelos? |
|--------|---------|---------------------|
| Detener | `./devcontainer/stop-container.sh` | ❌ No |
| Arrancar | `./devcontainer/start-from-terminal.sh` | ❌ No |
| Detener contenedor | `docker stop llm-setup-dev` | ❌ No |
| Eliminar volumen | `docker volume rm llm-models` | ✅ SÍ |
| Limpieza completa | `./devcontainer/cleanup.sh --all` | ✅ SÍ |

## 🆘 ¿Necesitas ayuda?

```bash
./devcontainer/help.sh
```

---

**Para más información, ver [`README.md`](../README.md)**
