# Loki no Talos

Objetivo:

- migrar o Loki que hoje roda fora do cluster
- rodar o Loki no Kubernetes
- manter os dados no NFS da VM `nextcloud`

## Estado inicial

- namespace dedicado: `loki`
- storage via NFS em `192.168.1.224:/srv/backup/nfs/loki`

## Estado atual

- `namespace.yaml`, `pvc.yaml`, `configmap.yaml`, `deployment.yaml` e `service.yaml` criados
- imagem em uso: `grafana/loki:3.7.0`
- dados migrados da VM antiga para o NFS
- Loki subiu no cluster e esta respondendo as consultas do Grafana

## Configuracao

O Loki usa:

- PVC montado em `/var/lib/loki`
- configuracao via `ConfigMap`
- `path_prefix: /var/lib/loki`

No NFS, o path final de dados ficou:

- `192.168.1.224:/srv/backup/nfs/loki`

Com os dados reais direto no nivel raiz, por exemplo:

- `chunks`
- `compactor`
- `rules`
- `tsdb-shipper-active`
- `tsdb-shipper-cache`
- `wal`
- `loki_cluster_seed.json`

## Exposicao

O service do Loki ficou:

- tipo `NodePort`
- porta interna `3100`
- `nodePort` `31010`

Uso recomendado:

- Grafana dentro do cluster:
  - `http://loki.loki.svc.cluster.local:3100`
- Alloy nas VMs externas:
  - `http://192.168.1.152:31010/loki/api/v1/push`

## Observacao sobre NodePort

O pod do Loki foi fixado no `worker-rasp`, mas para as VMs externas o endpoint que funcionou na pratica foi:

- `192.168.1.152:31010`

Mesmo com o pod no `worker-rasp`, o `NodePort` respondeu de forma confiavel pelo `worker-prox`.

O endpoint `192.168.1.153:31010` retornou `connection refused` para a VM `knots`, entao o endpoint externo efetivamente adotado foi o `192.168.1.152`.

## Alloy

As VMs externas usam `alloy`, nao `promtail`.

Diagnostico feito:

- Alloy estava lendo os arquivos locais corretamente
- o erro era de conexao com o endpoint externo errado do Loki
- ajuste necessario: trocar o `loki.write` para usar `192.168.1.152:31010`

## Pendencias

- revisar com calma as outras VMs que ainda usam Alloy
- entender depois por que o `NodePort` do `worker-rasp` nao respondeu externamente como esperado
