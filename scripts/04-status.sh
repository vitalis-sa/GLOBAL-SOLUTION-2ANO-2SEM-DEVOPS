#!/usr/bin/env bash
# =====================================================================
# Situação da infraestrutura: Web App, API publicada e banco.
# Só leitura: não altera nenhum recurso.
# =====================================================================
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")"
source ./00-variaveis.sh

echo "== Web App"
az webapp show \
  --name "${WEBAPP}" \
  --resource-group "${RESOURCE_GROUP}" \
  --query "{Estado:state, URL:defaultHostName, Runtime:siteConfig.linuxFxVersion, AlwaysOn:siteConfig.alwaysOn, SoHTTPS:httpsOnly}" \
  -o table

HOST=$(az webapp show --name "${WEBAPP}" --resource-group "${RESOURCE_GROUP}" --query defaultHostName -o tsv)
echo
# Sem deploy, o Web App devolve 200 com a página padrão em qualquer caminho,
# então o teste é pelo conteúdo: só a API responde um JSON "openapi".
if curl -s --max-time 60 "https://${HOST}${API_DOCS_PATH}" | grep -q '"openapi"'; then
  echo "API no ar: https://${HOST}${API_DOCS_PATH}"
else
  echo "API NÃO respondeu em https://${HOST}${API_DOCS_PATH}"
  echo "(sem deploy ainda, ou a aplicação está subindo/falhou: veja os logs)"
fi

echo
echo "== Banco"
az sql db show \
  --name "${SQL_DATABASE}" \
  --server "${SQL_SERVER}" \
  --resource-group "${RESOURCE_GROUP}" \
  --query "{Banco:name, Estado:status, Plano:currentServiceObjectiveName, Regiao:location}" \
  -o table

if command -v sqlcmd >/dev/null && [[ -n "${DB_USER:-}" && -n "${DB_PASSWORD:-}" ]]; then
  echo
  echo "Tabelas:"
  SQLCMDPASSWORD="${DB_PASSWORD}" sqlcmd -S "tcp:${SQL_HOST},1433" -d "${SQL_DATABASE}" -U "${DB_USER}" \
    -b -h -1 -Q "SET NOCOUNT ON; SELECT name FROM sys.tables ORDER BY name;"
fi

echo
echo "Logs ao vivo:  az webapp log tail --name ${WEBAPP} --resource-group ${RESOURCE_GROUP}"
