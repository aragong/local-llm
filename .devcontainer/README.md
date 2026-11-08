# 🐳 LLM-Setup DevContainer - Uso desde Terminal

## 📁 Estructura de carpetas

```
.
├── .devcontainer/              # Carpeta oculta (con el punto)
│   ├── Dockerfile             # Configuración del contenedor
│   ├── start-from-terminal.sh # Script para arrancar
│   ├── stop-container.sh      # Script para detener
│   ├── help.sh                # Script de ayuda
│   └── README.md              # Este archivo
└── ... otros archivos
```

**IMPORTANTE:**
- La carpeta es `.devcontainer` (con el punto)
- El **Dockerfile está dentro** de `.devcontainer/`
- Los scripts se ejecutan desde `.devcontainer/` o desde la raíz del proyecto

## 🚀 Comandos principales

### 1️⃣ Arrancar el contenedor

```bash
# Desde la raíz del proyecto (recomendado)
chmod +x .devcontainer/start-from-terminal.sh
./devcontainer/start-from-terminal.sh
```

**O desde dentro de .devcontainer/:**
```bash
cd .devcontainer/
chmod +x ./start-from-terminal.sh
./start-from-terminal.sh
```

### 2️⃣ Acceder a pi

```bash
# Acceder directamente a pi
docker exec -it llm-setup-dev pi
```

O primero entrar al bash y luego ejecutar:
```bash
docker exec -it llm-setup-dev bash
pi
```

### 3️⃣ Detener

```bash
chmod +x .devcontainer/stop-container.sh
./devcontainer/stop-container.sh
```

**O desde dentro de .devcontainer/:**
```bash
cd .devcontainer/
chmod +x ./stop-container.sh
./stop-container.sh
```

## 🐛 Solución de problemas

### Error: "open Dockerfile: no such file or directory"

**Causa:** El script no puede encontrar el Dockerfile en la ruta esperada.

**Solución:**
```bash
# Verificar que Dockerfile existe en la raíz del proyecto
ls -la /ruta/al/repo/Dockerfile

# Si no lo ves, quizás estás en la carpeta .devcontainer/
# Sal un nivel:
cd ..

# O usa la ruta absoluta:
PROJECT_ROOT=/ruta/al/repo
./devcontainer/start-from-terminal.sh
```

### Error: "failed to build: failed to solve"

**Causa:** Docker no puede encontrar el Dockerfile o falta GPU.

**Solución:**
```bash
# Verificar Dockerfile existe
ls -la /ruta/al/repo/Dockerfile

# Verificar GPU está disponible
docker --version
nvidia-smi
```

### Error: "Docker no está instalado"

**Solución:**
```bash
# Instalar Docker
sudo apt update
sudo apt install docker.io docker-compose

# Iniciar servicio
sudo systemctl start docker
sudo systemctl enable docker

# Añadir usuario a grupo docker (para evitar sudo)
sudo usermod -aG docker $USER
```

### ¿Qué pasa si dejo de usar el contenedor?

**⚠️ Importante:** El contenedor **NO** se detiene solo. Debes detenerlo manualmente:

```bash
# Detener temporalmente
./devcontainer/stop-container.sh

# O desde terminal
docker stop llm-setup-dev
docker rm llm-setup-dev
```

**Los modelos se conservan** en el volumen `llm-models` (~13 GB) a menos que los elimines:

```bash
# Eliminar volumen (borra los modelos)
docker volume rm llm-models
```

**Para más información:** `cat .devcontainer/HELP.md`

## 📊 Recursos en uso

| Recurso | Uso típico |
|---------|------------|
| RAM | ~2.0 GB (modelo cargado) |
| VRAM | ~6-7 GB (dependiendo del modelo) |
| Disco | ~13 GB (modelos) |
| CPU | ~10-15% durante inferencia |

## 🔗 API accesible

Una vez arrancado, el servidor llama está en:
- **Endpoint:** `http://localhost:9931`
- **Modelos:** `curl localhost:9931/models`
- **Chat:** `curl localhost:9931/v1/chat/completions`

---

## 🆘 ¿Necesitas ayuda?

Ejecuta:
```bash
./devcontainer/help.sh
```

**Para más información, ver [`../README.md`](../README.md)**
