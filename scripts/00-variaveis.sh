#!/usr/bin/env bash
# =====================================================================
# Variáveis compartilhadas pelos scripts de infraestrutura da GS.
# NÃO executa nada sozinho: é carregado com "source" pelos demais.
#
#   RM do representante do grupo: 566234 (João Guilherme Carvalho Novaes)
#
# Nenhum segredo fica aqui. Usuário e senha do banco vêm do ambiente
# (arquivo .env local, que nunca é versionado). Na nuvem, eles ficam no
# variable group protegido do Azure DevOps, e a Release os grava nas
# configurações do Web App a cada deploy.
# =====================================================================

export RM="rm566234"

# Região e Resource Group. A política "Allowed resource deployment regions"
# da assinatura Azure for Students só libera southafricanorth, brazilsouth,
# spaincentral, chilecentral e eastus.
export LOCATION="${LOCATION:-brazilsouth}"
# O banco pode ir para outra região permitida se a principal recusar o SQL Server.
export LOCATION_BANCO="${LOCATION_BANCO:-$LOCATION}"
export RESOURCE_GROUP="rg-${RM}-gs"

# App Service: plano Linux B1 (Always On, a JVM não dorme durante a correção)
export APP_SERVICE_PLAN="plan-${RM}-gs"
export APP_SERVICE_SKU="B1"

# Web App Java SE: a Release publica nele o .jar gerado pelo CI.
# O runtime acompanha a versão do Java do projeto (java.version no pom.xml).
export WEBAPP="${RM}-gs-api"
export WEBAPP_RUNTIME="${WEBAPP_RUNTIME:-JAVA:21-java21}"
# Caminho do OpenAPI usado para saber se a API está no ar (padrão do springdoc)
export API_DOCS_PATH="${API_DOCS_PATH:-/v3/api-docs}"

# Azure SQL (PaaS): servidor lógico e banco no plano Basic (5 DTU, sem pausa automática)
export SQL_SERVER="sql-${RM}-gs"
export SQL_DATABASE="db-gs"
export SQL_SERVICE_OBJECTIVE="Basic"
export SQL_HOST="${SQL_SERVER}.database.windows.net"
