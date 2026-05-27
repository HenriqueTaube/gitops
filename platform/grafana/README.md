# Grafana Test

Objetivo:

- subir um Grafana separado do principal
- usar PostgreSQL no `CloudNativePG`
- validar a troca de SQLite para Postgres sem mexer no Grafana atual

## Estado atual

Ja validado:

- `grafana-test` subiu no namespace `grafana-test`
- usa PostgreSQL no cluster `pg-lab` do `CloudNativePG`
- login no Grafana de teste funcionando
- datasource Loki configurado e funcional
- Explore funcionando com os logs normalmente
- dashboards recriados/importados no ambiente de teste
- service ajustado para a porta final `30091`

## Arquitetura atual

O Grafana de teste usa:

- namespace: `grafana-test`
- imagem: `grafana/grafana:12.4.1`
- banco: PostgreSQL
- backend do banco: `CloudNativePG`
- host do banco:
  - `pg-lab-rw.cloudnativepg-lab.svc.cluster.local:5432`
- banco:
  - `grafana`
- usuario:
  - `grafana`

Importante:

- este Grafana nao usa o `grafana.db` antigo
- ele nao depende do PVC NFS do Grafana principal
- os dados agora ficam no PostgreSQL do `CloudNativePG`

## Arquivos deste diretorio

- [namespace.yaml](/home/coder/talos/grafana-test/namespace.yaml)
- [db-secret.yaml](/home/coder/talos/grafana-test/db-secret.yaml)
- [deployment.yaml](/home/coder/talos/grafana-test/deployment.yaml)
- [service.yaml](/home/coder/talos/grafana-test/service.yaml)

## Fluxo que funcionou

1. criar usuario e banco `grafana` no `pg-lab`
2. aplicar `namespace.yaml`
3. aplicar `db-secret.yaml`
4. aplicar `deployment.yaml`
5. aplicar `service.yaml`
6. acessar o Grafana de teste
7. configurar datasource Loki
8. validar Explore
9. recriar/importar o necessario

## Loki

Datasource Loki funcional no `grafana-test` usando o service interno do cluster:

- `http://loki.loki.svc.cluster.local:3100`

## Porta

O service do `grafana-test` foi ajustado para:

- `NodePort`: `30091`

Observacao:

- se o `grafana-test` assumir de vez o lugar do Grafana antigo, revisar conflito de porta/service com o Grafana principal antes de desligar o antigo

## Persistencia

A persistencia do `grafana-test` agora depende do PostgreSQL no `CloudNativePG`.

Entao:

- reiniciar o pod do Grafana nao deve perder dashboards
- reiniciar o pod `pg-lab-1` nao deve perder dashboards
- apagar o `Cluster` do `CloudNativePG` nao e seguro sem backup

## Backup

Antes da migracao foi feito backup do `grafana.db` antigo.

Agora, para proteger o `grafana-test`, o backup relevante passa a ser:

- backup do banco `grafana` dentro do PostgreSQL

## Proximo passo

Quando o `grafana-test` estiver 100% equivalente ao Grafana atual:

- desligar ou remover o Grafana antigo
- manter o Grafana novo como principal
- depois avaliar migrar o storage do PostgreSQL para Longhorn
