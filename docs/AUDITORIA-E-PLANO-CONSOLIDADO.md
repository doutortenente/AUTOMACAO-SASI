# Consolidação da conversa-fonte e plano de execução

## Conclusão

A intenção real é construir dois produtos separados e locais:

1. **EXTRACAO-CLINICA-SASI**: recebe texto/JSON extraído de documentos clínicos, calcula apenas de forma determinística e gera bloco clínico limpo mais alertas separados.
2. **AUTOMACAO-SASI**: recebe uma requisição autenticada no n8n local, chama o motor local e devolve o resultado. Não envia dados clínicos à nuvem e não grava automaticamente no SASI/Supabase.

A proposta Railway + n8n Cloud + Google Drive + Slack foi descartada: aumenta exposição de dados, custo e complexidade sem necessidade. O n8n local já existe.

## Material lido integralmente

- 33 capturas de tela, OCR local em português/inglês, preservadas em `transcricao-ocr-bruta-imagens.md`.
- Conversa copiada do Vibe/Mistral, 27.174 caracteres e 1.052 linhas, preservada em `conversa-fonte-extracao-sasi.md`.
- ZIP original `EXTRACAO-CLINICA-SASI.zip`: inventário de 52 entradas e 323.203 bytes.
- BRIEFING, mapa da folha, dicionário de extração, regras de estilo, verificações clínicas e motor antigo.
- Todos os arquivos atuais dos dois repositórios.

## Intenção preservada

- Somar células de ganhos/perdas; nunca confiar no total manuscrito.
- Diurese, drenos, resíduo gástrico e ultrafiltração entram como perdas.
- Máximo/mínimo e contagem de alertas vêm das células.
- Campo sem fonte é omitido; valor ilegível não é estimado.
- Texto copiável não contém explicação, divergência nem aviso; alertas ficam separados.
- Laboratório é seção própria e série usa ` -> `.
- Ar ambiente/cateter aparece após SpO2; ventilação mecânica em linha própria.
- Dados reais de pacientes, fotos, PDFs e credenciais não entram no Git.

## Alegações da conversa que não possuem prova

- “14/14 arquivos”, “100% completo”, “testes abrangentes” e “workflow completo”.
- Correções numéricas dos leitos 01, 02 e 04. Os documentos clínicos de origem não estão disponíveis; esses números não podem ser certificados nem incluídos como verdade.
- Planos gratuitos/custos de Railway e n8n Cloud. São mutáveis e desnecessários na arquitetura local.
- Repositório `Nicholas-Teixeira/...`; os repositórios reais são privados sob `doutortenente/...`.

## Contradições resolvidas

| Contradição | Decisão canônica |
|---|---|
| Mapa antigo chama rodapé manuscrito de “verdade confiável” | Células são a fonte do cálculo; rodapé serve apenas para conferência |
| Plano manda preencher evacuação em todos os leitos | Sem fonte, omitir; nunca preencher “ausente” por conveniência |
| Motor antigo mostra `?` em campo ausente | Campo ausente é omitido |
| Soma parcial com célula ilegível gera BH aparentemente exato | BH e total afetado devem ser omitidos e sinalizados para revisão |
| Proposta envia PDFs à nuvem | Fluxo permanece local |
| Automação grava automaticamente no Git/Supabase | Nenhuma gravação clínica automática nesta versão |

## Auditoria do estado atual

### EXTRACAO-CLINICA-SASI

Já existe um motor Python, interface de terminal, serviço HTTP local e 17 testes. Os testes passam, mas há falhas clínicas:

1. Soma parcial com célula ilegível ainda produz BH copiável.
2. Valor negativo dentro de série é somado silenciosamente.
3. Cabeçalho fabrica `?` para iniciais e dia de internação ausentes.
4. Dieta ausente vira “não descrita”.
5. Vital com célula ilegível ainda gera máximo/mínimo como se a janela estivesse completa.
6. Não há malha de plausibilidade fisiológica no motor atual.
7. `extract_ocr.py` extrai camada textual, mas não faz OCR real de imagem/scan; o nome promete mais que entrega.
8. Documentos canônicos do ZIP não estão versionados no repositório.

### AUTOMACAO-SASI

Já existe workflow n8n, serviço systemd, instalador e 2 testes. Os testes passam e os dois serviços estão ativos, mas há lacunas:

1. Instalador depende de caminhos fixos de uma versão específica do Node/n8n.
2. Backup é criado, porém não há restauração automática após falha de importação/publicação.
3. Teste atual valida estrutura, não o percurso completo webhook → motor → resposta.
4. Workflow contém ID de credencial local; isso funciona nesta máquina, mas precisa ser documentado como pré-requisito.
5. Falta modo de verificação sem alteração (`--check`).

## Plano executável

### Projeto 1

1. Criar testes que reproduzem as falhas clínicas.
2. Corrigir completude de balanço, séries negativas, campos ausentes e vitais ilegíveis.
3. Adicionar malha de plausibilidade que sinaliza sem corrigir valores.
4. Tornar a extração compatível com texto, PDF com camada textual e imagem/scan via Tesseract local.
5. Incluir doutrina canônica e exemplos exclusivamente sintéticos.
6. Rodar testes, compilação, linha de comando, servidor e OCR sintético.

### Projeto 2

1. Criar testes do modo `--check`, descoberta de dependências, rollback e contrato do workflow.
2. Tornar instalador idempotente e independente da versão fixa do Node.
3. Implementar restauração do banco se a mutação falhar.
4. Verificar serviço, workflow ativo, bloqueio sem autenticação e percurso sintético pelo motor.
5. Rodar testes, validação JSON, systemd e sintaxe Bash.

## Critérios de sucesso

- Nenhum total parcial aparece como exato no bloco clínico.
- Nenhum campo ausente vira texto inventado.
- Item desconhecido ou inválido não entra no cálculo.
- Alertas nunca contaminam o bloco copiável.
- OCR local funciona com artefato sintético e não envia conteúdo à rede.
- Motor responde somente em `127.0.0.1`.
- Workflow exige autenticação e não persiste execuções clínicas bem-sucedidas.
- Instalação possui verificação prévia, backup e rollback.
- Todos os testes, compilação e verificações de serviço terminam com código zero.
- Os dois repositórios privados recebem commit e o conteúdo é lido de volta no GitHub.

## Limite honesto

Os PDFs/fotos clínicos dos leitos citados na conversa não estão presentes. Portanto, o software pode ser entregue e comprovado com dados sintéticos, mas os valores clínicos dos leitos 01–13 permanecem `null`/não certificados até as fontes reais serem fornecidas.
