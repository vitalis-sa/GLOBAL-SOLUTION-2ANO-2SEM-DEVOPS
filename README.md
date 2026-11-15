# Vitalis · API de lembretes de medicação com CI/CD no Azure DevOps 💊

Este repositório é a entrega de **DevOps Tools & Cloud Computing** da **Global Solution 2026/2** (FIAP, 2º ano de ADS) do grupo **Vitalis**. Ele leva a API Java da solução do grupo, uma plataforma de lembretes de medicação para idosos, para uma esteira de CI/CD no **Azure DevOps**:

- a infraestrutura em nuvem (Web App, **Azure Container Registry** e o banco **Oracle em container no Azure Container Instances**) é criada por **scripts Azure CLI** versionados em [`scripts/`](scripts/);
- o código vive no **Azure Repos**, com a branch `main` protegida, e cada mudança nasce de uma Task do **Azure Boards** e entra por pull request;
- cada merge na `main` dispara o **CI**, que compila, roda os testes automatizados e publica o artefato;
- cada novo artefato dispara a **Release**, que faz o deploy automático no **Azure Web App**.

A API publicada aqui é o **backend de produção do grupo**: o app Mobile e a API .NET da solução consomem este Web App, que fica no ar com todas as integrações ligadas (banco Oracle, fila RabbitMQ, IA generativa e push).

> O código-fonte em [`src/`](src/) é um snapshot de [`vitalis-sa/gs-remembered-java`](https://github.com/vitalis-sa/gs-remembered-java), a API da disciplina Java Advanced, na versão `6303baf`. Cada versão nova do Java entra neste repositório por uma Task, uma branch e um pull request.

---

## 👥 Integrantes

| RM | Nome completo | Turma |
|:---:|:---|:---:|
| RM561489 | Ana Flávia Camelo | 2TDSPV |
| RM562745 | Gustavo Kenji Terada | 2TDSPV |
| RM566234 | João Guilherme Carvalho Novaes | 2TDSPV |
| RM565154 | Pedro Chasci Puga | 2TDSPV |
| RM561342 | Lucas Figueiredo Vieira | 2TDSPV |

## 🔗 Links da entrega

| Item | Link |
|---|---|
| Projeto no Azure DevOps | https://dev.azure.com/RM565154/GS%202026-2%20-%20DevOps |
| Azure Repos (origem do código) | https://dev.azure.com/RM565154/GS%202026-2%20-%20DevOps/_git/gs-devops |
| Espelho público no GitHub | https://github.com/vitalis-sa/GLOBAL-SOLUTION-2ANO-2SEM-DEVOPS |
| Vídeo no YouTube | ⏳ PENDENTE: link do vídeo |
| API publicada (Swagger UI) | https://rm566234-gs-api.azurewebsites.net/swagger-ui.html |

---

## 1. 📝 Descrição da solução

Idosos que usam vários medicamentos ao mesmo tempo esquecem doses, tomam a mesma dose duas vezes ou confundem horários, e quem cuida deles normalmente só descobre a falha depois que ela teve consequência. A solução do grupo Vitalis é uma plataforma de lembretes de medicação: no horário de cada dose, o idoso recebe um lembrete e registra um check-in, e familiares e profissionais de saúde são avisados quando uma dose não é confirmada.

| Ator | Papel |
|---|---|
| Idoso | Recebe os lembretes, confirma as doses e gera o código que vincula um cuidador |
| Cuidador (familiar ou profissional) | Acompanha a adesão, recebe alertas de dose pulada e pede relatórios de adesão |

A solução atende principalmente ao **ODS 3 (Saúde e bem-estar)**, porque atua sobre a adesão ao tratamento, e ao **ODS 10 (Redução das desigualdades)**, porque amplia a autonomia de um público que costuma ficar à margem das soluções digitais. Todos os dados usados em testes, exemplos e vídeo são fictícios, já que dados de saúde são dados pessoais sensíveis pela LGPD.

A API Java atende o idoso: medicamentos e horários, agenda de doses, avisos, pareamento com o cuidador e relatório de adesão escrito por IA generativa. Ela publica eventos (dose pulada, medicamento criado) numa fila RabbitMQ consumida também pela API .NET do cuidador, e as duas APIs dividem o mesmo banco Oracle e o mesmo segredo JWT.

### Stack

| Camada | Tecnologia |
|---|---|
| Aplicação | Java 21 e Spring Boot 4.1 (Spring Web, Spring Security com JWT, Bean Validation, springdoc-openapi 3) |
| Persistência | Spring Data JPA (Hibernate) com o driver Oracle `ojdbc17`; o **Flyway** cria o schema na partida (`ddl-auto=validate`) |
| Banco de dados em nuvem | **Oracle AI Database 26ai Free** em container, com a imagem no **Azure Container Registry** e a execução no **Azure Container Instances** |
| Integrações | RabbitMQ no CloudAMQP (opção A de arquitetura distribuída), IA generativa com Spring AI 2 e Groq, e push do Expo |
| Build e testes | Maven (wrapper `mvnw`), JUnit 5, AssertJ e Mockito: 36 testes em 13 classes |
| Planejamento | **Azure Boards** (processo Scrum) |
| Versionamento | **Azure Repos** (origem, `main` protegida) e espelho público no GitHub |
| CI/CD | **Azure Pipelines**: CI em YAML ([`azure-pipeline.yml`](azure-pipeline.yml)), CD em Release clássica e Library (variable group protegido) |
| Nuvem | **Azure App Service** (Web App Linux, Java 21 SE, plano B1), **ACR** e **ACI**, região East US |
| Infraestrutura como script | **Azure CLI** em bash ([`scripts/`](scripts/)) e Dockerfile do banco em [`dockerfiles/`](dockerfiles/) |

---

## 2. 🏗️ Arquitetura macro e fluxo CI/CD

![Arquitetura macro e fluxo CI/CD do grupo Vitalis](docs/arquitetura-devops.png)

> Versão vetorial: [`docs/arquitetura-devops.svg`](docs/arquitetura-devops.svg).

Fluxo numerado (os mesmos números do desenho):

0. Os **scripts Azure CLI** criam o Resource Group, o plano B1, o Web App, o **Container Registry** (com o build da imagem do Oracle a partir de [`dockerfiles/oracle`](dockerfiles/oracle/)) e o **Container Instance** do Oracle.
1. O desenvolvedor cria a **Task** no Azure Boards.
2. A **branch** é criada a partir da Task, no Azure Repos, e fica vinculada a ela.
3. O desenvolvedor faz o **commit** (com `#id` da Task) e o push da branch.
4. O **pull request** passa pelas políticas da `main` (revisor obrigatório, work item vinculado e revisor padrão), e o merge dispara o CI.
5. O Maven **compila e roda os testes** (aba Tests), e o `.jar` é publicado como artefato **`gs-jar`**.
6. O novo artefato dispara a **Release clássica `gs-cd`** (gatilho de implantação contínua).
7. A Release lê o variable group **`gs-segredos`**, publica o `.jar` no Web App com as app settings e roda o **smoke test**.
8. A API conecta no **Oracle do ACI** por JDBC (porta 1521), e o **Flyway** cria as tabelas `TB_` na partida.
9. O **app Mobile**, a **API .NET** e o **Swagger** consomem a API por HTTPS.
10. O operador comprova a persistência de cada operação com **`SELECT`** no SQL Developer.

| Ferramenta | Onde atua | Passos |
|---|---|---|
| Azure CLI | Provisionamento da infraestrutura e build da imagem do banco | 0 |
| Azure Boards | Tasks vinculadas a branches, commits e PRs | 1–2 |
| Azure Repos | Código, branches, políticas da `main` e pull requests | 2–4 |
| Azure Pipelines (CI) | Build, testes e artefato | 4–5 |
| Azure Releases (CD) | Deploy automático no Web App e smoke test | 6–7 |
| Azure DevOps Library | Variable group com os segredos protegidos | 7 |
| Azure App Service (Web App) | Hospeda a API Java 21 | 7–9 |
| Azure Container Registry | Guarda a imagem `gs-oracle` | 0 |
| Azure Container Instances | Executa o banco Oracle | 8, 10 |
| GitHub | Espelho público da `main` | — |

---

## 3. ☁️ Infraestrutura criada por script (Azure CLI)

Todos os recursos de nuvem são criados pelos scripts de [`scripts/`](scripts/), e o Build e a Release usam esses recursos.

| Recurso | Nome | Configuração | Script |
|---|---|---|---|
| Resource Group | `rg-rm566234-gs` | `eastus` | `01-criar-app.sh` |
| App Service Plan | `plan-rm566234-gs` | Linux, B1 | `01-criar-app.sh` |
| Web App | `rm566234-gs-api` | Java 21 SE, Always On, só HTTPS, FTP desligado, logs em arquivo | `01-criar-app.sh` |
| Container Registry | `acrrm566234gs` | Basic, usuário admin para o ACI baixar a imagem | `02-criar-registro.sh` |
| Imagem do banco | `gs-oracle:1.1` | Build no próprio ACR (`az acr build`) a partir de [`dockerfiles/oracle/Dockerfile`](dockerfiles/oracle/Dockerfile) | `02-criar-registro.sh` |
| Container Instance | `aci-rm566234-oracle` | 1 vCPU, 3 GB, IP público com DNS `rm566234-gs-oracle.eastus.azurecontainer.io`, porta 1521, reinício automático | `03-criar-banco.sh` |

| Script | O que faz |
|---|---|
| [`00-variaveis.sh`](scripts/00-variaveis.sh) | Nomes dos recursos e região, centralizados e sem segredos (carregado com `source` pelos demais) |
| [`01-criar-app.sh`](scripts/01-criar-app.sh) | Cria o Resource Group, o plano B1 e o Web App, e aplica a configuração geral |
| [`02-criar-registro.sh`](scripts/02-criar-registro.sh) | Cria o ACR e faz o build da imagem do Oracle no próprio registro |
| [`03-criar-banco.sh`](scripts/03-criar-banco.sh) | Sobe o Oracle no ACI, com as senhas em variáveis de ambiente seguras, e espera o banco ficar pronto |
| [`04-status.sh`](scripts/04-status.sh) | Mostra os recursos, a saúde da API, as imagens do ACR e o estado do container (só leitura) |
| [`05-reiniciar-api.sh`](scripts/05-reiniciar-api.sh) | Reinicia o Web App depois de um reinício do container do banco, para o Flyway recriar o schema |
| [`99-limpar.sh`](scripts/99-limpar.sh) | Apaga o Resource Group inteiro, com confirmação |

Os scripts podem ser executados de novo: recursos existentes são mantidos. A assinatura Azure for Students só permite as regiões `southafricanorth`, `brazilsouth`, `spaincentral`, `chilecentral` e `eastus`; a escolhida é `eastus`, onde o Container Instances custa metade do preço de `brazilsouth`, e o Web App fica na mesma região do banco.

---

## 4. 🗄️ Banco de dados em nuvem: Oracle em container (ACR + ACI)

O banco é um **Oracle AI Database 26ai Free** executado no **Azure Container Instances**, a partir de uma imagem construída e guardada no **Azure Container Registry**. O Oracle foi mantido porque a API usa PL/SQL (o pacote `pkg_adesao` e o trigger de auditoria), que o Azure SQL não executaria. O Oracle como serviço PaaS no Azure (Oracle Database@Azure) não está disponível na assinatura Azure for Students.

**A imagem** ([`dockerfiles/oracle/Dockerfile`](dockerfiles/oracle/Dockerfile)) parte de `gvenzl/oracle-free:23-slim-faststart`, que sobe em cerca de um minuto, e:

- cria o usuário da aplicação (`REMEMBERED`) a partir das variáveis `APP_USER` e `APP_USER_PASSWORD`;
- na primeira partida, roda [`initdb/01-tabelas-net.sh`](dockerfiles/oracle/initdb/01-tabelas-net.sh), que cria as tabelas `NET_` da API .NET;
- não guarda senha nenhuma: o `03-criar-banco.sh` as passa ao ACI como variáveis seguras, que o Portal não exibe.

**Quem cria cada objeto:**

| Objetos | Quem cria | Quando |
|---|---|---|
| Usuário `REMEMBERED` e tabelas `NET_` (API .NET) | A imagem do Oracle | Primeira partida do container |
| Tabelas `TB_`, pacote `pkg_adesao` e trigger `trg_auditoria_medicamento` | Flyway da API Java (migrations V1 e V2) | Partida do Web App |
| Usuários e medicamentos de teste, fictícios | Flyway (migration V3) | Partida do Web App |

O DDL completo de todos os objetos está em [`scripts/script-bd.sql`](scripts/script-bd.sql), que roda em um schema limpo e cria 14 tabelas, o pacote e o trigger.

| Tabela | Conteúdo | Relacionamento |
|---|---|---|
| `TB_USUARIO` | Idoso: nome, e-mail, hash da senha, token de push e código de pareamento | — |
| `TB_MEDICAMENTO` | Medicamento do idoso: nome, dosagem, forma, criticidade e vigência | → `TB_USUARIO` |
| `TB_HORARIO_MEDICAMENTO` | Horários e dias da semana de cada medicamento | → `TB_MEDICAMENTO` (cascata) |
| `TB_REGISTRO_DOSE` | Agenda de doses e confirmação (pendente, tomada ou pulada) | → `TB_MEDICAMENTO` (cascata) |
| `TB_AVISO` | Avisos para o idoso, gerados pelos eventos da fila | → `TB_USUARIO` |
| `TB_RELATORIO_ADESAO` | Relatórios de adesão com o texto da IA | → `TB_USUARIO` |
| `TB_AUDITORIA_MEDICAMENTO` | Trilha de auditoria gravada pelo trigger | — |
| `NET_*` (7 tabelas) | Cuidador, vínculo, alerta, consulta, local de atendimento, idempotência e eventos processados | Referência lógica a `TB_USUARIO` |

**Sem disco persistente.** O ACI não guarda dados quando o container reinicia. Nesse caso, o banco volta só com o usuário e as tabelas `NET_`, e o [`05-reiniciar-api.sh`](scripts/05-reiniciar-api.sh) reinicia o Web App para o Flyway recriar as tabelas `TB_` e os dados de teste.

---

## 5. ⚙️ Projeto no Azure DevOps

| Campo | Valor |
|---|---|
| Organização | `RM565154` |
| Project name | `GS 2026-2 - DevOps` |
| Description | Projeto da Global Solution 2026/2 (DevOps Tools & Cloud Computing) do professor João Menk, com os integrantes RM, nome e turma |
| Visibility | Private |
| Version control | Git |
| Work item process | Scrum |

**Acesso do professor:** o professor João Menk tem nível de acesso **Basic** na organização (Organization Settings › Users) e está no grupo **Project Administrators** do projeto (Project Settings › Permissions).

---

## 6. 📋 Azure Boards e Azure Repos

O trabalho é planejado no Azure Boards e cada mudança no código fica rastreável até a Task que a originou.

| Work item | Tipo | Título |
|---|---|---|
| 302 | Product Backlog Item | Implantar a API na nuvem com CI/CD |
| 303 | Task (tarefa inicial) | Importar o snapshot do Java para o Azure Repos |
| 304 | Task | Provisionar a infraestrutura por Azure CLI |
| 305 | Task | Provisionar o banco Oracle em container (ACR + ACI) |
| 306 | Task | Criar o pipeline de CI |
| 307 | Task | Criar a Release de CD |
| 308 | Task | Documentar o README e a arquitetura |

Fluxo de trabalho de cada mudança:

1. A Task é criada no Boards.
2. A branch é criada a partir da própria Task (*Create branch*), o que já cria o vínculo.
3. Os commits citam a Task com `#id` na mensagem.
4. O pull request para a `main` é vinculado à Task, aprovado e mesclado.
5. A Task mostra, na seção *Development*, a branch, os commits, o PR e o build.

### Políticas da branch `main`

| Política (Branch policies) | Configuração |
|---|---|
| Require a minimum number of reviewers | 1 revisor, com *Allow requestors to approve their own changes* (o aluno pode aprovar o próprio PR) |
| Check for linked work items | Required: todo PR precisa de work item vinculado |
| Automatically included reviewers | RM566234 como revisor padrão obrigatório |

Com as políticas ativas, ninguém faz push direto na `main`: o único caminho é o merge de um PR, e é esse merge que dispara o CI. A `main` é espelhada no GitHub público depois de cada merge.

---

## 7. 🚀 Pipelines CI/CD

### CI: build, testes e artefato ([`azure-pipeline.yml`](azure-pipeline.yml))

Pipeline YAML `gs-ci`, ligada ao repositório `gs-devops` do Azure Repos. Ela dispara a cada commit na `main` (`trigger: main`) e não roda em PR (`pr: none`).

| Task | O que faz |
|---|---|
| `Maven@4` (`clean package`) | Compila com JDK 21, **roda os 36 testes automatizados** e empacota o `.jar` |
| ↳ `publishJUnitResults` | Publica os relatórios JUnit (`surefire-reports`) na aba **Tests** |
| `CopyFiles@2` | Separa o `.jar` executável em `$(Build.ArtifactStagingDirectory)` |
| `PublishPipelineArtifact@1` | **Publica o artefato `gs-jar`** no Azure DevOps |

| Variável da pipeline | Valor |
|---|---|
| `artefato` | `gs-jar` |
| `opcoesMaven` | `-B -DexcludedGroups=integracao` |

Os testes são de unidade (regras de doses e adesão, JWT, vínculo idoso-cuidador, exclusão de conta, jobs, documentação OpenAPI) e não precisam de banco nem de fila. Um teste que dependa de banco leva a tag JUnit `integracao` e fica de fora no CI, de modo que nenhuma credencial chega ao agente de build.

### CD: deploy automático (Release clássica `gs-cd`)

| Configuração | Valor |
|---|---|
| Artefato | Build da pipeline `gs-ci`, alias `_gs-ci`, versão padrão *Latest* |
| Gatilho | **Continuous deployment trigger** ligado, com filtro de branch `main`: cada artefato novo cria uma release |
| Stage | `Produção (Azure Web App)`, agente `ubuntu-latest` |
| Task 1 | **Azure Web App** (`AzureWebApp@1`): service connection `azure-gs`, tipo *Web App on Linux*, app `rm566234-gs-api`, pacote `$(System.DefaultWorkingDirectory)/_gs-ci/gs-jar/*.jar`, runtime `JAVA\|21-java21` |
| App settings | `-DB_URL "$(DB_URL)" -DB_USER "$(DB_USER)" -DB_PASSWORD "$(DB_PASSWORD)" -JWT_SECRET "$(JWT_SECRET)" -GROQ_API_KEY "$(GROQ_API_KEY)" -CLOUDAMQP_URL "$(CLOUDAMQP_URL)" -SERVER_PORT 80` |
| Task 2 | **Bash** (smoke test): espera a API responder `UP` antes de dar a release como concluída |
| Variáveis | Variable group `gs-segredos` vinculado à release |

Script do smoke test (Task 2):

```bash
URL="https://rm566234-gs-api.azurewebsites.net"
sleep 45   # o Web App reinicia com a versão nova e o Flyway confere o schema
for tentativa in $(seq 1 40); do
  SAUDE=$(curl -s --max-time 20 "$URL/actuator/health" || true)
  if echo "$SAUDE" | grep -q '"status":"UP"'; then
    echo "Saúde da API: $SAUDE"
    curl -s "$URL/api-docs" | python3 -c "import json,sys; i=json.load(sys.stdin)['info']; print('Swagger publicado:', i['title'], '-', i['version'])"
    exit 0
  fi
  echo "Tentativa $tentativa: a API ainda não respondeu UP"; sleep 15
done
echo "##vso[task.logissue type=error]A API não respondeu UP"; exit 1
```

O `/actuator/health` só responde `UP` quando a API está de pé e o banco e a fila estão acessíveis.

---

## 8. ✅ Requisitos do enunciado e como foram atendidos

| # | Requisito | Como foi atendido |
|:---:|---|---|
| 01 | Projeto privado e com Git | Projeto `GS 2026-2 - DevOps`, privado, Git, processo Scrum (seção 5) |
| 02 | Azure Boards vinculado ao Repos | Branches criadas a partir das Tasks, commits com `#id` e PRs vinculados (seção 6) |
| 03 | Branch principal protegida | Revisor obrigatório, work item vinculado e revisor padrão (RM566234) na `main` |
| 04 | Build somente após merge na main via PR | `trigger: main` e `pr: none`; as políticas impedem push direto na `main` |
| 05 | O aluno pode aprovar o próprio PR | *Allow requestors to approve their own changes* ligado |
| 06 | Release automática após novo artefato | Continuous deployment trigger da Release `gs-cd` no artefato `gs-jar` |
| 07 | Deploy em container ou Serviço de Aplicativo | Serviço de Aplicativo: Web App Linux `rm566234-gs-api` (Java 21 SE) |
| 08 | Banco em container ou PaaS | Container: Oracle Free no ACI (`aci-rm566234-oracle`), com a imagem no ACR (`acrrm566234gs`), criados por script |
| 09 | Scripts de infraestrutura no repositório | [`scripts/`](scripts/) |
| 10 | `script-bd.sql` com o DDL em `/scripts` | [`scripts/script-bd.sql`](scripts/script-bd.sql) |
| 11 | Scripts Azure CLI em `/scripts` | [`scripts/00-variaveis.sh`](scripts/00-variaveis.sh) a [`scripts/99-limpar.sh`](scripts/99-limpar.sh) |
| 12 | Dockerfiles em `/dockerfiles` (caso use Docker) | [`dockerfiles/oracle/Dockerfile`](dockerfiles/oracle/Dockerfile), a imagem do banco |
| 13 | `azure-pipeline.yml` na raiz | [`azure-pipeline.yml`](azure-pipeline.yml) |
| 14 | CRUD exposto em JSON no README (APIs sem Swagger) | A API tem Swagger e, mesmo assim, os JSON do CRUD estão na seção 11 e em [`docs/demo-crud.http`](docs/demo-crud.http) |
| 15 | Variáveis de ambiente nas pipelines | Variáveis no YAML do CI e variable group `gs-segredos` na Release, gravado como app settings no Web App |
| 16 | Desenho macro da arquitetura | Seção 2 |
| 17 | Testes automáticos no CI | `Maven@4` roda os 36 testes e publica os resultados JUnit na aba Tests |

---

## 9. 🔒 Variáveis de ambiente e segurança

| Variável | Sensível | Onde fica |
|---|:---:|---|
| `DB_URL` | não | Variable group `gs-segredos` → app setting do Web App |
| `DB_USER` | sim | Variable group `gs-segredos` (secret) → app setting do Web App |
| `DB_PASSWORD` | sim | Variable group `gs-segredos` (secret) → app setting do Web App e variável segura do ACI |
| `JWT_SECRET` | sim | Variable group `gs-segredos` (secret, ≥ 32 caracteres, o mesmo da API .NET) → app setting do Web App |
| `CLOUDAMQP_URL` | sim | Variable group `gs-segredos` (secret) → app setting do Web App |
| `GROQ_API_KEY` | sim | Variable group `gs-segredos` (secret) → app setting do Web App |
| `ORACLE_PASSWORD` | sim | Só no `.env` de quem opera a infraestrutura → variável segura do ACI (senha do SYS) |
| `SERVER_PORT` | não | `80`, a porta que o App Service Linux encaminha para a aplicação (gravada por `01-criar-app.sh`) |

- **Nenhuma credencial** está no código, no YAML, nos scripts, no Dockerfile ou no histórico. Localmente, as variáveis vêm de um `.env`, ignorado pelo Git; o [`.env.example`](.env.example) lista quais existem, sem valores.
- As senhas do banco chegam ao container como **variáveis de ambiente seguras** do ACI, que não aparecem no Portal nem no `az container show`.
- O Web App aceita só HTTPS e tem o FTP desligado. O ACI não tem firewall próprio, então a porta 1521 é pública e protegida por senhas fortes, e a senha do SYS fica só com quem opera a infraestrutura.

---

## 10. 💻 How-to: reproduzir a solução

### Pré-requisitos

- [Git](https://git-scm.com/) e **JDK 21** (o Maven vem no wrapper `mvnw`)
- [Azure CLI](https://learn.microsoft.com/pt-br/cli/azure/install-azure-cli), com `az login` feito na assinatura
- Uma organização no Azure DevOps com parallel jobs hospedados liberados
- [SQL Developer](https://www.oracle.com/database/sqldeveloper/) para consultar o banco
- Docker, opcional, só se a assinatura não permitir o build no ACR

### 1. Clonar e configurar as variáveis

```bash
git clone https://dev.azure.com/RM565154/GS%202026-2%20-%20DevOps/_git/gs-devops
cd gs-devops
cp .env.example .env   # preencha as senhas, o JWT_SECRET, a CLOUDAMQP_URL e a GROQ_API_KEY
# exporta as variáveis para os scripts, removendo o \r de arquivos salvos no Windows
while IFS='=' read -r k v; do v="${v%$'\r'}"; [[ "$k" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]] && export "$k=$v"; done < .env
```

### 2. Criar a infraestrutura na Azure

Os scripts **criam recursos pagos**.

```bash
bash scripts/01-criar-app.sh        # Resource Group, plano B1 e Web App Java 21
bash scripts/02-criar-registro.sh   # Container Registry e build da imagem do Oracle
bash scripts/03-criar-banco.sh      # Oracle no ACI (imprime a DB_URL)
bash scripts/04-status.sh           # estado dos recursos, da API e do banco (só leitura)
```

### 3. Configurar o Azure DevOps

1. Crie o projeto (privado, Git, Scrum), convide o professor com acesso **Basic** e coloque-o em **Project Administrators**.
2. Importe este repositório em **Repos** e configure as políticas da `main` (seção 6).
3. Em **Project settings › Service connections**, crie a conexão **Azure Resource Manager** `azure-gs` com acesso ao Resource Group `rg-rm566234-gs`.
4. Em **Pipelines › Library**, crie o variable group `gs-segredos` com `DB_URL`, `DB_USER`, `DB_PASSWORD`, `JWT_SECRET`, `CLOUDAMQP_URL` e `GROQ_API_KEY`, clicando no **cadeado** de todas, menos a `DB_URL`.
5. Em **Pipelines › New pipeline**, escolha *Azure Repos Git* › `gs-devops` › *Existing Azure Pipelines YAML file* › `/azure-pipeline.yml`, e renomeie para `gs-ci`.
6. Em **Releases › New › Empty job**, crie a `gs-cd` como na seção 7. Se o menu Releases não aparecer, desligue *Disable creation of classic release pipelines* em Organization Settings › Pipelines › Settings e nas configurações do projeto.
7. Crie uma Task no Boards, uma branch a partir dela, faça um commit e um PR para a `main`. O merge dispara o CI, o CI dispara a Release, e `bash scripts/04-status.sh` confirma que a API está no ar.

### 4. Rodar e testar localmente (opcional)

```bash
./mvnw -B clean package -DexcludedGroups=integracao   # o mesmo comando do CI (não precisa de banco)
```

No Windows, `.\run.ps1` carrega o `.env`, avisa se faltar variável obrigatória e sobe a API apontando para o Oracle da Azure. Como o banco é o mesmo da produção, o `run.ps1` deixa os jobs agendados e os consumidores da fila desligados (`JOBS_HABILITADOS=false` e `RABBIT_CONSUMIDORES=false`).

### 5. Recuperar a API depois de um reinício do banco

```bash
bash scripts/04-status.sh           # a coluna Reinicios mostra se o container reiniciou
bash scripts/05-reiniciar-api.sh    # o Flyway recria as tabelas TB_ e os dados de teste
```

### 6. Limpeza (depois da correção)

```bash
bash scripts/99-limpar.sh           # apaga o Resource Group inteiro (pede confirmação)
```

---

## 11. 🧪 Demonstração do CRUD com evidência no banco

O CRUD é feito pelo Swagger UI da API publicada e, depois de cada operação, um `SELECT` no SQL Developer, conectado ao Oracle do ACI, mostra a persistência. As chamadas estão em [`docs/demo-crud.http`](docs/demo-crud.http) (extensão *REST Client* do VS Code) e os `SELECT`, em [`docs/consultas-video.sql`](docs/consultas-video.sql). Os usuários de teste são fictícios: `maria.idosa@teste.dev` e `jose.idoso@teste.dev`, com a senha `Remembered@2026`.

| Passo | Chamada | Evidência no Oracle |
|---|---|---|
| 1.0 | `POST /api/v1/auth/login` com o idoso de teste | — (devolve o token JWT e o id do idoso) |
| 1.1 a 1.4 | `POST /api/v1/idosos/{id}/medicamentos`, `GET`, `PUT` e `DELETE /api/v1/medicamentos/{id}` | A linha de `TB_MEDICAMENTO` e o horário em `TB_HORARIO_MEDICAMENTO` aparecem, mudam e somem |
| 2.1 a 2.4 | `POST /api/v1/auth/cadastro`, login e `GET /api/v1/me`, `PUT /api/v1/me` e `DELETE /api/v1/me` | A linha de `TB_USUARIO` aparece, muda e some |

Corpos JSON de cada tabela:

```json
// 1.0 POST /api/v1/auth/login
{ "email": "maria.idosa@teste.dev", "senha": "Remembered@2026" }

// 1.1 POST /api/v1/idosos/{id}/medicamentos
{ "nome": "Vitamina D", "dosagem": "1000 UI", "forma": "Cápsula", "dataInicio": "2026-11-18",
  "observacoes": "Tomar depois do café da manhã", "horarios": [ { "hora": "09:00" } ] }

// 1.3 PUT /api/v1/medicamentos/{id}
{ "nome": "Vitamina D", "dosagem": "2000 UI", "forma": "Cápsula", "dataInicio": "2026-11-18",
  "observacoes": "Tomar depois do almoço", "horarios": [ { "hora": "13:00" } ] }

// 2.1 POST /api/v1/auth/cadastro
{ "nome": "Antônio Pereira", "email": "antonio.demo@teste.dev", "senha": "Demo@2026" }

// 2.3 PUT /api/v1/me
{ "nome": "Antônio Carlos Pereira" }
```

O `DELETE /api/v1/me` exclui a conta do idoso e os dados dele (medicamentos, horários, doses, avisos e relatórios), o que também atende ao direito de exclusão da LGPD.

Para usar o Swagger UI:

1. Abra https://rm566234-gs-api.azurewebsites.net/swagger-ui.html.
2. Execute `POST /api/v1/auth/login` e copie o `token`.
3. Clique em **Authorize** e cole o token.
4. A partir daí, todo *Try it out* já envia o cabeçalho `Authorization`.

---

## 12. 📁 Estrutura do repositório

```
.
├── azure-pipeline.yml          → CI: build, testes, resultados JUnit e artefato gs-jar
├── dockerfiles/
│   └── oracle/
│       ├── Dockerfile          → imagem do Oracle Free do projeto
│       ├── initdb/             → script de inicialização (tabelas NET_)
│       └── sql/                → DDL das tabelas NET_
├── scripts/
│   ├── 00-variaveis.sh         → nomes dos recursos e região (sem segredos)
│   ├── 01-criar-app.sh         → Resource Group, plano B1 e Web App
│   ├── 02-criar-registro.sh    → Container Registry e build da imagem
│   ├── 03-criar-banco.sh       → Oracle no Container Instances
│   ├── 04-status.sh            → estado dos recursos, da API e do banco
│   ├── 05-reiniciar-api.sh     → recupera a API depois de um reinício do banco
│   ├── 99-limpar.sh            → apaga o Resource Group
│   └── script-bd.sql           → DDL Oracle de todos os objetos do banco
├── docs/
│   ├── arquitetura-devops.png / .svg   → desenho macro da arquitetura
│   ├── demo-crud.http          → roteiro do CRUD contra a API publicada
│   └── consultas-video.sql     → SELECT de evidência de cada operação
├── src/                        → código-fonte da API Java (snapshot)
├── pom.xml · mvnw · .mvn/      → build Maven
├── .env.example                → modelo das variáveis de ambiente, sem valores
├── run.ps1                     → carrega o .env e sobe a API localmente
├── .gitattributes              → LF em scripts e YAML
└── .gitignore
```

---

## 🤖 Declaração de uso de IA

O grupo usou o Claude (Claude Code) como apoio para escrever os scripts Azure CLI, o Dockerfile do banco, o pipeline de CI, a definição da Release, o desenho da arquitetura e este README, a partir da entrega de DevOps da Sprint 4 do Challenge. Todo o conteúdo foi revisado pelo grupo, e cada integrante consegue explicar a esteira, os scripts e as decisões de arquitetura.
