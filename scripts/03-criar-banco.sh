#!/usr/bin/env bash
# =====================================================================
# ETAPA 3 - Sobe o banco Oracle no Azure Container Instances (ACI)
#
#   imagem gs-oracle do ACR  ->  container com IP público e porta 1521
#
# A imagem já cria o usuário da aplicação (DB_USER) e as tabelas NET_ da
# API .NET. As tabelas TB_ do Java são criadas pelo Flyway na partida do
# Web App.
#
# Segredos lidos do ambiente (arquivo .env local, nunca versionado):
#   ORACLE_PASSWORD  senha do SYS/SYSTEM (fica só com quem opera a infra)
#   DB_PASSWORD      senha do usuário da aplicação
# Eles chegam ao ACI como variáveis de ambiente SEGURAS, que o Portal e o
# "az container show" não exibem.
#
# O ACI não tem disco persistente: se o container reiniciar, o banco nasce
# de novo da imagem. Depois disso, rode 05-reiniciar-api.sh para o Flyway
# recriar as tabelas TB_ e os dados de teste.
# Pode ser executado de novo: o container existente é mantido.
# =====================================================================
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")"
source ./00-variaveis.sh

: "${ORACLE_PASSWORD:?Defina ORACLE_PASSWORD (senha do SYS) no ambiente ou no .env}"
: "${DB_PASSWORD:?Defina DB_PASSWORD (senha do usuário ${DB_USER}) no ambiente ou no .env}"

echo
echo "[1/2] Container ${ACI_ORACLE} (${ACI_CPU} vCPU, ${ACI_MEMORY} GB, ${LOCATION})..."
if az container show --name "${ACI_ORACLE}" --resource-group "${RESOURCE_GROUP}" -o none 2>/dev/null; then
  echo "      já existe; mantido."
else
  ACR_USUARIO=$(az acr credential show --name "${ACR_NAME}" --query username -o tsv)
  ACR_SENHA=$(az acr credential show --name "${ACR_NAME}" --query "passwords[0].value" -o tsv)
  az container create \
    --name "${ACI_ORACLE}" \
    --resource-group "${RESOURCE_GROUP}" \
    --location "${LOCATION}" \
    --image "${ORACLE_IMAGE}" \
    --registry-login-server "${ACR_NAME}.azurecr.io" \
    --registry-username "${ACR_USUARIO}" \
    --registry-password "${ACR_SENHA}" \
    --os-type Linux \
    --cpu "${ACI_CPU}" \
    --memory "${ACI_MEMORY}" \
    --ports "${ORACLE_PORT}" \
    --protocol TCP \
    --ip-address Public \
    --dns-name-label "${ACI_DNS_LABEL}" \
    --restart-policy Always \
    --environment-variables APP_USER="${DB_USER}" \
    --secure-environment-variables ORACLE_PASSWORD="${ORACLE_PASSWORD}" APP_USER_PASSWORD="${DB_PASSWORD}" \
    -o none
fi

echo "[2/2] Aguardando o Oracle ficar pronto (até 10 minutos)..."
for _ in $(seq 1 60); do
  if az container logs --name "${ACI_ORACLE}" --resource-group "${RESOURCE_GROUP}" 2>/dev/null \
       | grep -q "DATABASE IS READY TO USE"; then
    PRONTO="sim"
    echo "      banco pronto."
    az container logs --name "${ACI_ORACLE}" --resource-group "${RESOURCE_GROUP}" | grep "remembered:" || true
    break
  fi
  sleep 10
done

if [[ "${PRONTO:-nao}" != "sim" ]]; then
  echo "O Oracle não ficou pronto em 10 minutos. Veja o estado e os logs:"
  echo "  az container show --name ${ACI_ORACLE} --resource-group ${RESOURCE_GROUP} --query containers[0].instanceView"
  echo "  az container logs --name ${ACI_ORACLE} --resource-group ${RESOURCE_GROUP}"
  exit 1
fi

echo
echo "Pronto. Oracle em ${ORACLE_HOST}:${ORACLE_PORT}/${ORACLE_SERVICE} (usuário ${DB_USER})"
echo "DB_URL=${DB_URL_ORACLE}"
