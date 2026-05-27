# Forgejo no cluster Talos

Objetivo:

- mover o Forgejo da VM para o cluster Talos
- manter o workload funcional no cluster
- usar storage persistente para app e banco
- finalizar a migracao em `Longhorn`

## Arquivos

- `namespace.yaml`
- `deployment.yaml`
- `service.yaml`
- `mysql-service.yaml`
- `mysql-deployment.yaml`
- `longhorn-migrator/pvc.yaml`
- `longhorn-migrator/pvc-mysql.yaml`

## Imagem

O deployment usa a imagem oficial:

- `codeberg.org/forgejo/forgejo:14.0`

Escolha intencional:

- evita depender do registry do proprio Forgejo durante a migracao
- permite subir o Forgejo novo mesmo antes de desligar a VM antiga

Depois que a migracao estiver estavel, voce pode decidir se quer espelhar essa imagem no seu registry privado.

Referencia:

- `14.0.x` e a linha estavel atual
- usar a tag `14.0` acompanha os patch releases dessa linha

## Exposicao

- HTTP: `NodePort 30090`
- SSH Git: `NodePort 30222`

Exemplo:

- `http://IP_DO_NODE:30090`
- `ssh -p 30222 git@IP_DO_NODE`

## Aplicacao

```bash
kubectl --kubeconfig /home/coder/talos/kubeconfig apply -f /home/coder/talos/forgejo/namespace.yaml
kubectl --kubeconfig /home/coder/talos/kubeconfig apply -f /home/coder/talos/forgejo/pvc.yaml
kubectl --kubeconfig /home/coder/talos/kubeconfig apply -f /home/coder/talos/forgejo/mysql-pvc.yaml
kubectl --kubeconfig /home/coder/talos/kubeconfig create secret generic forgejo-mysql \
  -n forgejo \
  --from-literal=mysql-root-password='ROOT_PASSWORD' \
  --from-literal=mysql-database='forgejo' \
  --from-literal=mysql-user='forgejo' \
  --from-literal=mysql-password='APP_PASSWORD'
kubectl --kubeconfig /home/coder/talos/kubeconfig apply -f /home/coder/talos/forgejo/mysql-service.yaml
kubectl --kubeconfig /home/coder/talos/kubeconfig apply -f /home/coder/talos/forgejo/mysql-deployment.yaml
kubectl --kubeconfig /home/coder/talos/kubeconfig create secret generic forgejo-app-ini \
  -n forgejo \
  --from-file=app.ini=/CAMINHO/SEGURO/app.ini
kubectl --kubeconfig /home/coder/talos/kubeconfig apply -f /home/coder/talos/forgejo/deployment.yaml
kubectl --kubeconfig /home/coder/talos/kubeconfig apply -f /home/coder/talos/forgejo/service.yaml
```

O deployment espera um `Secret` chamado `forgejo-app-ini` com a chave `app.ini`.
Use [app.ini.example](/home/coder/talos/forgejo/app.ini.example:1) como base, mas nao comite o arquivo final com segredo real.

## Migracao da VM

Se a VM atual ja tem o Forgejo funcionando, nao basta assumir que tudo esta em um unico diretorio.
No ambiente antigo desta migracao, foi confirmado:

- binario rodando com `--config /etc/forgejo/app.ini`
- `WORK_PATH = /var/lib/forgejo`
- `APP_DATA_PATH = /var/lib/forgejo/data`
- `ROOT = /var/lib/forgejo/data/forgejo-repositories`
- banco em `MySQL` com `HOST = 127.0.0.1:3306`
- `START_SSH_SERVER = false`

Importante:

- o arquivo de configuracao principal fica em `/etc/forgejo/app.ini`
- o storage local fica em `/var/lib/forgejo/data`
- `custom/` estava vazio na VM antiga
- nao foi encontrado `forgejo.db`, entao a migracao depende do dump e restore do MySQL antigo
- nao salvar a senha do banco neste repositorio; recuperar do host antigo quando for subir o deployment final

Fluxo recomendado:

1. Parar o Forgejo antigo na VM para congelar escrita.
2. Gerar backup do storage local em `/var/lib/forgejo/data`.
3. Gerar dump consistente do MySQL usado pelo Forgejo.
4. Guardar uma copia de `/etc/forgejo/app.ini` fora da VM.
5. Subir o PVC no cluster.
6. Restaurar o backup dentro do volume montado em `/data`.
7. Adaptar o `app.ini` antigo para o layout do container no Kubernetes.
8. Provisionar ou restaurar o banco MySQL no cluster ou em host externo acessivel.
9. Subir o deployment.

Itens que vivem no storage local desta instalacao:

- repositorios git
- packages
- actions
- anexos, avatars e lfs

Itens que nao vieram junto so com o tar de `/var/lib/forgejo/data`:

- configuracao principal em `/etc/forgejo/app.ini`
- banco MySQL antigo

Estado observado no restore para o PVC:

- apareceu `/data/data/...`
- nao apareceu `custom/` com conteudo util
- nao apareceu `log/` como item critico de restore

Isso indica que o tar restaurado trouxe o storage local, mas ainda falta tratar configuracao e banco.

## Proximo passo da migracao

Antes de subir o Forgejo no cluster, fechar estes itens:

- criar ou restaurar o banco MySQL que o Forgejo vai usar
- ajustar `app.ini` para os paths do container, por exemplo `/data` em vez de `/var/lib/forgejo/data`
- revisar `ROOT_URL`, `SSH_PORT`, `SSH_DOMAIN` e portas publicadas pelo `service.yaml`
- decidir se o MySQL vai rodar no cluster ou fora dele
- injetar o `app.ini` no pod do Forgejo sem commitar segredo no repo

Exemplo de checagens uteis na VM antiga:

```bash
mysqldump -u forgejo -p forgejo > /root/forgejo.sql
sed -n '1,240p' /etc/forgejo/app.ini
```

Fluxo sugerido para fechar a migracao:

1. Tirar dump do banco antigo:

```bash
mysqldump -u forgejo -p --single-transaction --routines --triggers forgejo > /root/forgejo.sql
```

2. Copiar o `app.ini` antigo e adaptar usando [app.ini.example](/home/coder/talos/forgejo/app.ini.example:1):

- `WORK_PATH = /data`
- `APP_DATA_PATH = /data/data`
- `ROOT = /data/data/forgejo-repositories`
- `ROOT_PATH = /data/log`
- `ROOT_URL = http://IP_DO_NODE:30090/`
- `SSH_PORT = 30222`
- `START_SSH_SERVER = true`
- `SSH_DOMAIN = IP_DO_NODE_OU_DOMINIO`
- `HOST` do MySQL apontando para o banco novo

3. Criar o `Secret` com o `app.ini` ajustado:

```bash
kubectl --kubeconfig /home/coder/talos/kubeconfig create secret generic forgejo-app-ini \
  -n forgejo \
  --from-file=app.ini=/CAMINHO/SEGURO/app.ini \
  --dry-run=client -o yaml | kubectl --kubeconfig /home/coder/talos/kubeconfig apply -f -
```

4. Restaurar o dump no MySQL de destino.

Exemplo usando o banco deste diretorio:

```bash
kubectl --kubeconfig /home/coder/talos/kubeconfig create secret generic forgejo-mysql \
  -n forgejo \
  --from-literal=mysql-root-password='ROOT_PASSWORD' \
  --from-literal=mysql-database='forgejo' \
  --from-literal=mysql-user='forgejo' \
  --from-literal=mysql-password='APP_PASSWORD' \
  --dry-run=client -o yaml | kubectl --kubeconfig /home/coder/talos/kubeconfig apply -f -

kubectl --kubeconfig /home/coder/talos/kubeconfig apply -f /home/coder/talos/forgejo/mysql-pvc.yaml
kubectl --kubeconfig /home/coder/talos/kubeconfig apply -f /home/coder/talos/forgejo/mysql-service.yaml
kubectl --kubeconfig /home/coder/talos/kubeconfig apply -f /home/coder/talos/forgejo/mysql-deployment.yaml
kubectl --kubeconfig /home/coder/talos/kubeconfig rollout status -n forgejo deploy/forgejo-mysql
```

Observacao:

- o dump antigo usou a collation `utf8mb4_uca1400_as_cs`
- essa collation e de MariaDB e falha ao restaurar em `mysql:8`
- por isso o manifest `mysql-deployment.yaml` usa `mariadb:11.6`

No `app.ini`, use:

- `HOST = forgejo-mysql:3306`
- `NAME = forgejo`
- `USER = forgejo`
- `PASSWD = APP_PASSWORD`

Restore do dump:

```bash
kubectl --kubeconfig /home/coder/talos/kubeconfig cp /root/forgejo.sql forgejo/forgejo-mysql-DEPLOYMENT_POD:/tmp/forgejo.sql
kubectl --kubeconfig /home/coder/talos/kubeconfig exec -n forgejo -it forgejo-mysql-DEPLOYMENT_POD -- \
  sh -c 'mysql -u root -p"$MYSQL_ROOT_PASSWORD" forgejo < /tmp/forgejo.sql'
```

5. Aplicar deployment e service.

6. Validar logs:

```bash
kubectl --kubeconfig /home/coder/talos/kubeconfig logs -n forgejo deploy/forgejo
kubectl --kubeconfig /home/coder/talos/kubeconfig get pods -n forgejo -w
```

Exemplo de checagens uteis no cluster depois da restauracao:

```bash
kubectl --kubeconfig /home/coder/talos/kubeconfig get pvc -n forgejo
kubectl --kubeconfig /home/coder/talos/kubeconfig get pods -n forgejo -o wide
```

Se o deployment novo subir usando so o PVC restaurado, sem o MySQL antigo e sem o `app.ini` adaptado, o comportamento esperado e falha de conexao com banco ou inicializacao incompleta.

## Ajustes depois da subida

Depois de abrir a interface no cluster, valide principalmente:

- `ROOT_URL`
- dominio/IP publico
- porta SSH anunciada
- configuracao do registry
- conectividade com o MySQL configurado

Se a VM antiga usava outra URL, provavelmente voce vai precisar ajustar o `app.ini` migrado.

## DNS local e registry

Quando o Forgejo passou a ficar atras do Traefik com hostname local, foi necessario criar um registro DNS no Pi-hole para esse nome.

Exemplo usado:

- `forgejo.home.arpa -> 192.168.1.194`

Sem isso, o acesso no browser pode ate funcionar via `/etc/hosts`, mas ferramentas que rodam em containers, como `docker buildx`, podem continuar falhando porque consultam o DNS configurado na rede em vez do `/etc/hosts` da maquina.

Sintoma observado:

- `docker buildx` falhando com `lookup forgejo.home.arpa on 192.168.1.233:53: no such host`

Solucao:

1. No Pi-hole, adicionar um `Local DNS Record` para o hostname do Forgejo apontando para o IP do `Service` do Traefik.
2. Recriar o builder do `buildx` depois da mudanca de DNS:

```bash
sudo docker buildx rm mybuilder
sudo docker buildx create --name mybuilder --use
sudo docker buildx inspect --bootstrap
```

3. Testar resolucao contra o Pi-hole.

No Arch Linux, o comando `dig` nao e um pacote separado. Ele vem no pacote `bind`.

```bash
sudo pacman -S bind
dig @192.168.1.233 forgejo.home.arpa
```

Se preferir, tambem da para testar com:

```bash
getent hosts forgejo.home.arpa
```

## Estado atual da migracao para NFS

O Forgejo foi migrado do `local-path` para NFS.

Paths usados no NFS:

- dados do app: `/srv/backup/nfs/forgejo`
- dump do banco: `/srv/backup/nfs/forgejo-mysql/forgejo.sql`

PVCs atuais:

- [pvc.yaml](/home/coder/talos/forgejo/pvc.yaml) aponta para `/srv/backup/nfs/forgejo`
- [mysql-pvc.yaml](/home/coder/talos/forgejo/mysql-pvc.yaml) aponta para `/srv/backup/nfs/forgejo-mysql`

Fluxo que funcionou:

1. Copiar os dados do Forgejo para o NFS.
2. Fazer dump do MariaDB antigo com `mariadb-dump`.
3. Importar o dump no MariaDB novo no cluster.
4. Ajustar o `Secret` `forgejo-app-ini`.
5. Reiniciar o deployment do Forgejo.

### Detalhe importante do storage restaurado

Depois da copia dos dados para o NFS, o layout ficou com uma arvore duplicada.

Exemplo observado:

- `/data`
- `/data/data`
- repositorios git em `/data/data/data/forgejo-repositories`

Por causa disso, para o estado atual funcionar, o `app.ini` precisou ficar apontando para:

- `WORK_PATH = /data`
- `APP_DATA_PATH = /data/data`
- `ROOT = /data/data/data/forgejo-repositories`
- `ROOT_PATH = /data/log`

Isso nao e o layout ideal, mas ficou funcional.

Consequencia:

- a migracao esta operacional
- login voltou
- repositorios voltaram
- push voltou

Pendencia tecnica:

- reorganizar o conteudo do NFS depois, com o Forgejo parado, para remover o nivel extra de `data`
- depois disso, simplificar o `ROOT` para um path mais limpo

## Estado atual da migracao para Longhorn

O Forgejo foi migrado de NFS para `Longhorn`.

Volumes novos usados na migracao:

- app: PVC `forgejo-longhorn`
- banco: PVC `forgejo-mysql-longhorn`

Fluxo que funcionou:

1. Criar novos PVCs em `Longhorn`.
2. Parar o workload do `Forgejo`.
3. Montar o PVC antigo e o PVC novo no pod temporario `forgejo-data-copy`.
4. Copiar os dados do app com `cp -a /data/. /longhorn/`.
5. Manter o `forgejo-mysql` antigo ligado so para gerar dump.
6. Gerar dump com `mariadb-dump` para `/tmp/forgejo.sql`.
7. Subir o `forgejo-mysql` novo apontando para `forgejo-mysql-longhorn`.
8. Copiar o dump para o pod novo e importar com `mariadb`.
9. Ajustar o deployment do `Forgejo` para usar `forgejo-longhorn`.
10. Apagar o pod temporario `forgejo-data-copy` para liberar o volume `ReadWriteOnce`.

Exemplo do pod temporario para montar os dois PVCs:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: forgejo-data-copy
  namespace: forgejo
spec:
  restartPolicy: Never
  containers:
    - name: copy
      image: alpine:3.22
      command: ["/bin/sh", "-c", "sleep 36000"]
      volumeMounts:
        - name: old-data
          mountPath: /data
        - name: new-data
          mountPath: /longhorn
  volumes:
    - name: old-data
      persistentVolumeClaim:
        claimName: forgejo-data
    - name: new-data
      persistentVolumeClaim:
        claimName: forgejo-longhorn
```

Aplicacao e copia:

```bash
kubectl apply -f /home/coder/talos/forgejo/longhorn-migrator/pod-for-copy.yaml
kubectl -n forgejo exec -it forgejo-data-copy -- sh
cp -a /data/. /longhorn/
```

Observacoes importantes:

- o pod temporario de copia pode impedir o start do `Forgejo` com erro de `Multi-Attach`
- nesse caso, apagar `forgejo-data-copy` depois da copia
- o dump `forgejo.sql` nao vai direto para o PVC; ele e importado no `MariaDB`, que grava os dados no volume novo
- durante a migracao, o `Longhorn` precisou de ajuste no numero de replicas de `3` para `2`

Estado final observado:

- `Forgejo` funcionando normalmente no cluster
- dados do app em `Longhorn`
- `MariaDB` do `Forgejo` em `Longhorn`
- login e operacao basica funcionando
