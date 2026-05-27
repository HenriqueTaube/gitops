# Orcamentos

Base inicial reaproveitada do projeto `codex`.

## Objetivo

Subir uma API simples no worker Talos para conversar com a API da OpenAI e servir de base para o projeto de orcamentos.

Primeira fase:

- reaproveitar o backend do `codex`
- usar `app.py` como base
- expor um endpoint de chat
- salvar historico em volume no worker
- publicar a imagem no registry do Forgejo
- rodar no node `worker`

Fases depois:

- app web simples
- login e senha basicos
- fluxo para criar e atualizar orcamentos
- upload de fotos
- geracao e download de arquivo final
- refinamento do layout do Word com estrutura mais profissional

## Arquivos base

- `app.py`
- `requirements.txt`
- `Dockerfile`
- `secret.yaml`
- `pvc.yaml`
- `deployment.yaml`
- `service.yaml`

## Ajustes principais em relacao ao projeto codex

- namespace: `orcamentos`
- deployment: `orcamentos-api`
- service: `orcamentos-api`
- secret: `orcamentos-openai`
- pvc: `orcamentos-data`
- imagem: `192.168.1.54:3000/henrique/orcamentos-api:latest`
- node atual: `worker`
- nodePort: `30081`

## Proximo fluxo

1. Ajustar o `app.py` para o comportamento especifico de orcamentos.
2. Buildar a imagem `linux/arm64`.
3. Fazer push no registry do Forgejo.
4. Criar namespace `orcamentos`.
5. Aplicar `secret`, `pvc`, `deployment` e `service`.

## Melhorias futuras do Word

- criar pasta `templates/` com um `orcamento_padrao.docx`
- definir marcadores editaveis como `{{TITULO}}`, `{{CLIENTE}}`, `{{ITENS}}`, `{{TOTAL}}`
- deixar a IA gerar apenas o conteudo dos campos, nao o layout inteiro
- aplicar cabecalho com dados da empresa
- estruturar secoes fixas de orcamento
- melhorar tipografia e espacamento
- padronizar tabelas de itens, valores e totais
- inserir imagens enviadas pelo usuario no documento final
- suportar edicao de orcamento existente sem perder formatacao
