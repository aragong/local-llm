ARG CUDA_VERSION=12.8.1
ARG UBUNTU_VERSION=24.04

# ---------- build stable-diffusion.cpp (CUDA, Blackwell sm_120) ----------
# Node/pnpm solo para incrustar la Web UI en sd-server.
FROM nvidia/cuda:${CUDA_VERSION}-devel-ubuntu${UBUNTU_VERSION} AS sd-builder
ARG SD_CPP_TAG=master-1106-532d2c1
ARG CUDA_ARCH=120

RUN apt-get update && apt-get install -y --no-install-recommends \
        git cmake build-essential ca-certificates curl \
    && curl -fsSL https://deb.nodesource.com/setup_22.x | bash - \
    && apt-get install -y --no-install-recommends nodejs \
    && npm install -g pnpm@10 \
    && rm -rf /var/lib/apt/lists/*

RUN git clone --depth 1 --branch ${SD_CPP_TAG} --recurse-submodules --shallow-submodules \
        https://github.com/leejet/stable-diffusion.cpp /src
WORKDIR /src
RUN cmake -B build \
        -DCMAKE_BUILD_TYPE=Release \
        -DSD_CUDA=ON \
        -DCMAKE_CUDA_ARCHITECTURES=${CUDA_ARCH} \
        -DGGML_NATIVE=OFF \
        -DCMAKE_EXE_LINKER_FLAGS=-Wl,--allow-shlib-undefined \
    && cmake --build build -j"$(nproc)" --target sd-cli sd-server

# ---------- runtime ----------
FROM nvidia/cuda:${CUDA_VERSION}-runtime-ubuntu${UBUNTU_VERSION}

RUN apt-get update && apt-get install -y --no-install-recommends \
        curl ca-certificates git sudo libcurl4 libssl3 libgomp1 python3 python3-venv \
    && curl -fsSL https://deb.nodesource.com/setup_22.x | bash - \
    && apt-get install -y --no-install-recommends nodejs \
    && rm -rf /var/lib/apt/lists/*

RUN npm install -g --ignore-scripts @earendil-works/pi-coding-agent

# SearXNG (metabuscador local, sin claves) para la herramienta web_search de pi.
ARG SEARXNG_REF=57ff753ad416b7bf27e59d72ae8c7cac93b56be4
RUN git init -q /opt/searxng/src && cd /opt/searxng/src \
    && git fetch -q --depth 1 https://github.com/searxng/searxng ${SEARXNG_REF} && git checkout -q FETCH_HEAD \
    && python3 -m venv /opt/searxng/venv \
    && /opt/searxng/venv/bin/pip install --no-cache-dir -q -r requirements.txt
COPY .devcontainer/searxng-settings.yml /etc/searxng/settings.yml
ENV SEARXNG_SETTINGS_PATH=/etc/searxng/settings.yml \
    SEARXNG_URL=http://127.0.0.1:8888

# llama.cpp: binario precompilado del fork de Unsloth (upstream b12651 + parches Inkling 2: DSpark,
# colocación de capas en bucle...). CUDA 12.8, incluye sm_120. Libs junto a los binarios (rpath $ORIGIN).
# Hash = digest del asset en la release de GitHub. Oficial ggml-org b12676 medido: Inkling 34 tok/s frente
# a 43 con el fork (Qwen igual en ambos). Volver al oficial (compilar, ver git log) cuando lo iguale.
ARG LLAMA_CPP_URL=https://github.com/unslothai/llama.cpp/releases/download/b12651-mix-c7059d6/app-b12651-mix-c7059d6-linux-x64-cuda12-newer.tar.gz
ARG LLAMA_CPP_SHA256=4a08e6f3483ffa5e383cfa6ef88eec0765160cc2a9fefc80c0d380bb207a49b3
RUN mkdir -p /opt/llama.cpp/bin && curl -fsSL "$LLAMA_CPP_URL" -o /tmp/llama.tgz \
    && echo "$LLAMA_CPP_SHA256  /tmp/llama.tgz" | sha256sum -c - \
    && tar xzf /tmp/llama.tgz -C /opt/llama.cpp/bin --no-same-owner && chmod 755 /opt/llama.cpp/bin && rm /tmp/llama.tgz
COPY --from=sd-builder /src/build/bin/sd-cli /src/build/bin/sd-server /opt/sd.cpp/bin/
ENV PATH=/opt/llama.cpp/bin:/opt/sd.cpp/bin:${PATH}

# ubuntu:24.04 trae usuario "ubuntu" con UID 1000; lo reemplazamos por oceanos
RUN userdel -r ubuntu \
    && useradd -m -s /bin/bash -u 1000 oceanos \
    && echo "oceanos ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/oceanos \
    && mkdir -p /models && chown oceanos:oceanos /models

COPY .devcontainer/models.ini /etc/llama/models.ini
COPY --chmod=755 .devcontainer/download-models.sh /usr/local/bin/download-models.sh
COPY --chmod=755 .devcontainer/sd-server.sh /usr/local/bin/sd-server.sh
# Modelo de imagen (FLUX.2 klein 4B): rutas únicas para sd-server.sh y para usar sd-cli sin escribirlas.
ENV FLUX_DIT=/models/sd/diffusion_models/flux-2-klein-4b-Q6_K.gguf \
    FLUX_LLM=/models/sd/text_encoders/Qwen3-4B-Q6_K.gguf \
    FLUX_VAE=/models/sd/vae/flux2-vae.safetensors
COPY --chown=oceanos:oceanos .devcontainer/pi-models.json /home/oceanos/.pi/agent/models.json
COPY --chown=oceanos:oceanos .devcontainer/pi-settings.json /home/oceanos/.pi/agent/settings.json

USER oceanos
WORKDIR /home/oceanos
RUN pi install npm:@oresk/pi-searxng@0.2.2

# Procesos del contenedor (no dependen de sesiones exec de VS Code): SearXNG, router llama.cpp y sd-server.
# ponytail: sin reinicio automático si alguno cae; relanzar el contenedor o a mano (ver README).
CMD ["sh", "-c", "cd /opt/searxng/src && /opt/searxng/venv/bin/python -m searx.webapp > /tmp/searxng.log 2>&1 & llama-server --models-preset /etc/llama/models.ini --models-max 1 --host 0.0.0.0 --port 9931 > /tmp/llama-server.log 2>&1 & sd-server.sh > /tmp/sd-server.log 2>&1 & exec sleep infinity"]
