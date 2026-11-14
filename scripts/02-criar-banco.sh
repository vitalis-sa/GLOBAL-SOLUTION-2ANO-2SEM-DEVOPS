#!/usr/bin/env bash
# =====================================================================
# ETAPA 2 - Cria o banco de dados em nuvem (Azure SQL, PaaS)
#
#   SQL Server  ->  banco Basic  ->  regras de firewall
#
# Requer, no ambiente, o login e a senha de administrador do banco:
#   set -a; source .env; set +a      (na raiz do repositório; o .env nunca é versionado)
# A senha precisa de maiúscula, minúscula, número e símbolo, sem ; ' " ou $.
#
# Pode ser executado de novo: servidor e banco existentes são mantidos,
# e a regra "operador" é atualizada com o IP público atual.
# O schema é criado depois, por 03-aplicar-ddl.sh.
# =====================================================================
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")"
source ./00-variaveis.sh

: "${DB_USER:?Defina DB_USER (login de administrador do banco) no .env}"
: "${DB_PASSWORD:?Defina DB_PASSWORD (senha do administrador do banco) no .env}"

echo
echo "[1/4] SQL Server ${SQL_SERVER} (${LOCATION_BANCO})..."
if az sql server show --name "${SQL_SERVER}" --resource-group "${RESOURCE_GROUP}" -o none 2>/dev/null; then
  echo "      já existe; mantido."
else
  az sql server create \
    --name "${SQL_SERVER}" \
    --resource-group "${RESOURCE_GROUP}" \
    --location "${LOCATION_BANCO}" \
    --admin-user "${DB_USER}" \
    --admin-password "${DB_PASSWORD}" \
    --minimal-tls-version 1.2 \
    -o none
fi

echo "[2/4] Banco ${SQL_DATABASE} (${SQL_SERVICE_OBJECTIVE})..."
if az sql db show --name "${SQL_DATABASE}" --server "${SQL_SERVER}" --resource-group "${RESOURCE_GROUP}" -o none 2>/dev/null; then
  echo "      já existe; mantido."
else
  az sql db create \
    --name "${SQL_DATABASE}" \
    --server "${SQL_SERVER}" \
    --resource-group "${RESOURCE_GROUP}" \
    --service-objective "${SQL_SERVICE_OBJECTIVE}" \
    --backup-storage-redundancy Local \
    -o none
fi

# 0.0.0.0 é a regra especial "Allow Azure services": libera o Web App.
echo "[3/4] Firewall: serviços do Azure (Web App)..."
az sql server firewall-rule create \
  --server "${SQL_SERVER}" \
  --resource-group "${RESOURCE_GROUP}" \
  --name AllowAzureServices \
  --start-ip-address 0.0.0.0 \
  --end-ip-address 0.0.0.0 \
  -o none

# Libera o computador de quem roda o script, para o sqlcmd e o SELECT do vídeo.
IP_OPERADOR=$(curl -s --max-time 20 https://api.ipify.org)
echo "[4/4] Firewall: IP do operador (${IP_OPERADOR})..."
az sql server firewall-rule create \
  --server "${SQL_SERVER}" \
  --resource-group "${RESOURCE_GROUP}" \
  --name operador \
  --start-ip-address "${IP_OPERADOR}" \
  --end-ip-address "${IP_OPERADOR}" \
  -o none

echo
echo "Pronto. Servidor: ${SQL_HOST}"
echo "DB_URL para o .env e para o variable group (sem segredos):"
echo "jdbc:sqlserver://${SQL_HOST}:1433;database=${SQL_DATABASE};encrypt=true;trustServerCertificate=false;hostNameInCertificate=*.database.windows.net;loginTimeout=30;"
