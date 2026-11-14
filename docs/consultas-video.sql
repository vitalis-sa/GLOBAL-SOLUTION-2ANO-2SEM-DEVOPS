-- =====================================================================
-- SELECTs de evidência do CRUD do vídeo (Azure SQL, banco db-gs).
-- Rode cada bloco no Query editor do Portal Azure logo depois da
-- chamada correspondente em docs/demo-crud.http.
-- A penalidade 15 do enunciado exige SELECT no banco, e não GET na API.
-- =====================================================================

-- Tabelas criadas pelo scripts/script-bd.sql
SELECT name AS tabela, create_date AS criada_em
  FROM sys.tables
 ORDER BY name;

-- ---------------------------------------------------------------------
-- CRUD 1 - TABELA 1 (⏳ PENDENTE (src): nome da tabela e colunas)
-- ---------------------------------------------------------------------
-- Depois de 1.1 (inserir) e 1.3 (atualizar): a linha aparece / muda.
-- Depois de 1.4 (deletar): a consulta volta vazia.
-- SELECT ... FROM ... WHERE ...;

-- ---------------------------------------------------------------------
-- CRUD 2 - TABELA 2 (⏳ PENDENTE (src): nome da tabela e colunas)
-- ---------------------------------------------------------------------
-- Depois de 2.1 (inserir) e 2.3 (atualizar): a linha aparece / muda.
-- Depois de 2.4 (deletar): a consulta volta vazia.
-- SELECT ... FROM ... WHERE ...;
