-- =====================================================================
-- script-bd.sql - DDL dos objetos do banco Oracle do Remembered
--
-- ARQUIVO GERADO por scripts/sincronizar-java-devops.sh (na casca do grupo)
-- a partir de gs-remembered-java@6303baf. Não edite à mão: mude a migration
-- no repositório Java ou o DDL NET_ da imagem e gere de novo.
--
-- Banco: Oracle Database Free no Azure Container Instances
--   rm566234-gs-oracle.eastus.azurecontainer.io:1521/FREEPDB1, schema REMEMBERED
--
-- Quem cria cada parte na nuvem:
--   - Tabelas TB_ (API Java), pacote pkg_adesao e trigger de auditoria: o
--     Flyway do Java, na partida do Web App (migrations V1 e V2, abaixo).
--   - Tabelas NET_ (API .NET): a imagem do Oracle, na primeira partida do
--     container (dockerfiles/oracle/sql/tabelas-net.sql, abaixo).
--
-- Para recriar o schema à mão em um banco limpo, rode este arquivo inteiro
-- no SQL*Plus ou no SQL Developer com o usuário da aplicação.
-- =====================================================================

-- ---------------------------------------------------------------------
-- Flyway: V1__schema_inicial.sql
-- ---------------------------------------------------------------------
-- Tabelas TB_ da API Java do Remembered. Todo registro de TB_USUARIO e um idoso.

CREATE TABLE TB_USUARIO (
    id                 NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nome               VARCHAR2(120) NOT NULL,
    email              VARCHAR2(160) NOT NULL,
    senha_hash         VARCHAR2(100) NOT NULL,
    push_token         VARCHAR2(200),
    codigo_pareamento  VARCHAR2(10),
    codigo_expira_em   TIMESTAMP,
    criado_em          TIMESTAMP DEFAULT SYSTIMESTAMP NOT NULL,
    CONSTRAINT uk_usuario_email  UNIQUE (email),
    CONSTRAINT uk_usuario_codigo UNIQUE (codigo_pareamento)
);

CREATE TABLE TB_MEDICAMENTO (
    id               NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    idoso_id         NUMBER NOT NULL,
    nome             VARCHAR2(120) NOT NULL,
    dosagem          VARCHAR2(60),
    forma            VARCHAR2(40),
    cor_icone        VARCHAR2(20),
    formato_icone    VARCHAR2(20),
    critico          CHAR(1) DEFAULT 'N' NOT NULL,
    limite_pulos     NUMBER(3) DEFAULT 3 NOT NULL,
    data_inicio      DATE NOT NULL,
    data_fim         DATE,
    ativo            CHAR(1) DEFAULT 'S' NOT NULL,
    observacoes      VARCHAR2(500),
    criado_por_tipo  VARCHAR2(10) NOT NULL,
    criado_por_nome  VARCHAR2(120) NOT NULL,
    CONSTRAINT fk_medicamento_idoso FOREIGN KEY (idoso_id) REFERENCES TB_USUARIO (id),
    CONSTRAINT ck_medicamento_critico CHECK (critico IN ('S', 'N')),
    CONSTRAINT ck_medicamento_ativo   CHECK (ativo IN ('S', 'N')),
    CONSTRAINT ck_medicamento_limite  CHECK (limite_pulos >= 1),
    CONSTRAINT ck_medicamento_criador CHECK (criado_por_tipo IN ('IDOSO', 'CUIDADOR', 'CHAT'))
);

CREATE TABLE TB_HORARIO_MEDICAMENTO (
    id              NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    medicamento_id  NUMBER NOT NULL,
    hora            VARCHAR2(5) NOT NULL,
    dias_semana     VARCHAR2(7) DEFAULT '1111111' NOT NULL,
    CONSTRAINT fk_horario_medicamento FOREIGN KEY (medicamento_id) REFERENCES TB_MEDICAMENTO (id) ON DELETE CASCADE,
    CONSTRAINT ck_horario_hora CHECK (REGEXP_LIKE(hora, '^([01][0-9]|2[0-3]):[0-5][0-9]$')),
    CONSTRAINT ck_horario_dias CHECK (REGEXP_LIKE(dias_semana, '^[01]{7}$'))
);

CREATE TABLE TB_REGISTRO_DOSE (
    id                NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    medicamento_id    NUMBER NOT NULL,
    horario_previsto  TIMESTAMP NOT NULL,
    status            VARCHAR2(10) DEFAULT 'PENDENTE' NOT NULL,
    confirmada_em     TIMESTAMP,
    origem            VARCHAR2(10),
    CONSTRAINT fk_dose_medicamento FOREIGN KEY (medicamento_id) REFERENCES TB_MEDICAMENTO (id) ON DELETE CASCADE,
    CONSTRAINT uk_dose_medicamento_horario UNIQUE (medicamento_id, horario_previsto),
    CONSTRAINT ck_dose_status CHECK (status IN ('PENDENTE', 'TOMADA', 'PULADA')),
    CONSTRAINT ck_dose_origem CHECK (origem IS NULL OR origem IN ('APP', 'CHAT', 'CUIDADOR'))
);

CREATE TABLE TB_AVISO (
    id               NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    idoso_id         NUMBER NOT NULL,
    tipo             VARCHAR2(12) NOT NULL,
    referencia_id    NUMBER,
    titulo           VARCHAR2(120) NOT NULL,
    resumo           VARCHAR2(300) NOT NULL,
    criado_por_nome  VARCHAR2(120) NOT NULL,
    criado_em        TIMESTAMP DEFAULT SYSTIMESTAMP NOT NULL,
    lido_em          TIMESTAMP,
    -- Idempotencia do consumidor: um aviso por evento recebido.
    evento_id        VARCHAR2(64) NOT NULL,
    CONSTRAINT fk_aviso_idoso FOREIGN KEY (idoso_id) REFERENCES TB_USUARIO (id),
    CONSTRAINT uk_aviso_evento UNIQUE (evento_id),
    CONSTRAINT ck_aviso_tipo CHECK (tipo IN ('MEDICAMENTO', 'CONSULTA'))
);

CREATE TABLE TB_RELATORIO_ADESAO (
    id                 NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    idoso_id           NUMBER NOT NULL,
    periodo_inicio     DATE NOT NULL,
    periodo_fim        DATE NOT NULL,
    percentual_adesao  NUMBER(5, 2),
    -- JSON com resumo, pontosDeAtencao e sugestaoParaFamilia. Nulo quando o LLM falhou.
    texto_llm          CLOB,
    -- JSON com os numeros calculados no Oracle (base do texto do LLM).
    dados_json         CLOB NOT NULL,
    gerado_em          TIMESTAMP DEFAULT SYSTIMESTAMP NOT NULL,
    CONSTRAINT fk_relatorio_idoso FOREIGN KEY (idoso_id) REFERENCES TB_USUARIO (id)
);

-- Sem chave estrangeira de proposito: o historico de auditoria sobrevive a exclusao do medicamento.
CREATE TABLE TB_AUDITORIA_MEDICAMENTO (
    id               NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    medicamento_id   NUMBER NOT NULL,
    operacao         VARCHAR2(10) NOT NULL,
    valores_antigos  VARCHAR2(1000),
    valores_novos    VARCHAR2(1000),
    usuario_bd       VARCHAR2(60) DEFAULT USER NOT NULL,
    data_hora        TIMESTAMP DEFAULT SYSTIMESTAMP NOT NULL
);

CREATE OR REPLACE TRIGGER trg_auditoria_medicamento
AFTER INSERT OR UPDATE OR DELETE ON TB_MEDICAMENTO
FOR EACH ROW
DECLARE
    v_operacao VARCHAR2(10);
BEGIN
    v_operacao := CASE WHEN INSERTING THEN 'INSERT' WHEN UPDATING THEN 'UPDATE' ELSE 'DELETE' END;

    INSERT INTO TB_AUDITORIA_MEDICAMENTO (medicamento_id, operacao, valores_antigos, valores_novos)
    VALUES (
        NVL(:NEW.id, :OLD.id),
        v_operacao,
        CASE WHEN INSERTING THEN NULL
             ELSE 'nome=' || :OLD.nome || ';dosagem=' || :OLD.dosagem || ';critico=' || :OLD.critico
                  || ';ativo=' || :OLD.ativo || ';limite_pulos=' || :OLD.limite_pulos END,
        CASE WHEN DELETING THEN NULL
             ELSE 'nome=' || :NEW.nome || ';dosagem=' || :NEW.dosagem || ';critico=' || :NEW.critico
                  || ';ativo=' || :NEW.ativo || ';limite_pulos=' || :NEW.limite_pulos END
    );
END;
/

-- ===== Indices =====
-- Cada indice atende uma consulta quente da API; sem eles viram varredura completa (O(n)) em vez de O(log n).

-- Lista de medicamentos do idoso (GET /idosos/{id}/medicamentos).
CREATE INDEX idx_medicamento_idoso ON TB_MEDICAMENTO (idoso_id);

-- Horarios de um medicamento (carregados junto com ele).
CREATE INDEX idx_horario_medicamento ON TB_HORARIO_MEDICAMENTO (medicamento_id);

-- Job de 60 s: doses PENDENTE vencidas. Comeca por status e ordena pelo horario.
CREATE INDEX idx_dose_status_horario ON TB_REGISTRO_DOSE (status, horario_previsto);

-- Doses do dia por medicamento e janela de adesao: o UNIQUE (medicamento_id, horario_previsto) ja cobre.

-- Avisos do idoso, mais recentes primeiro, com filtro por lido.
CREATE INDEX idx_aviso_idoso_criado ON TB_AVISO (idoso_id, criado_em DESC);

-- Historico de relatorios do idoso.
CREATE INDEX idx_relatorio_idoso_gerado ON TB_RELATORIO_ADESAO (idoso_id, gerado_em DESC);

-- ===== Pacote de adesao (PL/SQL) =====
-- Regras de calculo que ficam no Oracle (disciplina de banco): adesao e severidade do alerta.
CREATE OR REPLACE PACKAGE pkg_adesao AS
    -- Adesao (%) = TOMADA / (TOMADA + PULADA) no periodo [p_inicio, p_fim). PENDENTES nao entram.
    -- Retorna NULL quando nao ha doses encerradas no periodo.
    FUNCTION fn_percentual_adesao(p_medicamento_id IN NUMBER,
                                  p_inicio         IN TIMESTAMP,
                                  p_fim            IN TIMESTAMP) RETURN NUMBER;

    -- ALTA: medicamento critico. MEDIA: doses PULADA nos 7 dias ate a dose chegam a limite_pulos.
    -- NENHUM: demais casos (nao gera evento).
    FUNCTION fn_severidade_alerta(p_dose_id IN NUMBER) RETURN VARCHAR2;
END pkg_adesao;
/

CREATE OR REPLACE PACKAGE BODY pkg_adesao AS

    FUNCTION fn_percentual_adesao(p_medicamento_id IN NUMBER,
                                  p_inicio         IN TIMESTAMP,
                                  p_fim            IN TIMESTAMP) RETURN NUMBER IS
        v_tomadas NUMBER;
        v_puladas NUMBER;
    BEGIN
        SELECT NVL(SUM(CASE WHEN status = 'TOMADA' THEN 1 ELSE 0 END), 0),
               NVL(SUM(CASE WHEN status = 'PULADA' THEN 1 ELSE 0 END), 0)
          INTO v_tomadas, v_puladas
          FROM TB_REGISTRO_DOSE
         WHERE medicamento_id = p_medicamento_id
           AND horario_previsto >= p_inicio
           AND horario_previsto <  p_fim;

        IF v_tomadas + v_puladas = 0 THEN
            RETURN NULL;
        END IF;
        RETURN ROUND(100 * v_tomadas / (v_tomadas + v_puladas), 2);
    END fn_percentual_adesao;

    FUNCTION fn_severidade_alerta(p_dose_id IN NUMBER) RETURN VARCHAR2 IS
        v_critico  CHAR(1);
        v_limite   NUMBER;
        v_medicamento NUMBER;
        v_horario  TIMESTAMP;
        v_puladas  NUMBER;
    BEGIN
        SELECT m.critico, m.limite_pulos, m.id, d.horario_previsto
          INTO v_critico, v_limite, v_medicamento, v_horario
          FROM TB_REGISTRO_DOSE d
          JOIN TB_MEDICAMENTO m ON m.id = d.medicamento_id
         WHERE d.id = p_dose_id;

        IF v_critico = 'S' THEN
            RETURN 'ALTA';
        END IF;

        SELECT COUNT(*)
          INTO v_puladas
          FROM TB_REGISTRO_DOSE
         WHERE medicamento_id = v_medicamento
           AND status = 'PULADA'
           AND horario_previsto >  v_horario - INTERVAL '7' DAY
           AND horario_previsto <= v_horario;

        IF v_puladas >= v_limite THEN
            RETURN 'MEDIA';
        END IF;
        RETURN 'NENHUM';
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RETURN 'NENHUM';
    END fn_severidade_alerta;

END pkg_adesao;
/

-- ---------------------------------------------------------------------
-- Flyway: V2__corrige_trigger_auditoria.sql
-- ---------------------------------------------------------------------
-- A versao da V1 compila INVALID (ORA-00920): INSERTING e DELETING sao predicados de PL/SQL e
-- nao valem dentro do INSERT, que e SQL. Com o trigger invalido, todo INSERT/UPDATE/DELETE em
-- TB_MEDICAMENTO falha com ORA-04098. Aqui os valores sao montados em variaveis antes do INSERT.
-- A V1 fica intacta porque o Flyway ja gravou o checksum dela nos bancos onde rodou.
CREATE OR REPLACE TRIGGER trg_auditoria_medicamento
AFTER INSERT OR UPDATE OR DELETE ON TB_MEDICAMENTO
FOR EACH ROW
DECLARE
    v_operacao        VARCHAR2(10);
    v_valores_antigos VARCHAR2(1000);
    v_valores_novos   VARCHAR2(1000);
BEGIN
    IF INSERTING THEN
        v_operacao := 'INSERT';
    ELSIF UPDATING THEN
        v_operacao := 'UPDATE';
    ELSE
        v_operacao := 'DELETE';
    END IF;

    IF NOT INSERTING THEN
        v_valores_antigos := SUBSTR('nome=' || :OLD.nome || ';dosagem=' || :OLD.dosagem || ';critico=' || :OLD.critico
            || ';ativo=' || :OLD.ativo || ';limite_pulos=' || :OLD.limite_pulos, 1, 1000);
    END IF;

    IF NOT DELETING THEN
        v_valores_novos := SUBSTR('nome=' || :NEW.nome || ';dosagem=' || :NEW.dosagem || ';critico=' || :NEW.critico
            || ';ativo=' || :NEW.ativo || ';limite_pulos=' || :NEW.limite_pulos, 1, 1000);
    END IF;

    INSERT INTO TB_AUDITORIA_MEDICAMENTO (medicamento_id, operacao, valores_antigos, valores_novos)
    VALUES (NVL(:NEW.id, :OLD.id), v_operacao, v_valores_antigos, v_valores_novos);
END;
/

-- ---------------------------------------------------------------------
-- Imagem do Oracle: dockerfiles/oracle/sql/tabelas-net.sql
-- ---------------------------------------------------------------------
-- =====================================================================
-- Tabelas NET_ da API .NET (Cuidar de Perto), criadas pela imagem no
-- schema do APP_USER na primeira partida do container.
--
-- Origem: scripts/script-bd.sql do repositório gs-remembered-dotnet
-- (commit 0296cbf), sem as linhas de limpeza comentadas. Quando o .NET mudar o
-- DDL, copie a versão nova para cá e gere uma imagem nova.
--
-- IDOSO_ID é referência lógica a TB_USUARIO da API Java, sem chave
-- estrangeira, porque TB_USUARIO só existe depois que o Flyway do Java roda.
-- =====================================================================

CREATE TABLE NET_CUIDADOR (
    ID          NUMBER(19)     GENERATED BY DEFAULT ON NULL AS IDENTITY,
    NOME        VARCHAR2(120)  NOT NULL,
    EMAIL       VARCHAR2(150)  NOT NULL,
    SENHA_HASH  VARCHAR2(255)  NOT NULL,
    PUSH_TOKEN  VARCHAR2(255),
    CRIADO_EM   TIMESTAMP      DEFAULT SYS_EXTRACT_UTC(SYSTIMESTAMP) NOT NULL,
    CONSTRAINT PK_NET_CUIDADOR PRIMARY KEY (ID),
    CONSTRAINT UK_NET_CUIDADOR_EMAIL UNIQUE (EMAIL)
);

CREATE TABLE NET_VINCULO (
    ID           NUMBER(19)     GENERATED BY DEFAULT ON NULL AS IDENTITY,
    CUIDADOR_ID  NUMBER(19)     NOT NULL,
    IDOSO_ID     NUMBER(19)     NOT NULL,
    IDOSO_NOME   VARCHAR2(120)  NOT NULL,
    PARENTESCO   VARCHAR2(60),
    CRIADO_EM    TIMESTAMP      DEFAULT SYS_EXTRACT_UTC(SYSTIMESTAMP) NOT NULL,
    CONSTRAINT PK_NET_VINCULO PRIMARY KEY (ID),
    CONSTRAINT UK_NET_VINCULO UNIQUE (CUIDADOR_ID, IDOSO_ID),
    CONSTRAINT FK_NET_VINCULO_CUIDADOR FOREIGN KEY (CUIDADOR_ID) REFERENCES NET_CUIDADOR (ID) ON DELETE CASCADE
);
CREATE INDEX IX_NET_VINCULO_IDOSO ON NET_VINCULO (IDOSO_ID);

CREATE TABLE NET_ALERTA (
    ID                NUMBER(19)     GENERATED BY DEFAULT ON NULL AS IDENTITY,
    CUIDADOR_ID       NUMBER(19)     NOT NULL,
    IDOSO_ID          NUMBER(19)     NOT NULL,
    IDOSO_NOME        VARCHAR2(120)  NOT NULL,
    MEDICAMENTO_NOME  VARCHAR2(120)  NOT NULL,
    DOSE_ID           NUMBER(19)     NOT NULL,
    SEVERIDADE        VARCHAR2(10)   NOT NULL,
    MOTIVO            VARCHAR2(255)  NOT NULL,
    CRIADO_EM         TIMESTAMP      DEFAULT SYS_EXTRACT_UTC(SYSTIMESTAMP) NOT NULL,
    LIDO_EM           TIMESTAMP,
    CONSTRAINT PK_NET_ALERTA PRIMARY KEY (ID),
    CONSTRAINT UK_NET_ALERTA_DOSE UNIQUE (CUIDADOR_ID, DOSE_ID),
    CONSTRAINT CK_NET_ALERTA_SEVERIDADE CHECK (SEVERIDADE IN ('ALTA', 'MEDIA')),
    CONSTRAINT FK_NET_ALERTA_CUIDADOR FOREIGN KEY (CUIDADOR_ID) REFERENCES NET_CUIDADOR (ID) ON DELETE CASCADE
);

CREATE TABLE NET_LOCAL_ATENDIMENTO (
    ID               NUMBER(19)     GENERATED BY DEFAULT ON NULL AS IDENTITY,
    NOME             VARCHAR2(120)  NOT NULL,
    ENDERECO         VARCHAR2(255)  NOT NULL,
    TELEFONE         VARCHAR2(20),
    CRIADO_POR_TIPO  VARCHAR2(10)   NOT NULL,
    CRIADO_POR_ID    NUMBER(19)     NOT NULL,
    CONSTRAINT PK_NET_LOCAL_ATENDIMENTO PRIMARY KEY (ID),
    CONSTRAINT CK_NET_LOCAL_CRIADO_POR CHECK (CRIADO_POR_TIPO IN ('IDOSO', 'CUIDADOR'))
);

CREATE TABLE NET_CONSULTA (
    ID                 NUMBER(19)     GENERATED BY DEFAULT ON NULL AS IDENTITY,
    IDOSO_ID           NUMBER(19)     NOT NULL,
    LOCAL_ID           NUMBER(19)     NOT NULL,
    ESPECIALIDADE      VARCHAR2(100)  NOT NULL,
    DATA_HORA          TIMESTAMP      NOT NULL,
    STATUS             VARCHAR2(10)   DEFAULT 'AGENDADA' NOT NULL,
    OBSERVACOES        VARCHAR2(500),
    LEMBRAR_ANTES_MIN  NUMBER(5)      DEFAULT 60 NOT NULL,
    CRIADO_POR_TIPO    VARCHAR2(10)   NOT NULL,
    CRIADO_POR_NOME    VARCHAR2(120)  NOT NULL,
    CONSTRAINT PK_NET_CONSULTA PRIMARY KEY (ID),
    CONSTRAINT CK_NET_CONSULTA_STATUS CHECK (STATUS IN ('AGENDADA', 'REALIZADA', 'CANCELADA')),
    CONSTRAINT CK_NET_CONSULTA_LEMBRAR CHECK (LEMBRAR_ANTES_MIN BETWEEN 0 AND 10080),
    CONSTRAINT CK_NET_CONSULTA_CRIADO_POR CHECK (CRIADO_POR_TIPO IN ('IDOSO', 'CUIDADOR')),
    CONSTRAINT FK_NET_CONSULTA_LOCAL FOREIGN KEY (LOCAL_ID) REFERENCES NET_LOCAL_ATENDIMENTO (ID)
);
CREATE INDEX IX_NET_CONSULTA_IDOSO_DATA ON NET_CONSULTA (IDOSO_ID, DATA_HORA);
CREATE INDEX IX_NET_CONSULTA_LOCAL ON NET_CONSULTA (LOCAL_ID);

CREATE TABLE NET_IDEMPOTENCIA (
    USUARIO_ID   VARCHAR2(40)   NOT NULL,  -- "CUIDADOR:7" ou "IDOSO:10"
    CHAVE        VARCHAR2(100)  NOT NULL,
    HASH_CORPO   VARCHAR2(64)   NOT NULL,  -- SHA-256 em hexadecimal
    STATUS_CODE  NUMBER(3)      NOT NULL,
    RESPOSTA     CLOB           NOT NULL,
    CRIADO_EM    TIMESTAMP      DEFAULT SYS_EXTRACT_UTC(SYSTIMESTAMP) NOT NULL,
    CONSTRAINT PK_NET_IDEMPOTENCIA PRIMARY KEY (USUARIO_ID, CHAVE)
);
CREATE INDEX IX_NET_IDEMPOTENCIA_CRIADO ON NET_IDEMPOTENCIA (CRIADO_EM);

-- Um registro por eventId consumido do RabbitMQ (idempotência do consumidor de dose.pulada).
CREATE TABLE NET_EVENTO_PROCESSADO (
    EVENT_ID       VARCHAR2(64)  NOT NULL,
    PROCESSADO_EM  TIMESTAMP     DEFAULT SYS_EXTRACT_UTC(SYSTIMESTAMP) NOT NULL,
    CONSTRAINT PK_NET_EVENTO_PROCESSADO PRIMARY KEY (EVENT_ID)
);

-- Dados de exemplo (fictícios) para a demonstração do CRUD de locais.
INSERT INTO NET_LOCAL_ATENDIMENTO (NOME, ENDERECO, TELEFONE, CRIADO_POR_TIPO, CRIADO_POR_ID)
VALUES ('UBS Vila Mariana', 'Rua Domingos de Morais, 100 - São Paulo', '(11) 3333-0001', 'CUIDADOR', 0);
INSERT INTO NET_LOCAL_ATENDIMENTO (NOME, ENDERECO, TELEFONE, CRIADO_POR_TIPO, CRIADO_POR_ID)
VALUES ('Clínica Coração Saudável', 'Av. Paulista, 1000 - São Paulo', '(11) 3333-0002', 'CUIDADOR', 0);

COMMIT;
