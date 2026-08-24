#!/usr/bin/env bash
set -euo pipefail
umask 077

MODE="${1:-install}"
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
EXTRACT_REPO="${EXTRACT_REPO:-/home/dr/projetos/EXTRACAO-CLINICA-SASI}"
SYSTEMD_DIR="${SYSTEMD_DIR:-/home/dr/.config/systemd/user}"
N8N_HOME="${N8N_HOME:-/home/dr/.n8n}"
N8N_CLI="${N8N_CLI:-$(command -v n8n || true)}"
if [[ -z "$N8N_CLI" ]]; then
  for candidate in "$HOME"/.nvm/versions/node/*/bin/n8n; do
    if [[ -x "$candidate" ]]; then
      N8N_CLI="$candidate"
    fi
  done
fi
WORKFLOW="$REPO_DIR/n8n/workflows/sasi-clinical-compile.json"
WORKFLOW_ID="5c7ae179-bce1-4f40-a4f2-d78fdaf7723f"
BACKUP=""
MUTATION_STARTED=0

wait_http() {
  local url="$1" attempts="${2:-60}" i
  for ((i=1; i<=attempts; i++)); do
    if curl --silent --fail --max-time 2 "$url" >/dev/null 2>&1; then
      return 0
    fi
    sleep 1
  done
  echo "Serviço não respondeu: $url" >&2
  return 1
}

rollback_database() {
  [[ -n "$BACKUP" && -f "$BACKUP" ]] || return 0
  systemctl --user stop n8n.service >/dev/null 2>&1 || true
  install -m 0600 "$BACKUP" "$N8N_HOME/database.sqlite"
  systemctl --user start n8n.service >/dev/null 2>&1 || true
}

cleanup() {
  local status=$?
  if (( status != 0 && MUTATION_STARTED )); then
    rollback_database
    echo "Instalação revertida a partir do backup: ${BACKUP:-indisponível}" >&2
  fi
  return "$status"
}
trap cleanup EXIT

for dependency in curl python3 systemctl install systemd-analyze; do
  command -v "$dependency" >/dev/null || { echo "Dependência ausente: $dependency" >&2; exit 1; }
done
[[ -n "$N8N_CLI" && -x "$N8N_CLI" ]] || { echo "n8n não encontrado no PATH ou NVM; defina N8N_CLI" >&2; exit 1; }
export PATH="$(dirname "$N8N_CLI"):$PATH"
for required in \
  "$EXTRACT_REPO/src/extracao_clinica_sasi/server.py" \
  "$WORKFLOW" \
  "$REPO_DIR/services/extracao-clinica-sasi.service"; do
  [[ -f "$required" ]] || { echo "Arquivo obrigatório ausente: $required" >&2; exit 1; }
done
[[ -f "$N8N_HOME/database.sqlite" ]] || { echo "Banco n8n ausente: $N8N_HOME/database.sqlite" >&2; exit 1; }
python3 -m json.tool "$WORKFLOW" >/dev/null
systemd-analyze --user verify "$REPO_DIR/services/extracao-clinica-sasi.service"

if [[ "$MODE" == "--check" ]]; then
  echo "Pré-requisitos válidos; nenhuma alteração realizada."
  exit 0
fi
[[ "$MODE" == "install" ]] || { echo "Uso: $0 [--check]" >&2; exit 2; }

install -d -m 0700 "$SYSTEMD_DIR"
install -m 0600 "$REPO_DIR/services/extracao-clinica-sasi.service" \
  "$SYSTEMD_DIR/extracao-clinica-sasi.service"
systemctl --user daemon-reload
systemctl --user enable extracao-clinica-sasi.service
systemctl --user restart extracao-clinica-sasi.service
wait_http "http://127.0.0.1:8765/healthz" 30

install -d -m 0700 "$N8N_HOME/backups"
if [[ -f "$N8N_HOME/database.sqlite" ]]; then
  BACKUP="$N8N_HOME/backups/database-pre-sasi-$(date +%Y%m%dT%H%M%S)-$$.sqlite"
  python3 - "$N8N_HOME/database.sqlite" "$BACKUP" <<'PY'
import os
import sqlite3
import sys
source_path, backup_path = sys.argv[1:]
source = sqlite3.connect(f"file:{source_path}?mode=ro", uri=True)
target = sqlite3.connect(backup_path)
try:
    if source.execute("PRAGMA quick_check").fetchone()[0] != "ok":
        raise SystemExit("Banco n8n de origem corrompido")
    source.backup(target)
    target.commit()
    if target.execute("PRAGMA integrity_check").fetchone()[0] != "ok":
        raise SystemExit("Backup n8n inválido")
finally:
    target.close()
    source.close()
os.chmod(backup_path, 0o600)
PY
fi

MUTATION_STARTED=1
systemctl --user stop n8n.service
"$N8N_CLI" import:workflow --input="$WORKFLOW"
"$N8N_CLI" publish:workflow --id="$WORKFLOW_ID"
systemctl --user start n8n.service
wait_http "http://127.0.0.1:5678/healthz" 60

python3 - "$N8N_HOME/database.sqlite" "$WORKFLOW_ID" <<'PY'
import sqlite3
import sys
path, workflow_id = sys.argv[1:]
connection = sqlite3.connect(f"file:{path}?mode=ro", uri=True)
try:
    row = connection.execute(
        'SELECT name, active FROM workflow_entity WHERE id = ?', (workflow_id,)
    ).fetchone()
finally:
    connection.close()
if row != ("SASI - Compilar Extração Clínica", 1):
    raise SystemExit(f"Workflow não ficou ativo: {row!r}")
PY
MUTATION_STARTED=0

echo "Motor clínico ativo em 127.0.0.1:8765; workflow SASI publicado no n8n."
[[ -z "$BACKUP" ]] || echo "Backup n8n: $BACKUP"
