# local-llm

Contenedor con [llama.cpp](https://github.com/ggml-org/llama.cpp) (compilado con CUDA para Blackwell / RTX 50xx) + [pi](https://pi.dev), búsqueda web local con [SearXNG](https://docs.searxng.org/) y modelos locales:

| Modelo | Fichero | Tamaño |
|---|---|---|
| Qwen3.5 9B Q4_K_M | `unsloth/Qwen3.5-9B-GGUF` / `Qwen3.5-9B-Q4_K_M.gguf` | ~5.7 GB |
| DeepSeek R1 Distill Qwen 14B Q4_K_M | `unsloth/DeepSeek-R1-Distill-Qwen-14B-GGUF` / `DeepSeek-R1-Distill-Qwen-14B-Q4_K_M.gguf` | ~9.0 GB |

`llama-server` carga un solo modelo a la vez (`--models-max 1`): al pedir otro, descarga el anterior de la VRAM.

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

Primera vez: compilar llama.cpp ~10-20 min + instalar SearXNG ~1 min + descargar ~15 GB. API en `http://localhost:9931` (solo localhost); otro puerto: `LOCAL_LLM_PORT=9932 ./local-llm.sh --start`.

El contenedor **no se para solo**: mientras corre ocupa VRAM. Párelo con `--stop` cuando no lo use.

## Uso desde VS Code

`F1` → **Dev Containers: Reopen in Container**. Tras cambiar algo en `.devcontainer/`: **Dev Containers: Rebuild Container**.
En la terminal integrada (`` Ctrl+` ``): `pi`.

## pi

Arranca con `qwen3.5-9b`. Cambiar de modelo: `/model` → `deepseek-r1-14b`.

| Modelo | Para qué | Contexto |
|---|---|---|
| `qwen3.5-9b` | Uso general, agente con herramientas | 256k (KV q8_0) |
| `deepseek-r1-14b` | Razonamiento matemático/físico (piensa siempre en `<think>`). Flojo usando herramientas de pi: mejor para preguntar que para editar código | 44k (KV q8_0) |

| Acción | Cómo |
|---|---|
| Buscar en internet | Pedirlo en el prompt: el modelo usa la herramienta `web_search` |
| Nivel de razonamiento | `Shift+Tab` |
| Salir | `Ctrl+C` dos veces |

### Búsqueda web (SearXNG)

pi puede buscar en internet con la herramienta `web_search`, sin claves de API ni cuotas y sin salir del contenedor:

```
pi ──web_search──▶ @oresk/pi-searxng ──HTTP──▶ SearXNG (127.0.0.1:8888) ──▶ Google, Brave, DuckDuckGo…
```

- [SearXNG](https://docs.searxng.org/) es un metabuscador de código abierto. Arranca junto a `llama-server` dentro de `local-llm-dev`, escucha solo en `127.0.0.1:8888` (no se publica al host) y consulta los buscadores desde tu IP, combinando resultados.
- La extensión [`@oresk/pi-searxng`](https://www.npmjs.com/package/@oresk/pi-searxng) (MIT, un fichero, sin dependencias) registra `web_search` en pi y llama a SearXNG vía `SEARXNG_URL`.
- Privacidad: solo salen a internet las consultas de búsqueda; la conversación y el código siguen en local.

**Por qué SearXNG y no `pi-web-search`:** ese paquete delega en la búsqueda nativa del proveedor del modelo (Gemini, OpenAI, Anthropic…). Con llama.cpp (o vLLM, Ollama local…) no hay búsqueda nativa: necesitaría un modelo en la nube con clave. SearXNG es la única opción 100 % local.

**Uso:** pedirlo en el prompt. Ejemplos:

```
Busca en internet la última versión de llama.cpp y resume sus cambios.
Busca en la categoría science artículos recientes sobre turbulencia en flujos costeros.
```

El modelo puede filtrar por categoría (`general`, `it`, `science`, `news`, `repos`…), idioma, fecha o motor concreto. Qwen usa la herramienta bien; DeepSeek R1 no está entrenado para herramientas. Revisa las fuentes citadas: un modelo de 9B puede elegir resultados poco fiables.

**Comprobar / solucionar** (dentro del contenedor):

```bash
curl -s "$SEARXNG_URL/search?q=test&format=json" | head -c 300   # debe devolver JSON con "results"
tail /tmp/searxng.log
# Si no responde (no hay reinicio automático), relanzarlo:
cd /opt/searxng/src && nohup /opt/searxng/venv/bin/python -m searx.webapp > /tmp/searxng.log 2>&1 &
```

- `unresponsive_engines` con `CAPTCHA` o `too many requests` es normal: algunos buscadores bloquean peticiones automáticas y SearXNG usa los demás. Si uno falla siempre, desactivarlo en `.devcontainer/searxng-settings.yml` (ver [engines](https://docs.searxng.org/admin/settings/settings_engines.html)).
- En el log, `torch: can't register engine` y `missing config file: limiter.toml` son avisos inofensivos.

**Actualizar SearXNG:** cambiar `ARG SEARXNG_REF` en el `Dockerfile` por un commit reciente de [searxng/searxng](https://github.com/searxng/searxng/commits/master) y reconstruir. La extensión se actualiza cambiando la versión en `RUN pi install npm:@oresk/pi-searxng@…`.

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
| Contexto, capas GPU, KV cache, muestreo | `.devcontainer/models.ini` |
| Modelos de pi | `.devcontainer/pi-models.json` → `~/.pi/agent/models.json` |
| Modelo inicial de pi | `.devcontainer/pi-settings.json` → `~/.pi/agent/settings.json` |
| Lista de descargas | `.devcontainer/download-models.sh` |
| SearXNG (motores, puerto) | `.devcontainer/searxng-settings.yml`; versión: `ARG SEARXNG_REF` en el `Dockerfile` |
| Extensiones de pi | `RUN pi install …` en el `Dockerfile` |

Cambios en `.devcontainer/` van dentro de la imagen: aplicar con `./local-llm.sh --stop && ./local-llm.sh --start` (o **Rebuild Container** en VS Code).

`HF_TOKEN` del host se pasa al contenedor si existe (solo para repos con acceso restringido).

## Recursos

- [llama.cpp](https://github.com/ggml-org/llama.cpp) · [pi](https://pi.dev) · [Qwen3.5 9B](https://huggingface.co/Qwen/Qwen3.5-9B) · [DeepSeek-R1-Distill-Qwen-14B](https://huggingface.co/deepseek-ai/DeepSeek-R1-Distill-Qwen-14B) · [SearXNG](https://docs.searxng.org/) · [@oresk/pi-searxng](https://www.npmjs.com/package/@oresk/pi-searxng)
