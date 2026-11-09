ARG CUDA_VERSION=12.8.1
ARG UBUNTU_VERSION=24.04

# ---------- build llama.cpp (CUDA, Blackwell sm_120) ----------
FROM nvidia/cuda:${CUDA_VERSION}-devel-ubuntu${UBUNTU_VERSION} AS builder
ARG LLAMA_CPP_TAG=b12167
ARG CUDA_ARCH=120

RUN apt-get update && apt-get install -y --no-install-recommends \
        git cmake build-essential libcurl4-openssl-dev libssl-dev ca-certificates \
    && rm -rf /var/lib/apt/lists/*

RUN git clone --depth 1 --branch ${LLAMA_CPP_TAG} https://github.com/ggml-org/llama.cpp /src
WORKDIR /src
RUN cmake -B build \
        -DCMAKE_BUILD_TYPE=Release \
        -DGGML_CUDA=ON \
        -DCMAKE_CUDA_ARCHITECTURES=${CUDA_ARCH} \
        -DGGML_NATIVE=OFF \
        -DLLAMA_BUILD_TESTS=OFF \
        -DCMAKE_EXE_LINKER_FLAGS=-Wl,--allow-shlib-undefined \
    && cmake --build build -j"$(nproc)" \
    && cmake --install build --prefix /opt/llama.cpp

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

COPY --from=builder /opt/llama.cpp /opt/llama.cpp
ENV PATH=/opt/llama.cpp/bin:${PATH} \
    LD_LIBRARY_PATH=/opt/llama.cpp/lib:${LD_LIBRARY_PATH}

# ubuntu:24.04 trae usuario "ubuntu" con UID 1000; lo reemplazamos por oceanos
RUN userdel -r ubuntu \
    && useradd -m -s /bin/bash -u 1000 oceanos \
    && echo "oceanos ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/oceanos \
    && mkdir -p /models && chown oceanos:oceanos /models

COPY .devcontainer/models.ini /etc/llama/models.ini
COPY --chmod=755 .devcontainer/download-models.sh /usr/local/bin/download-models.sh
COPY --chown=oceanos:oceanos .devcontainer/pi-models.json /home/oceanos/.pi/agent/models.json
COPY --chown=oceanos:oceanos .devcontainer/pi-settings.json /home/oceanos/.pi/agent/settings.json

USER oceanos
WORKDIR /home/oceanos
RUN pi install npm:@oresk/pi-searxng@0.2.2

# Router llama.cpp y SearXNG como procesos del contenedor (no dependen de sesiones exec de VS Code).
# ponytail: sin reinicio automático si alguno cae; relanzar el contenedor o a mano (ver README).
CMD ["sh", "-c", "cd /opt/searxng/src && /opt/searxng/venv/bin/python -m searx.webapp > /tmp/searxng.log 2>&1 & llama-server --models-preset /etc/llama/models.ini --models-max 1 --host 0.0.0.0 --port 9931 > /tmp/llama-server.log 2>&1 & exec sleep infinity"]
