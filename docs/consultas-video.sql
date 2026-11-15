-- =====================================================================
-- SELECTs de evidência do CRUD do vídeo (Oracle no Azure Container
-- Instances, serviço FREEPDB1, usuário REMEMBERED).
-- Rode cada bloco no SQL Developer logo depois da chamada correspondente
-- em docs/demo-crud.http.
-- A penalidade 15 do enunciado exige SELECT no banco, e não GET na API.
-- =====================================================================

-- Tabelas do schema: TB_ (criadas pelo Flyway da API) e NET_ (criadas pela imagem)
SELECT table_name AS tabela, num_rows AS linhas_estimadas
  FROM user_tables
 ORDER BY table_name;

-- ---------------------------------------------------------------------
-- CRUD 1 - TB_MEDICAMENTO (e os horários em TB_HORARIO_MEDICAMENTO)
-- ---------------------------------------------------------------------
-- Depois de 1.1 (inserir): a linha e o horário 09:00 aparecem.
-- Depois de 1.3 (atualizar): a dosagem vira 2000 UI e o horário, 13:00.
-- Depois de 1.4 (deletar): as duas consultas voltam vazias.
SELECT m.id, m.nome, m.dosagem, m.forma, m.observacoes, u.email AS idoso
  FROM tb_medicamento m
  JOIN tb_usuario u ON u.id = m.idoso_id
 WHERE m.nome = 'Vitamina D';

SELECT h.medicamento_id, h.hora, h.dias_semana
  FROM tb_horario_medicamento h
  JOIN tb_medicamento m ON m.id = h.medicamento_id
 WHERE m.nome = 'Vitamina D';

-- O trigger de auditoria registra cada INSERT, UPDATE e DELETE do medicamento
SELECT operacao, valores_novos, data_hora
  FROM tb_auditoria_medicamento
 ORDER BY id DESC
 FETCH FIRST 3 ROWS ONLY;

-- ---------------------------------------------------------------------
-- CRUD 2 - TB_USUARIO
-- ---------------------------------------------------------------------
-- Depois de 2.1 (inserir): a conta aparece (a senha só existe como hash BCrypt).
-- Depois de 2.3 (atualizar): o nome vira "Antônio Carlos Pereira".
-- Depois de 2.4 (deletar): a consulta volta vazia.
SELECT id, nome, email, criado_em
  FROM tb_usuario
 WHERE email = 'antonio.demo@teste.dev';
