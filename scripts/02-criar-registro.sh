#!/usr/bin/env bash
# =====================================================================
# ETAPA 2 - Cria o Azure Container Registry e publica a imagem do Oracle
#
#   ACR (Basic)  ->  build de dockerfiles/oracle  ->  gs-oracle:<versão>
#
# O build roda na própria Azure (az acr build), sem precisar de Docker na
# máquina. Se a assinatura não permitir ACR Tasks, o script usa o Docker
# local para construir e enviar a mesma imagem.
# Requer Azure CLI com "az login" na assinatura do grupo.
# Pode ser executado de novo: o registro existente é mantido, e a imagem
# com a mesma versão é reconstruída.
# =====================================================================
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")"
source ./00-variaveis.sh

CONTEXTO="../dockerfiles/oracle"

echo
echo "[1/3] Container Registry ${ACR_NAME} (${ACR_SKU}, ${LOCATION})..."
if az acr show --name "${ACR_NAME}" --resource-group "${RESOURCE_GROUP}" -o none 2>/dev/null; then
  echo "      já existe; mantido."
else
  # O usuário admin permite que o ACI baixe a imagem com usuário e senha do registro.
  az acr create \
    --name "${ACR_NAME}" \
    --resource-group "${RESOURCE_GROUP}" \
    --location "${LOCATION}" \
    --sku "${ACR_SKU}" \
    --admin-enabled true \
    -o none
fi

echo "[2/3] Build da imagem ${ORACLE_IMAGE_NAME}:${ORACLE_IMAGE_TAG} a partir de dockerfiles/oracle..."
if az acr build \
     --registry "${ACR_NAME}" \
     --image "${ORACLE_IMAGE_NAME}:${ORACLE_IMAGE_TAG}" \
     "${CONTEXTO}"; then
  echo "      build feito na Azure (ACR Tasks)."
else
  echo "      ACR Tasks indisponível nesta assinatura; usando o Docker local."
  az acr login --name "${ACR_NAME}"
  docker build -t "${ORACLE_IMAGE}" "${CONTEXTO}"
  docker push "${ORACLE_IMAGE}"
fi

echo "[3/3] Imagens publicadas no registro:"
az acr repository show-tags \
  --name "${ACR_NAME}" \
  --repository "${ORACLE_IMAGE_NAME}" \
  -o table

echo
echo "Pronto. Imagem: ${ORACLE_IMAGE}"
