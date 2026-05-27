# CloudNativePG

Objetivo:

- aprender `CloudNativePG` no cluster Talos
- entender o fluxo basico de um PostgreSQL gerenciado no Kubernetes
- avaliar depois se o Grafana vai migrar de SQLite para PostgreSQL

## Estado atual do laboratorio

Ja validado:

- operador `CloudNativePG` instalado no namespace `cnpg-system`
- SSD local conectado no `worker-rasp`
- disco montado no host em `/var/mnt/ssd`
- diretorio do laboratorio em `/var/mnt/ssd/cloudnative`
- `PersistentVolume` local criado apontando para esse path
- `StorageClass` `cloudnativepg-local`
- cluster `pg-lab` criado no namespace `cloudnativepg-lab`
- banco `app` e usuario `app` funcionando
- teste de persistencia validado depois de reiniciar o pod

## Arquivos deste diretorio

- [namespace.yaml](/home/coder/talos/cloudnativepg/namespace.yaml)
- [storageclass.yaml](/home/coder/talos/cloudnativepg/storageclass.yaml)
- [pv.yaml](/home/coder/talos/cloudnativepg/pv.yaml)
- [secret.yaml](/home/coder/talos/cloudnativepg/secret.yaml)
- [cluster.yaml](/home/coder/talos/cloudnativepg/cluster.yaml)

## Conceitos basicos

### Cluster

O objeto principal do `CloudNativePG` e o `Cluster`.

Ele representa o banco gerenciado pelo operador.

Exemplo mental:

- `Cluster` = o servidor PostgreSQL gerenciado
- o operador cria pods, services, secrets e PVCs a partir dele

Importante:

- o `Cluster` cria o PVC dele proprio
- nao usar um PVC manual para a instancia do Postgres depois que o laboratorio estiver validado

### PV

O `PersistentVolume` e o volume real do Kubernetes.

No laboratorio atual:

- ele aponta para o path local do host:
  - `/var/mnt/ssd/cloudnative`
- ele esta preso ao node `worker-rasp`

### PVC

O `PersistentVolumeClaim` e o pedido de storage.

No `CloudNativePG`:

- o operador cria o PVC da instancia sozinho
- no nosso caso apareceu como:
  - `pg-lab-1`

Importante:

- nao reaplicar o `pvc.yaml` manual antigo depois que o cluster estiver funcionando
- ele foi util apenas para testar o PV no comeco

### Service

O `Service` e a forma de comunicacao com o banco dentro do cluster.

No laboratorio atual:

- `pg-lab-rw` = leitura e escrita no primario
- `pg-lab-ro` = leitura
- `pg-lab-r` = leitura/uso interno

Para app normal, o mais comum e usar:

- `pg-lab-rw`

## Fluxo que funcionou

1. instalar o operador `CloudNativePG`
2. criar namespace do laboratorio
3. preparar storage local no `worker-rasp`
4. criar `StorageClass`
5. criar `PV`
6. criar `Secret` do usuario/app
7. criar o `Cluster`
8. deixar o operador criar o PVC da instancia
9. validar com `psql`
10. reiniciar o pod e confirmar persistencia

## Validacao feita

Cliente de teste:

```bash
k -n cloudnativepg-lab run psql-client --rm -it --restart=Never \
  --image=postgres:17 \
  --env PGPASSWORD=app123456 \
  -- psql -h pg-lab-rw -U app -d app
```

Teste realizado:

```sql
create table teste (id serial primary key, nome text);
insert into teste (nome) values ('ok');
select * from teste;
```

Depois:

- pod `pg-lab-1` foi deletado
- o operador recriou o pod
- `select * from teste;` continuou retornando a linha `ok`

Isso validou a persistencia.

## Operacoes basicas uteis

Ver o cluster:

```bash
k -n cloudnativepg-lab get cluster
k -n cloudnativepg-lab describe cluster pg-lab
```

Ver pods:

```bash
k -n cloudnativepg-lab get pods -o wide
```

Ver PVC:

```bash
k -n cloudnativepg-lab get pvc
```

Ver services:

```bash
k -n cloudnativepg-lab get svc
```

Reiniciar a instancia:

```bash
k -n cloudnativepg-lab delete pod pg-lab-1
```

Ver logs do operador:

```bash
k -n cnpg-system logs deploy/cnpg-controller-manager --tail=200
```

## Licoes aprendidas

- para `instances: 2`, cada replica precisa do proprio volume
- com apenas um PV local, o laboratorio atual suporta apenas `instances: 1`
- `Retain` no PV pode ficar
- se o PVC antigo for removido, o PV pode ficar em `Released`
- quando isso acontecer, pode ser necessario limpar o `claimRef` do PV manualmente para voltar a `Available`

## Relacao com o Grafana

Hoje o Grafana esta:

- funcional
- usando `grafana.db` em SQLite
- com storage em NFS

Suspeita atual:

- a lentidao intermitente pode estar ligada a SQLite sobre NFS

Possivel proximo passo no futuro:

- usar um PostgreSQL no cluster para o Grafana

O deployment do Grafana provavelmente precisaria usar algo como:

- `GF_DATABASE_TYPE=postgres`
- `GF_DATABASE_HOST=<service do postgres>`
- `GF_DATABASE_NAME=<banco>`
- `GF_DATABASE_USER=<usuario>`
- `GF_DATABASE_PASSWORD=<senha>`

## Decisao atual

- manter o laboratorio do `CloudNativePG`
- aprender backup/restore depois
- avaliar com calma se o Grafana vai migrar para PostgreSQL
