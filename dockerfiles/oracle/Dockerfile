# =====================================================================
# Oracle Database Free (23ai) do Remembered, executado no Azure
# Container Instances (ACI) a partir do Azure Container Registry (ACR).
#
# Base: gvenzl/oracle-free, variante "slim-faststart", que já traz o banco
# criado dentro da imagem e sobe em cerca de um minuto. Ela cria o usuário
# da aplicação a partir das variáveis APP_USER e APP_USER_PASSWORD e roda
# os scripts de /container-entrypoint-initdb.d na primeira partida.
#
# O que esta imagem acrescenta à base:
#   - as tabelas NET_ da API .NET, criadas no schema do APP_USER;
#   - nada das tabelas TB_ do Java: elas são criadas pelo Flyway na partida
#     do Web App, como no desenvolvimento local.
#
# O ACI não tem disco persistente. A cada partida do container, o banco
# nasce da imagem, e o script de inicialização recria as tabelas NET_.
#
# Build (a partir da raiz do repositório, pelo script 02-criar-registro.sh):
#   az acr build --registry <acr> --image gs-oracle:<versão> dockerfiles/oracle
#
# Nenhuma senha fica nesta imagem: ORACLE_PASSWORD, APP_USER e
# APP_USER_PASSWORD chegam como variáveis de ambiente seguras do ACI.
# =====================================================================
FROM gvenzl/oracle-free:23-slim-faststart

LABEL org.opencontainers.image.title="gs-oracle" \
      org.opencontainers.image.description="Oracle Free do Remembered (GS 2026/2) com as tabelas NET_ da API .NET"

COPY sql/ /opt/remembered/sql/
COPY initdb/ /container-entrypoint-initdb.d/
