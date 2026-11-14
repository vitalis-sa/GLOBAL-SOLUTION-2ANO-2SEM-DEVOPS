#!/usr/bin/env bash
# =====================================================================
# ETAPA 3 - Cria as tabelas executando scripts/script-bd.sql no Azure SQL
#
# O script-bd.sql apaga e recria as tabelas (DROP TABLE IF EXISTS e
# CREATE TABLE), então rodar de novo devolve o banco ao estado inicial
# e APAGA OS DADOS de teste.
#
# Requer o sqlcmd (winget install Microsoft.Sqlcmd) e, no ambiente,
# DB_USER e DB_PASSWORD (na raiz: set -a; source .env; set +a).
# A senha vai para o sqlcmd pela variável SQLCMDPASSWORD, e não pela
# linha de comando.
# =====================================================================
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")"
source ./00-variaveis.sh

: "${DB_USER:?Defina DB_USER no .env}"
: "${DB_PASSWORD:?Defina DB_PASSWORD no .env}"

if ! command -v sqlcmd >/dev/null; then
  echo "sqlcmd não encontrado. Instale com: winget install Microsoft.Sqlcmd"
  exit 1
fi
if [[ ! -f ./script-bd.sql ]]; then
  echo "scripts/script-bd.sql não encontrado."
  exit 1
fi

echo
echo "[1/2] Executando script-bd.sql em ${SQL_DATABASE}..."
SQLCMDPASSWORD="${DB_PASSWORD}" sqlcmd \
  -S "tcp:${SQL_HOST},1433" \
  -d "${SQL_DATABASE}" \
  -U "${DB_USER}" \
  -b \
  -i ./script-bd.sql

echo "[2/2] Tabelas existentes no banco:"
SQLCMDPASSWORD="${DB_PASSWORD}" sqlcmd \
  -S "tcp:${SQL_HOST},1433" \
  -d "${SQL_DATABASE}" \
  -U "${DB_USER}" \
  -b \
  -h -1 \
  -Q "SET NOCOUNT ON; SELECT name FROM sys.tables ORDER BY name;"
