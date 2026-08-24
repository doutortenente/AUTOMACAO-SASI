# AUTOMACAO-SASI

Orquestração local do motor clínico pelo n8n já existente no Tijolão.

## Fluxo

`POST autenticado no n8n → motor Python local → texto clínico + flags táticos`

- Entrada: `POST /webhook/sasi-clinical-compile`.
- Autenticação: cabeçalho já gerenciado pelo n8n local.
- Motor: `http://127.0.0.1:8765/v1/compile`.
- Saída: JSON com `texto_clinico`, `flags_taticos` e `requires_human_review`.

## Segurança

- Nenhuma chave no repositório.
- Motor escuta apenas em `127.0.0.1`.
- Serviço com isolamento do sistema e limite de 256 MiB.
- Workflow não grava no Supabase e não publica dados externamente.
- Dados reais de pacientes, fotos e PDFs não entram no Git.

## Verificação sem alterar serviços

```bash
bash scripts/install-local.sh --check
```

## Instalação local

```bash
bash scripts/install-local.sh
```

O instalador descobre o n8n disponível no sistema, faz cópia de segurança do banco antes da importação, restaura o banco automaticamente se a instalação falhar, liga o motor e testa a saúde dos dois serviços.

## Verificação

```bash
python3 -m unittest discover -s tests -v
python3 -m json.tool n8n/workflows/sasi-clinical-compile.json >/dev/null
systemd-analyze --user verify services/extracao-clinica-sasi.service
bash -n scripts/install-local.sh
```
