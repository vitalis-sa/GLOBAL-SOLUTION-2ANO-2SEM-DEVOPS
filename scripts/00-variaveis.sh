#!/usr/bin/env bash
# =====================================================================
# Variáveis compartilhadas pelos scripts de infraestrutura da GS.
# NÃO executa nada sozinho: é carregado com "source" pelos demais.
#
#   RM do representante do grupo: 566234 (João Guilherme Carvalho Novaes)
#
# Nenhum segredo fica aqui. As senhas do Oracle (ORACLE_PASSWORD, do SYS,
# e DB_PASSWORD, do usuário da aplicação) vêm do ambiente (arquivo .env
# local, que nunca é versionado). Na nuvem, os segredos da aplicação ficam
# no variable group protegido do Azure DevOps, e a Release os grava nas
# configurações do Web App a cada deploy.
# =====================================================================

export RM="rm566234"

# Região e Resource Group. A política "Allowed resource deployment regions"
# da assinatura Azure for Students só libera southafricanorth, brazilsouth,
# spaincentral, chilecentral e eastus. Em eastus, o ACI custa metade do
# preço de brazilsouth, e o Web App fica na mesma região do banco.
export LOCATION="${LOCATION:-eastus}"
export RESOURCE_GROUP="rg-${RM}-gs"

# App Service: plano Linux B1 (Always On, a JVM não dorme durante a correção)
export APP_SERVICE_PLAN="plan-${RM}-gs"
export APP_SERVICE_SKU="B1"

# Web App Java SE: a Release publica nele o .jar gerado pelo CI.
# O runtime acompanha a versão do Java do projeto (java.version no pom.xml).
export WEBAPP="${RM}-gs-api"
export WEBAPP_RUNTIME="${WEBAPP_RUNTIME:-JAVA:21-java21}"
# Caminhos usados para saber se a API está no ar (springdoc e actuator do projeto)
export API_DOCS_PATH="${API_DOCS_PATH:-/api-docs}"
export HEALTH_PATH="${HEALTH_PATH:-/actuator/health}"

# Azure Container Registry: guarda a imagem do Oracle construída a partir de
# dockerfiles/oracle. O nome aceita só letras minúsculas e números.
export ACR_NAME="acr${RM}gs"
export ACR_SKU="Basic"
export ORACLE_IMAGE_NAME="gs-oracle"
export ORACLE_IMAGE_TAG="${ORACLE_IMAGE_TAG:-1.1}"
export ORACLE_IMAGE="${ACR_NAME}.azurecr.io/${ORACLE_IMAGE_NAME}:${ORACLE_IMAGE_TAG}"

# Azure Container Instances: Oracle Database Free (23ai) com IP público.
# 1 vCPU e 3 GB cabem no Oracle Free (que usa no máximo 2 GB de RAM) e no
# crédito da assinatura até o fim da correção.
export ACI_ORACLE="aci-${RM}-oracle"
export ACI_DNS_LABEL="${RM}-gs-oracle"
export ACI_CPU="1"
export ACI_MEMORY="3"
export ORACLE_PORT="1521"
export ORACLE_SERVICE="FREEPDB1"
export ORACLE_HOST="${ACI_DNS_LABEL}.${LOCATION}.azurecontainer.io"
# Usuário (schema) da aplicação, compartilhado pelas APIs Java e .NET
export DB_USER="${DB_USER:-REMEMBERED}"
export DB_URL_ORACLE="jdbc:oracle:thin:@//${ORACLE_HOST}:${ORACLE_PORT}/${ORACLE_SERVICE}"
