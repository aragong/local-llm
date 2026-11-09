# llm-setup

Contenedor con [llama.cpp](https://github.com/ggml-org/llama.cpp) (compilado con CUDA para Blackwell / RTX 50xx) + [pi](https://pi.dev) y un modelo local:

| Modelo | Fichero | Tamaño |
|---|---|---|
| Qwen3.5 9B Q4_K_M | `unsloth/Qwen3.5-9B-GGUF` / `Qwen3.5-9B-Q4_K_M.gguf` | ~5.7 GB |

Usuario del contenedor: `oceanos`. Los modelos viven en el volumen Docker `llm-models` y sobreviven a parar/borrar el contenedor.

## Requisitos

- GPU NVIDIA (probado: RTX 5070 Ti 16 GB) con driver reciente.
- Docker con soporte GPU (Docker Desktop + WSL2, o Docker Engine + `nvidia-container-toolkit`).
- Opcional: VS Code + extensión Dev Containers.

## Una sola instancia: VS Code y terminal comparten contenedor

VS Code (`devcontainer.json`) y `local-llm.sh` usan el **mismo** contenedor, `local-llm-dev`. Con 16 GB de VRAM no conviene tener dos `llama-server` con modelo cargado, así que no hay instancias independientes:

- Arrancado desde VS Code → `./local-llm.sh pi` desde una terminal del host entra en ese mismo contenedor.
- Arrancado desde terminal → en VS Code usar `F1` → **Dev Containers: Attach to Running Container** → `local-llm-dev`.
  (**Reopen in Container** fallaría con "name already in use"; antes `./local-llm.sh --stop`.)
- La terminal integrada de VS Code ya está *dentro* del contenedor: ahí se usa `pi` directamente, no `local-llm.sh`.

## Uso desde terminal (host)

```bash
./local-llm.sh --start     # construye imagen (caché), arranca, descarga modelos que falten
./local-llm.sh pi          # abre pi dentro del contenedor (lo arranca si hace falta)
./local-llm.sh --status    # estado, origen (VS Code/terminal), puerto, modelos
./local-llm.sh --logs      # log de llama-server
./local-llm.sh --restart
./local-llm.sh --stop      # elimina el contenedor; los modelos se conservan
./local-llm.sh --cleanup   # elimina contenedor y, si confirmas, volumen e imagen
```

Primera vez: compilar llama.cpp ~10-20 min + descargar ~5.7 GB. API en `http://localhost:9931` (solo localhost); otro puerto: `LOCAL_LLM_PORT=9932 ./local-llm.sh --start`.

El contenedor **no se para solo**: mientras corre ocupa VRAM. Párelo con `--stop` cuando no lo use.

## Uso desde VS Code

`F1` → **Dev Containers: Reopen in Container**. Tras cambiar algo en `.devcontainer/`: **Dev Containers: Rebuild Container**.
En la terminal integrada (`` Ctrl+` ``): `pi`.

## pi

Usa `qwen3.5-9b` (único modelo configurado).

| Acción | Cómo |
|---|---|
| Nivel de razonamiento | `Shift+Tab` |
| Salir | `Ctrl+C` dos veces |

## Comprobar el servidor

Si pi muestra `Connection error`, `llama-server` no corre. Dentro del contenedor:

```bash
nohup llama-server --models-preset /etc/llama/models.ini --models-max 1 --host 0.0.0.0 --port 9931 > /tmp/llama-server.log 2>&1 &
curl localhost:9931/models
curl localhost:9931/v1/chat/completions -H 'Content-Type: application/json' \
  -d '{"model":"qwen3.5-9b","messages":[{"role":"user","content":"hola"}]}'
```

## Configuración

| Qué | Dónde |
|---|---|
| Versión llama.cpp / arquitectura CUDA | `ARG` en `.devcontainer/Dockerfile` |
| Contexto y capas GPU | `.devcontainer/models.ini` |
| Modelos de pi | `.devcontainer/pi-models.json` → `~/.pi/agent/models.json` |
| Modelo inicial de pi | `.devcontainer/pi-settings.json` → `~/.pi/agent/settings.json` |
| Lista de descargas | `.devcontainer/download-models.sh` |

`HF_TOKEN` del host se pasa al contenedor si existe (solo para repos con acceso restringido).

## Recursos

- [llama.cpp](https://github.com/ggml-org/llama.cpp) · [pi](https://pi.dev) · [Qwen3.5 9B](https://huggingface.co/Qwen/Qwen3.5-9B)
