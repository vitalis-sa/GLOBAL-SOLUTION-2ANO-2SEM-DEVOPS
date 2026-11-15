#!/usr/bin/env bash
# =====================================================================
# Situação da infraestrutura: Web App, API publicada, registro e banco.
# Só leitura: não altera nenhum recurso.
# =====================================================================
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")"
source ./00-variaveis.sh

echo "== Recursos do ${RESOURCE_GROUP}"
az resource list \
  --resource-group "${RESOURCE_GROUP}" \
  --query "[].{Nome:name, Tipo:type, Regiao:location}" \
  -o table

echo
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
  echo "API no ar: https://${HOST}/swagger-ui.html"
  echo "Saúde:     $(curl -s --max-time 30 "https://${HOST}${HEALTH_PATH}")"
else
  echo "API NÃO respondeu em https://${HOST}${API_DOCS_PATH}"
  echo "(sem deploy ainda, ou a aplicação está subindo/falhou: veja os logs)"
fi

echo
echo "== Container Registry"
az acr repository show-tags --name "${ACR_NAME}" --repository "${ORACLE_IMAGE_NAME}" -o table 2>/dev/null \
  || echo "Imagem ${ORACLE_IMAGE_NAME} ainda não publicada."

echo
echo "== Banco Oracle (ACI)"
az container show \
  --name "${ACI_ORACLE}" \
  --resource-group "${RESOURCE_GROUP}" \
  --query "{Estado:instanceView.state, Endereco:ipAddress.fqdn, CPU:containers[0].resources.requests.cpu, MemoriaGB:containers[0].resources.requests.memoryInGB, Reinicios:containers[0].instanceView.restartCount}" \
  -o table
echo "Conexão: ${ORACLE_HOST}:${ORACLE_PORT}/${ORACLE_SERVICE} (usuário ${DB_USER})"
az container logs --name "${ACI_ORACLE}" --resource-group "${RESOURCE_GROUP}" 2>/dev/null \
  | grep -E "remembered:|DATABASE IS READY" || true

echo
echo "Logs ao vivo da API:  az webapp log tail --name ${WEBAPP} --resource-group ${RESOURCE_GROUP}"
echo "Logs do Oracle:       az container logs --name ${ACI_ORACLE} --resource-group ${RESOURCE_GROUP}"
