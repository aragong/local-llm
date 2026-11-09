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
        curl ca-certificates git sudo libcurl4 libssl3 libgomp1 \
    && curl -fsSL https://deb.nodesource.com/setup_22.x | bash - \
    && apt-get install -y --no-install-recommends nodejs \
    && rm -rf /var/lib/apt/lists/*

RUN npm install -g --ignore-scripts @earendil-works/pi-coding-agent

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

# Router llama.cpp como proceso del contenedor (no depende de sesiones exec de VS Code).
# ponytail: sin reinicio automático si llama-server cae; relanzar el contenedor o a mano (ver README).
CMD ["sh", "-c", "llama-server --models-preset /etc/llama/models.ini --models-max 1 --host 0.0.0.0 --port 9931 > /tmp/llama-server.log 2>&1 & exec sleep infinity"]
