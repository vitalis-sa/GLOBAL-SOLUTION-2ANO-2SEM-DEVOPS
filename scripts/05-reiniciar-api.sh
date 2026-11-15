#!/usr/bin/env bash
# =====================================================================
# Recupera a API depois de um reinício do container do Oracle
#
# O ACI não tem disco persistente: quando o container reinicia, o banco
# volta só com o usuário da aplicação e as tabelas NET_. Reiniciar o Web
# App faz o Flyway rodar de novo na partida e recriar as tabelas TB_, o
# pacote, o trigger e os dados de teste (migrations V1 a V3).
# Não altera nenhum recurso além de reiniciar o Web App.
# =====================================================================
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")"
source ./00-variaveis.sh

HOST=$(az webapp show --name "${WEBAPP}" --resource-group "${RESOURCE_GROUP}" --query defaultHostName -o tsv)

echo
echo "[1/2] Reiniciando o Web App ${WEBAPP}..."
az webapp restart --name "${WEBAPP}" --resource-group "${RESOURCE_GROUP}" -o none

echo "[2/2] Aguardando https://${HOST}${HEALTH_PATH} responder UP (até 5 minutos)..."
for _ in $(seq 1 30); do
  if curl -s --max-time 20 "https://${HOST}${HEALTH_PATH}" | grep -q '"status":"UP"'; then
    echo "      API no ar."
    exit 0
  fi
  sleep 10
done

echo "A API não respondeu UP. Veja os logs:"
echo "  az webapp log tail --name ${WEBAPP} --resource-group ${RESOURCE_GROUP}"
exit 1
