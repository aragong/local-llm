# llm-setup

Devcontainer con [llama.cpp](https://github.com/ggml-org/llama.cpp) (compilado con CUDA para Blackwell / RTX 50xx) + [pi](https://pi.dev) y dos modelos locales:

| Modelo | Fichero | Tamaño |
|---|---|---|
| Gemma 4 12B it Q4_K_M | `unsloth/gemma-4-12b-it-GGUF` / `gemma-4-12b-it-Q4_K_M.gguf` | ~7.1 GB |
| Qwen3.5 9B Q4_K_M | `unsloth/Qwen3.5-9B-GGUF` / `Qwen3.5-9B-Q4_K_M.gguf` | ~5.7 GB |

Usuario del contenedor: `oceanos`.

---

## Recursos utilizados

- **[llama.cpp](https://github.com/ggml-org/llama.cpp)** - Implementación en C para ejecutar modelos LLM de forma eficiente
- **[pi](https://pi.dev)** - Asistente de codificación y razonamiento con IA local
- **[Gemma 4 12B](https://huggingface.co/google/gemma-4-12b-it)** - Modelo de lenguaje de Google
- **[Qwen3.5 9B](https://huggingface.co/Qwen/Qwen3.5-9B)** - Modelo de lenguaje de Alibaba Cloud

## Requisitos

- GPU NVIDIA (probado: RTX 5070 Ti 16 GB) con driver reciente.
- Docker con soporte GPU (Docker Desktop + WSL2, o Docker Engine + `nvidia-container-toolkit`).
- VS Code + extensión Dev Containers (o `devcontainer` CLI).

## Uso

1. Abrir el repo en VS Code → `F1` → **Dev Containers: Reopen in Container**.
   - Primera vez: compila llama.cpp (~10-20 min) y descarga modelos (~13 GB) al volumen `llm-models`.
2. `llama-server` se levanta solo como proceso principal del contenedor (router, puerto `9931`, log `/tmp/llama-server.log`).
   Tras cambiar algo en `.devcontainer/`: `F1` → **Dev Containers: Rebuild Container**.
3. Abrir una terminal en VS Code (`` Ctrl+` ``) y ejecutar:

   ```bash
   pi
   ```

   Arranca con `qwen3.5-9b` seleccionado. Escribir el prompt y `Enter`.

### Cambiar de modelo en pi

---

| Acción | Cómo |
|---|---|
| Elegir modelo de una lista | `/model` (o `Ctrl+L`) → elegir `gemma-4-12b` / `qwen3.5-9b` |
| Alternar entre los dos | `Ctrl+P` |
| Guardar el elegido como inicial | `Ctrl+S` dentro de `/model` |
| Nivel de razonamiento (thinking) | `Shift+Tab` |
| Salir | `Ctrl+C` dos veces |

Solo un modelo cabe en VRAM a la vez: al cambiar, el primer mensaje tarda unos segundos mientras el router descarga uno y carga el otro.

Arrancar pi directamente con un modelo: `pi --model llama-cpp/gemma-4-12b`.

---

## 🐳 Uso desde Terminal (sin VS Code)

Si prefieres no usar VS Code, puedes arrancar el contenedor directamente desde una terminal de Ubuntu:

### 1️⃣ Arrancar el contenedor

```bash
cd /ruta/al/repo
chmod +x .devcontainer/start-from-terminal.sh
./devcontainer/start-from-terminal.sh
```

**⚠️ IMPORTANTE:** La carpeta de configuración es `.devcontainer` (con el punto). El script la busca correctamente desde la raíz del proyecto.

### 2️⃣ Acceder a pi

```bash
docker exec -it llm-setup-dev pi
```

O primero entrar al bash y luego ejecutar:
```bash
docker exec -it llm-setup-dev bash
pi
```

Esto hará:
- ✅ Verificar Docker y GPU
- ✅ Crear el volumen para modelos (si no existe)
- ✅ Construir la imagen Docker (primera vez, ~10-20 min)
- ✅ Descargar los modelos (~13 GB al volumen `llm-models`)
- ✅ Arrancar el contenedor con `llama-server` corriendo

### 2️⃣ Acceder a pi

```bash
docker exec -it llm-setup-dev bash
pi
```

O directamente:
```bash
docker exec -it llm-setup-dev pi
```

### 3️⃣ Ver estado y logs

```bash
docker ps                    # Ver contenedor corriendo
docker logs -f llm-setup-dev # Ver logs del servidor
docker exec llm-setup-dev pi # Acceder a pi
```

### 4️⃣ Detener cuando termines

```bash
chmod +x .devcontainer/stop-container.sh
./devcontainer/stop-container.sh
```

**Nota:** Puedes ejecutarlo desde cualquier lugar si usas rutas absolutas, o desde la raíz del proyecto.

### 5️⃣ Accesos directos Docker

| Acción | Comando |
|--------|---------|
| Arrancar | `./devcontainer/start-from-terminal.sh` |
| Ver logs | `docker logs -f llm-setup-dev` |
| Acceder a pi | `docker exec -it llm-setup-dev pi` |
| Detener | `./devcontainer/stop-container.sh` |

---

## 🔧 Configuración

| Qué | Dónde |
|---|---|
| Versión llama.cpp / arquitectura CUDA | `.devcontainer/devcontainer.json` |
| Contexto y capas GPU por modelo | `.devcontainer/models.ini` |
| Modelos de pi | `.devcontainer/pi-models.json` → `~/.pi/agent/models.json` |
| Modelo inicial de pi | `.devcontainer/pi-settings.json` → `~/.pi/agent/settings.json` |
| Lista de descargas | `.devcontainer/download-models.sh` |

`HF_TOKEN` del host se pasa al contenedor si existe (solo necesario para repos con acceso restringido).

---

## 📊 Recursos aproximados

| Recurso | Uso típico |
|---------|------------|
| RAM | ~2.0 GB (solo modelo cargado) |
| VRAM | ~6-7 GB (dependiendo del modelo) |
| Disco | ~13 GB (modelos en volumen persistente) |
| CPU | ~10-15% durante inferencia |

*Valores aproximados para RTX 5070 Ti 16 GB*

---

## 📝 Notas importantes

- **Carpeta `.devcontainer`**: Es una carpeta oculta (empieza con punto). Contiene `Dockerfile`, scripts de terminal, etc.
- **Dockerfile**: Está **dentro** de `.devcontainer/`, no en la raíz del proyecto
- **Persistencia**: Los modelos se guardan en un volumen Docker (`llm-models`) para no perderlos al reiniciar.
- **Primera vez**: La construcción de llama.cpp puede tardar 10-20 minutos.
- **Rebuild**: Después de modificar `.devcontainer/`, usa `docker build` o `F1 → Dev Containers: Rebuild Container` en VS Code.

| Recurso | Uso típico |
|---------|------------|
| RAM | ~2.0 GB (solo modelo cargado) |
| VRAM | ~6-7 GB (dependiendo del modelo) |
| Disco | ~13 GB (modelos en volumen persistente) |
| CPU | ~10-15% durante inferencia |

*Valores aproximados para RTX 5070 Ti 16 GB*

### Comprobar el servidor

Si pi muestra `Connection error`, el servidor no está corriendo. Relanzarlo a mano:

```bash
nohup llama-server --models-preset /etc/llama/models.ini --models-max 1 --host 0.0.0.0 --port 9931 > /tmp/llama-server.log 2>&1 &
```

```bash
tail -f /tmp/llama-server.log
curl localhost:9931/models
curl localhost:9931/v1/chat/completions -H 'Content-Type: application/json' \
  -d '{"model":"qwen3.5-9b","messages":[{"role":"user","content":"hola"}]}'
```

## Configuración

| Qué | Dónde |
|---|---|
| Versión llama.cpp / arquitectura CUDA | `build.args` en `.devcontainer/devcontainer.json` |
| Contexto y capas GPU por modelo | `.devcontainer/models.ini` |
| Modelos de pi | `.devcontainer/pi-models.json` → `~/.pi/agent/models.json` |
| Modelo inicial de pi | `.devcontainer/pi-settings.json` → `~/.pi/agent/settings.json` |
| Lista de descargas | `.devcontainer/download-models.sh` |

`HF_TOKEN` del host se pasa al contenedor si existe (solo necesario para repos con acceso restringido).
