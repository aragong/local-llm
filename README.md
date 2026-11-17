# local-llm

Contenedor con [llama.cpp](https://github.com/ggml-org/llama.cpp) (compilado con CUDA para Blackwell / RTX 50xx) + [pi](https://pi.dev), búsqueda web local con [SearXNG](https://docs.searxng.org/) y generación de imágenes con [stable-diffusion.cpp](https://github.com/leejet/stable-diffusion.cpp). Modelos locales:

| Modelo | Fichero | Tamaño |
|---|---|---|
| Qwen3.5 9B Q4_K_M (texto, pi) | `unsloth/Qwen3.5-9B-GGUF` / `Qwen3.5-9B-Q4_K_M.gguf` | ~5.7 GB |
| FLUX.2 [klein] 4B Q6_K (imágenes) | `unsloth/FLUX.2-klein-4B-GGUF` / `flux-2-klein-4b-Q6_K.gguf` | ~3.4 GB |
| ↳ codificador de texto Qwen3 4B Q6_K | `unsloth/Qwen3-4B-GGUF` / `Qwen3-4B-Q6_K.gguf` | ~3.3 GB |
| ↳ VAE FLUX.2 | `Comfy-Org/Flux-2-Klein-4B` / `split_files/vae/flux2-vae.safetensors` | ~0.3 GB |

`llama-server` corre en modo router (`--models-preset`): para añadir otro modelo basta una sección en `models.ini`, una entrada en `pi-models.json` y su descarga. `--models-max 1` mantiene uno solo en VRAM.

Usuario del contenedor: `oceanos`. Los modelos viven en el volumen Docker `llm-models` (los de imagen en `/models/sd/`) y sobreviven a parar/borrar el contenedor.

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
./local-llm.sh shell       # abre una terminal bash dentro del contenedor (ídem)
./local-llm.sh --status    # estado, origen (VS Code/terminal), puerto, modelos
./local-llm.sh --logs      # log de llama-server (--logs sd: el de sd-server)
./local-llm.sh --restart
./local-llm.sh --stop      # elimina el contenedor; los modelos se conservan
./local-llm.sh --cleanup   # elimina contenedor y, si confirmas, volumen e imagen
```

Primera vez: compilar llama.cpp ~10-20 min + stable-diffusion.cpp ~8 min (en paralelo) + instalar SearXNG ~1 min + descargar ~13 GB. API de texto en `http://localhost:9931` y Web UI de imágenes en `http://localhost:7860` (solo localhost); otros puertos: `LOCAL_LLM_PORT=9932 LOCAL_SD_PORT=7861 ./local-llm.sh --start`.

El contenedor **no se para solo**: mientras corre ocupa VRAM. Párelo con `--stop` cuando no lo use.

## Uso desde VS Code

`F1` → **Dev Containers: Reopen in Container**. Tras cambiar algo en `.devcontainer/`: **Dev Containers: Rebuild Container**.
En la terminal integrada (`` Ctrl+` ``): `pi`.

## pi

Modelo: `qwen3.5-9b` (uso general, agente con herramientas), contexto 256k (KV q8_0).

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

El modelo puede filtrar por categoría (`general`, `it`, `science`, `news`, `repos`…), idioma, fecha o motor concreto. Revisa las fuentes citadas: un modelo de 9B puede elegir resultados poco fiables.

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

## Generación de imágenes (stable-diffusion.cpp)

`sd-server` arranca con el contenedor y deja **FLUX.2 [klein] 4B** listo (texto → imagen y edición con imágenes de referencia, 4 pasos, licencia Apache 2.0):

- **Web UI:** abrir <http://localhost:7860> en el navegador de Windows. El modelo ya aparece cargado como *Command-line model*; escribir el prompt y generar. Para editar una imagen, adjuntarla como referencia y describir el cambio.
- **API compatible con OpenAI** (desde el host o el contenedor):

  ```bash
  curl -s localhost:7860/v1/images/generations -H 'Content-Type: application/json' \
    -d '{"prompt":"a lighthouse on a rocky coast at sunset","size":"1024x1024"}' \
    | python3 -c "import sys,json,base64; open('out.png','wb').write(base64.b64decode(json.load(sys.stdin)['data'][0]['b64_json']))"
  ```

  También expone la API de A1111 (`/sdapi/v1/txt2img`) y la propia (`/sdcpp/v1/...`): ver [api.md](https://github.com/leejet/stable-diffusion.cpp/blob/master/examples/server/api.md).
- **CLI** con `sd-cli`, sin pasar por el servidor. Abrir una terminal en el contenedor (`./local-llm.sh shell` desde el host, o la terminal integrada de VS Code) y, desde cualquier carpeta:

  ```bash
  sd-cli \
    --diffusion-model $FLUX_DIT \
    --llm $FLUX_LLM \
    --vae $FLUX_VAE \
    -p "Un astronauta descansando en una playa tropical al atardecer, estilo cinematografico" \
    --cfg-scale 1.0 \
    --steps 4 \
    -W 1024 -H 1024 \
    --flash-attn on \
    -o ~/test.png
  ```

  ~4 s por imagen. `$FLUX_DIT`, `$FLUX_LLM` y `$FLUX_VAE` son variables de entorno del contenedor con las rutas del modelo, el codificador de texto y el VAE (definidas en el `Dockerfile`). klein está destilado para 4 pasos con `--cfg-scale 1.0`; la variante *base* usaría ~20 pasos y CFG ~4. `--flash-attn on` ahorra VRAM (sustituye al obsoleto `--diffusion-fa`).

  Para ver la imagen desde Windows: `docker cp local-llm-dev:/home/oceanos/test.png .` en el host, o `code ~/test.png` desde la terminal integrada de VS Code.

**VRAM: convive con Qwen.** `sd-server` usa `--offload-to-cpu`: los pesos (~7 GB) quedan en RAM y solo suben a la GPU mientras genera, así que en reposo no ocupa VRAM. Medido en la RTX 5070 Ti, 1024×1024:

| Situación | Tiempo por imagen | VRAM pico (GPU total) |
|---|---|---|
| Solo FLUX | ~4-5 s | 10.7 GB |
| Con Qwen cargado (256k) | ~6-7 s | 15.8 GB de 16.3 |

Con Qwen cargado se roza el límite: la primera respuesta de pi justo después de generar puede ir más lenta (medido 67 tok/s en vez de ~110) mientras Windows devuelve memoria a la GPU; se recupera en la siguiente. pi **no** genera imágenes por sí mismo (no tiene herramienta para ello): se usan la Web UI, la API o `sd-cli`.

**Comprobar / relanzar** (dentro del contenedor):

```bash
curl -s localhost:7860/sdcpp/v1/models/status | head -c 200   # "state":"ready"
tail /tmp/sd-server.log
nohup sd-server.sh > /tmp/sd-server.log 2>&1 &                 # si no responde
```

`sd-server.sh` espera a que estén los tres ficheros del modelo (en el primer arranque se descargan después de arrancar el contenedor).

**Otros modelos de imagen:** añadir sus ficheros a `download-models.sh` con la subcarpeta de categoría (`sd/diffusion_models`, `sd/text_encoders`, `sd/vae`…) y elegirlos en la Web UI con su *recipe* (botón **Model**). Ver la [lista de modelos soportados](https://github.com/leejet/stable-diffusion.cpp/tree/master/docs/models). Para cambiar el modelo precargado (y las variables `$FLUX_*`), editar `ENV FLUX_*` en el `Dockerfile`.

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
| Versión llama.cpp / stable-diffusion.cpp / arquitectura CUDA | `ARG LLAMA_CPP_TAG`, `SD_CPP_TAG`, `CUDA_ARCH` en `.devcontainer/Dockerfile` |
| Contexto, capas GPU, KV cache, muestreo | `.devcontainer/models.ini` |
| Modelos de pi | `.devcontainer/pi-models.json` → `~/.pi/agent/models.json` |
| Modelo inicial de pi | `.devcontainer/pi-settings.json` → `~/.pi/agent/settings.json` |
| Lista de descargas | `.devcontainer/download-models.sh` |
| Modelo de imagen precargado (`$FLUX_*`) | `ENV FLUX_*` en `.devcontainer/Dockerfile` |
| Opciones de sd-server | `.devcontainer/sd-server.sh` |
| SearXNG (motores, puerto) | `.devcontainer/searxng-settings.yml`; versión: `ARG SEARXNG_REF` en el `Dockerfile` |
| Extensiones de pi | `RUN pi install …` en el `Dockerfile` |

Cambios en `.devcontainer/` van dentro de la imagen: aplicar con `./local-llm.sh --stop && ./local-llm.sh --start` (o **Rebuild Container** en VS Code).

`HF_TOKEN` del host se pasa al contenedor si existe (solo para repos con acceso restringido).

## Recursos

- [llama.cpp](https://github.com/ggml-org/llama.cpp) · [pi](https://pi.dev) · [Qwen3.5 9B](https://huggingface.co/Qwen/Qwen3.5-9B) · [stable-diffusion.cpp](https://github.com/leejet/stable-diffusion.cpp) · [FLUX.2 klein 4B](https://huggingface.co/black-forest-labs/FLUX.2-klein-4B) · [SearXNG](https://docs.searxng.org/) · [@oresk/pi-searxng](https://www.npmjs.com/package/@oresk/pi-searxng)
