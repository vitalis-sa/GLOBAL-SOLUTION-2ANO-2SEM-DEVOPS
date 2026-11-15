#!/bin/bash
# =====================================================================
# Executado uma vez pela imagem gvenzl/oracle-free na primeira partida do
# container, depois que o usuário APP_USER já existe no FREEPDB1.
#
# Cria as tabelas NET_ da API .NET no schema do APP_USER. As tabelas TB_
# do Java não entram aqui, porque o Flyway do Java as cria na partida do
# Web App e falharia ao encontrá-las prontas.
#
# A imagem pode executar este arquivo ou carregá-lo com "source" (quando o
# arquivo chega sem permissão de execução, como no build enviado do
# Windows). Por isso ele não usa "set -e" nem "exit": um erro aqui não pode
# derrubar o entrypoint, porque um reinício do container no ACI encontra a
# memória compartilhada da instância anterior e o Oracle não sobe mais.
# =====================================================================

if [ -z "${APP_USER:-}" ] || [ -z "${APP_USER_PASSWORD:-}" ]; then
  echo "remembered: ERRO - APP_USER ou APP_USER_PASSWORD não definido; tabelas NET_ não criadas."
else
  # O arquivo .sql é UTF-8 (há acentos nos dados de exemplo); sem isto o
  # SQL*Plus grava os acentos corrompidos.
  export NLS_LANG="AMERICAN_AMERICA.AL32UTF8"

  echo "remembered: criando as tabelas NET_ no schema ${APP_USER}..."
  if sqlplus -s -L "${APP_USER}/${APP_USER_PASSWORD}@//localhost/FREEPDB1" <<'SQL'
WHENEVER SQLERROR EXIT SQL.SQLCODE
SET ECHO OFF FEEDBACK OFF
@/opt/remembered/sql/tabelas-net.sql
SELECT 'remembered: ' || COUNT(*) || ' tabelas NET_ prontas' AS status
  FROM user_tables WHERE table_name LIKE 'NET\_%' ESCAPE '\';
EXIT
SQL
  then
    :
  else
    echo "remembered: ERRO ao criar as tabelas NET_ (veja as mensagens acima)."
  fi
fi
