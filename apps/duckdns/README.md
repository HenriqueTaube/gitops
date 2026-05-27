# DuckDNS no Kubernetes

## Objetivo

Atualizar automaticamente o dominio DuckDNS a cada 5 minutos, como substituicao do cron que rodava na VM antiga.

## Estrategia

Usar um `CronJob` do Kubernetes.

Isso substitui este padrao antigo:

```cron
*/5 * * * * curl -s "https://www.duckdns.org/update?domains=taubevps&token=SEU_TOKEN&ip=" >/dev/null 2>&1
```

## Componentes

- `secret.yaml`
  - guarda dominio e token
- `cronjob.yaml`
  - executa `curl` a cada 5 minutos

## Como Funciona

O `CronJob` chama:

```text
https://www.duckdns.org/update?domains=DOMINIO&token=TOKEN&ip=
```

Com `ip=` vazio, o DuckDNS detecta o IP publico automaticamente.

## Aplicacao

```bash
kubectl create namespace duckdns
kubectl apply -f duckdns/secret.yaml
kubectl apply -f duckdns/cronjob.yaml
```

## Verificacao

Ver o cronjob:

```bash
kubectl -n duckdns get cronjob
```

Ver jobs:

```bash
kubectl -n duckdns get jobs
```

Ver logs do job mais recente:

```bash
kubectl -n duckdns get pods
kubectl -n duckdns logs NOME_DO_POD
```

## Observacao

O `secret.yaml` foi deixado como template.
Troque o token real antes de aplicar.
