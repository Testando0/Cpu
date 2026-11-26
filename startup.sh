#!/usr/bin/env bash
# ==========================================================
#  API compatível com OpenAI (Qwen 2.5 0.5B) para o Replit
#
#  Como usar no Replit:
#    1. Crie um Repl "Python" e envie este arquivo.
#    2. (Recomendado) Em Secrets, crie API_KEY com uma senha sua.
#    3. No Shell:  bash setup_replit.sh
#    4. Depois, é só clicar em "Run" (usa start.sh).
#
#  Endpoints (OpenAI):
#    POST /v1/chat/completions
#    POST /v1/completions
#    GET  /v1/models
# ==========================================================
set -euo pipefail

MODEL_URL="${MODEL_URL:-https://huggingface.co/Qwen/Qwen2.5-0.5B-Instruct-GGUF/resolve/main/qwen2.5-0.5b-instruct-q4_k_m.gguf}"
MODEL_DIR="models"
MODEL_FILE="$MODEL_DIR/qwen.gguf"
MIN_SIZE=100000000   # 100 MB: abaixo disso o download é considerado inválido

echo "==> 1/4 Instalando servidor (llama-cpp-python, wheel pré-compilada)"
pip install -q --upgrade pip || true
pip install -q "llama-cpp-python[server]" \
  --extra-index-url https://abetlen.github.io/llama-cpp-python/whl/cpu

echo "==> 2/4 Baixando o modelo"
mkdir -p "$MODEL_DIR"
if [ -f "$MODEL_FILE" ] && [ "$(stat -c%s "$MODEL_FILE")" -gt "$MIN_SIZE" ]; then
  echo "Modelo já existe, pulando."
else
  curl -L --fail --retry 3 -C - -o "$MODEL_FILE" "$MODEL_URL"
fi
if [ "$(stat -c%s "$MODEL_FILE")" -le "$MIN_SIZE" ]; then
  rm -f "$MODEL_FILE"
  echo "Modelo inválido. Rode o script de novo." >&2
  exit 1
fi
ls -lh "$MODEL_FILE"

echo "==> 3/4 Criando start.sh"
cat > start.sh <<'EOF'
#!/usr/bin/env bash
set -e
ARGS=(
  --model models/qwen.gguf
  --model_alias qwen2.5-0.5b
  --host 0.0.0.0
  --port "${PORT:-8000}"
  --n_ctx 2048
  --n_threads "$(nproc)"
  --chat_format chatml
)
if [ -n "${API_KEY:-}" ]; then
  ARGS+=(--api_key "$API_KEY")
else
  echo "AVISO: API_KEY não definida (Secrets). A API ficará aberta!"
fi
exec python -m llama_cpp.server "${ARGS[@]}"
EOF
chmod +x start.sh

echo "==> 4/4 Criando .replit"
cat > .replit <<'EOF'
run = "bash start.sh"

[[ports]]
localPort = 8000
externalPort = 80

[deployment]
run = ["bash", "start.sh"]
deploymentTarget = "cloudrun"
EOF

cat <<'EOF'

Pronto! Clique em "Run".

Teste:
  curl https://SEU-REPL.replit.app/v1/chat/completions \
    -H "Authorization: Bearer $API_KEY" \
    -H "Content-Type: application/json" \
    -d '{"model":"qwen2.5-0.5b","messages":[{"role":"user","content":"Olá!"}]}'

Em clientes OpenAI use:
  base_url = https://SEU-REPL.replit.app/v1
  api_key  = o valor de API_KEY
EOF
