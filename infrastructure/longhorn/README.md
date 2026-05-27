# Longhorn

Objetivo:

- estudar `Longhorn` como storage distribuido para Kubernetes
- reduzir dependencia do NFS da VM `nextcloud`
- migrar workloads do NFS para Longhorn de forma gradual

## Ideia geral

O Longhorn nao converte o NFS inteiro automaticamente.

A migracao seria:

- workload por workload
- volume por volume

Ou seja:

1. instalar o Longhorn no cluster
2. criar `StorageClass` do Longhorn
3. criar novo PVC Longhorn para uma app especifica
4. parar a app
5. copiar os dados do PVC NFS antigo para o PVC Longhorn novo
6. trocar o deployment/statefulset para o PVC novo
7. subir a app e validar

## Recomendacao atual

Nao migrar tudo de uma vez.

Ordem sugerida:

1. testar Longhorn
2. validar funcionamento basico
3. migrar primeiro um workload simples
4. manter NFS como fallback por um tempo

## Estado atual do lab

Hoje o ambiente ficou assim:

- `worker-rasp` com SSD local dedicado
- `worker-prox` com HD local novo anexado na VM `108`
- NFS da VM `nextcloud` continua existindo e funcionando

Objetivo atual:

- usar Longhorn com discos locais em dois nodes do cluster
- manter o NFS como fallback enquanto a migracao nao estiver madura

## Ordem recomendada agora

1. preparar os dois workers para o Longhorn
2. validar prerequisitos especificos do Talos
3. instalar Longhorn
4. testar um PVC pequeno
5. migrar primeiro o `grafana-test`
6. depois migrar o Grafana principal
7. so depois pensar em `wireguard`, `duckdns`, `loki`
8. deixar `forgejo` por ultimo

## Talos

Para Talos, a documentacao do Longhorn pede alguns cuidados especificos.

Requisitos principais:

- `PodSecurity` privilegiado para o namespace do Longhorn
- extensoes de sistema:
  - `siderolabs/iscsi-tools`
  - `siderolabs/util-linux-tools`
- preparar os discos locais para uso no host

Observacao importante:

- em Talos `v1.10+`, o caminho recomendado e usar `UserVolumeConfig`
- o path costuma ser montado em `/var/mnt/<nome>`

Arquivo de schematic criado:

- `longhorn/talos-schematic.yaml`

Esse schematic serve para gerar a imagem/custom installer do Talos com as extensoes que o Longhorn precisa.

Conteudo:

- `siderolabs/iscsi-tools`
- `siderolabs/util-linux-tools`

Observacao:

- isso nao entra via `apply-config`
- isso entra via imagem customizada do Talos
- como o cluster tem `amd64` e `arm64`, a mesma schematic serve para os dois, mas o installer final muda por arquitetura

Para deixar claro o papel desse arquivo:

- `talos-schematic.yaml` nao instala nada sozinho no cluster
- ele descreve quais `systemExtensions` devem entrar na imagem do Talos
- ele foi enviado ao `Image Factory`
- o `Image Factory` devolveu um `schematic id`
- esse `schematic id` foi usado para montar a imagem:
  - `factory.talos.dev/metal-installer/<SCHEMATIC_ID>:v1.12.6`
- essa imagem foi usada no `talosctl upgrade` dos workers

Resumo pratico:

- `worker-prox.yaml` e `worker-rasp.yaml` configuram os nodes
- `talos-schematic.yaml` customiza a imagem do sistema operacional

## Instalacao real do Longhorn

Primeiro, a instalacao foi feita usando diretamente o manifest oficial do site do Longhorn:

```bash
kubectl apply -f https://raw.githubusercontent.com/longhorn/longhorn/v1.11.1/deploy/longhorn.yaml
```

URL usada:

- https://raw.githubusercontent.com/longhorn/longhorn/v1.11.1/deploy/longhorn.yaml

Observacao importante:

- o arquivo local `longhorn/longhorn-v1.11.1.yaml` foi baixado/customizado como referencia
- mas a instalacao real que subiu o cluster foi feita pela URL oficial acima

Logo depois, foi necessario corrigir o namespace `longhorn-system` para `PodSecurity` privilegiado.

Sem isso, o `longhorn-manager` falha com erro de `violates PodSecurity "baseline:latest"`.

Comando aplicado:

```bash
kubectl label namespace longhorn-system \
  pod-security.kubernetes.io/enforce=privileged \
  pod-security.kubernetes.io/enforce-version=latest \
  pod-security.kubernetes.io/audit=privileged \
  pod-security.kubernetes.io/audit-version=latest \
  pod-security.kubernetes.io/warn=privileged \
  pod-security.kubernetes.io/warn-version=latest \
  --overwrite
```

Depois disso, foi necessario reiniciar os workloads do Longhorn:

```bash
kubectl -n longhorn-system rollout restart daemonset/longhorn-manager
kubectl -n longhorn-system rollout restart deployment/longhorn-driver-deployer
kubectl -n longhorn-system rollout restart deployment/longhorn-ui
```

## Replica configuration

Depois que o Longhorn ficou funcional, os primeiros PVCs de teste ficaram com status `Degraded`.

O motivo foi simples:

- a `StorageClass` original `longhorn` vinha do manifest oficial
- ela foi criada com `numberOfReplicas: "3"`
- no lab atual, os volumes de dados do Longhorn estao em apenas dois workers:
  - `worker-prox`
  - `worker-rasp`

Com isso, o volume funcionava, mas nao conseguia satisfazer 3 replicas e ficava `Degraded`.

Tentativa que nao funciona:

- editar a `StorageClass` original em cima
- `StorageClass.parameters` e imutavel

Solucao adotada:

- criar uma nova `StorageClass` local em `longhorn/longhorn-config.yaml`
- manter o provisioner do Longhorn
- mudar apenas `numberOfReplicas` para `2`
- usar essa nova classe nos PVCs de teste

Arquivo usado:

- `longhorn/longhorn-config.yaml`

Aplicacao:

```bash
kubectl apply -f /home/coder/talos/longhorn/longhorn-config.yaml
```

Depois disso:

1. os PVCs/pods de teste antigos foram removidos
2. os PVCs de teste foram recriados usando a nova `StorageClass`
3. os volumes passaram de `Degraded` para `Healthy`

Resumo pratico:

- `longhorn` original: 3 replicas
- `longhorn-2` no `longhorn-config.yaml`: 2 replicas
- para este cluster atual, `2` replicas e o valor correto

## Upgrade real feito nos dois workers

Depois da instalacao inicial, ficou claro que o Longhorn no Talos ainda precisava de prerequisitos no host.

Nao bastou aplicar manifests do Kubernetes.

Foi necessario fazer upgrade dos dois workers com uma imagem customizada do Talos contendo as extensoes exigidas pelo Longhorn.

Fluxo executado:

1. criar o schematic no `Image Factory` usando `longhorn/talos-schematic.yaml`
2. obter o `schematic id`
3. montar a imagem de installer customizada:
   - `factory.talos.dev/metal-installer/<SCHEMATIC_ID>:v1.12.6`
4. fazer `talosctl upgrade` em `worker-prox`
5. validar extensoes e `iscsid`
6. fazer `talosctl upgrade` em `worker-rasp`
7. validar extensoes e `iscsid`

Exemplo de upgrade:

```bash
talosctl -e 192.168.1.113 -n 192.168.1.152 upgrade \
  --image factory.talos.dev/metal-installer/<SCHEMATIC_ID>:v1.12.6 \
  --wait

talosctl -e 192.168.1.113 -n 192.168.1.153 upgrade \
  --image factory.talos.dev/metal-installer/<SCHEMATIC_ID>:v1.12.6 \
  --wait
```

Observacao:

- durante o upgrade pode aparecer `connection reset by peer`
- isso pode acontecer no reboot da troca de installer
- o importante e validar o node depois que ele volta

Validacao feita apos o upgrade:

```bash
talosctl -e 192.168.1.113 -n 192.168.1.152 get extensions
talosctl -e 192.168.1.113 -n 192.168.1.153 get extensions
talosctl -e 192.168.1.113 -n 192.168.1.152 service iscsid
talosctl -e 192.168.1.113 -n 192.168.1.153 service iscsid
```

Resultado esperado:

- extensoes `siderolabs/iscsi-tools`
- extensoes `siderolabs/util-linux-tools`
- servico `iscsid` registrado e ativo nos workers

## Extra mount no kubelet

Depois do upgrade dos workers, ainda foi necessario ajustar o `kubelet`.

No Talos, o `kubelet` roda containerizado.

Para o Longhorn funcionar corretamente com propagacao de mounts, foi necessario adicionar `extraMounts` em `machine.kubelet` nos dois workers.

Trecho aplicado:

```yaml
machine:
  kubelet:
    extraMounts:
      - destination: /var/lib/longhorn
        type: bind
        source: /var/lib/longhorn
        options:
          - bind
          - rshared
          - rw
```

Esse bloco nao entra como documento separado com `---`.

Ele entra dentro de `machine.kubelet` no YAML principal de cada worker:

- `worker-prox.yaml`
- `worker-rasp.yaml`

Motivo:

- o Longhorn faz mounts no host
- o `kubelet` precisa enxergar esses mounts corretamente
- o `rshared` e o ponto critico para a propagacao funcionar

Sem isso, o Longhorn pode instalar, mas falhar em attach/mount dos volumes.

Resumo do que entrou de novo no Talos por causa do Longhorn:

- `siderolabs/iscsi-tools`
- `siderolabs/util-linux-tools`
- `iscsid`
- `extraMounts` do kubelet para `/var/lib/longhorn`
- namespace `longhorn-system` com `PodSecurity` privilegiado

## Acesso a UI

Para acessar a UI do Longhorn de forma rapida, foi usado `port-forward` no service `longhorn-frontend`.

No caso de acesso local na propria maquina:

```bash
kubectl -n longhorn-system port-forward svc/longhorn-frontend 8080:80
```

Depois abrir:

```text
http://127.0.0.1:8080
```

No caso de acesso pela VM/IP da rede, foi necessario expor no endereco da maquina:

```bash
kubectl -n longhorn-system port-forward --address 0.0.0.0 svc/longhorn-frontend 8080:80
```

Depois abrir:

```text
http://<IP_DA_VM>:8080
```

Observacao:

- `port-forward` nao cria recurso no Kubernetes
- ele so abre um tunel temporario preso ao terminal atual
- se fechar o terminal, o acesso cai

## Discos planejados

Planejamento atual:

- `worker-rasp`: SSD local novo
- `worker-prox`: HD local novo anexado na VM do worker

Ideia:

- usar os dois nodes como base das replicas do Longhorn
- evitar depender so do NFS da `nextcloud`

Estado real dos discos no Talos:

- `worker-prox`: disco novo livre em `sdb` com `500 GB`
- `worker-rasp`: SSD em `sda1 ext4` com `120 GB`, montado pelo Talos via `ExistingVolumeConfig`

Implicacao importante:

- hoje so o `worker-prox` esta pronto para receber `UserVolumeConfig` sem apagar nada
- o `worker-rasp` ainda nao pode receber um `UserVolumeConfig` para Longhorn no SSD sem antes migrar ou apagar o laboratorio atual do `CloudNativePG`
- o motivo e simples: o SSD do rasp ja esta sendo usado em `/var/mnt/ssd/cloudnative`
- no rasp, o caminho oficial do Talos para esse disco agora e `/var/mnt/ssd`

Entao o passo certo agora e:

1. preparar primeiro o `worker-prox`
2. manter o `worker-rasp` como pendencia controlada
3. depois decidir se o SSD do rasp sera:
   - migrado para Longhorn
   - reparticionado
   - ou mantido temporariamente para o laboratorio atual

## Estrategia de transicao aprovada

Decisao pratica para este lab:

- manter o `CloudNativePG` onde esta hoje
- nao desmontar o Postgres agora
- criar uma pasta separada para o Longhorn dentro do mesmo SSD do `worker-rasp`

Layout temporario planejado no rasp:

- `/var/mnt/ssd/cloudnative`
- `/var/mnt/ssd/longhorn`

Ideia:

1. `CloudNativePG` continua em `/var/mnt/ssd/cloudnative`
2. Longhorn usa `/var/mnt/ssd/longhorn` no rasp
3. Longhorn usa tambem o disco novo do `worker-prox`
4. primeiro migra um workload simples, como `grafana-test`
5. depois, quando o Longhorn estiver estavel, migrar o `CloudNativePG` para dentro do Longhorn

Observacao importante:

- isso e uma estrategia de transicao
- no `worker-rasp`, `cloudnative` e `longhorn` ainda dividem o mesmo SSD
- entao nao e o desenho final ideal
- mas e o caminho mais pragmático para aprender e evoluir sem desmontar o que ja funciona

## UserVolumeConfig no worker-prox

Arquivo criado:

- `longhorn/worker-prox-longhorn-volume.yaml`

Esse patch cria um `UserVolumeConfig` chamado `longhorn` no disco novo do `worker-prox`.

Resultado esperado no host:

- Talos cria o volume
- o volume fica montado em `/var/mnt/longhorn`
- esse path pode ser entregue ao Longhorn depois

Aplicacao:

```bash
talosctl --talosconfig /home/coder/talos/talosconfig \
  -e 192.168.1.113 \
  -n 192.168.1.152 \
  patch mc --patch @/home/coder/talos/longhorn/worker-prox-longhorn-volume.yaml
```

Validacao:

```bash
talosctl --talosconfig /home/coder/talos/talosconfig \
  -e 192.168.1.113 \
  -n 192.168.1.152 \
  get volumestatus u-longhorn

talosctl --talosconfig /home/coder/talos/talosconfig \
  -e 192.168.1.113 \
  -n 192.168.1.152 \
  get mountstatus
```

O esperado e ver:

- volume `u-longhorn`
- mount em `/var/mnt/longhorn`

Estado atual validado:

- `worker-prox` ja esta pronto
- Talos criou:
  - `VolumeStatus u-longhorn`
  - particao em `/dev/sdb1`
  - mount em `/var/mnt/longhorn`
  - filesystem `xfs`

Saida validada:

- `u-longhorn` em fase `ready`
- `MountStatus u-longhorn`
- target `/var/mnt/longhorn`

## Worker-rasp

Nao aplicar `UserVolumeConfig` no SSD do rasp agora.

Antes disso, precisa resolver o conflito com o laboratorio atual:

- `CloudNativePG` esta persistindo em `/var/mnt/ssd/cloudnative`
- o disco do SSD aparece no Talos como:
  - `sda`
  - `sda1 ext4`

Se aplicar `UserVolumeConfig` nesse disco sem migracao previa, o risco e sobrescrever o storage atual do Postgres do laboratorio.

Estado atual do rasp:

- `ExistingVolumeConfig` aplicado no `worker-rasp` com `name: ssd`
- `MountStatus e-ssd` validado no target `/var/mnt/ssd`
- o `PV` do laboratorio do `CloudNativePG` continua apontando para `/var/mnt/ssd/cloudnative`
- a pasta `/var/mnt/cloudnative` ainda pode aparecer no host como diretorio residual, mas nao e mais o mount oficial do Talos

Layout temporario real no rasp:

- `/var/mnt/ssd/cloudnative`
- `/var/mnt/ssd/longhorn`

Resumo operacional atual:

- `worker-prox` fornece `/var/mnt/longhorn`
- `worker-rasp` fornece `/var/mnt/ssd/longhorn`
- com isso, o proximo passo passa a ser a instalacao do Longhorn e o cadastro correto desses dois caminhos

## Primeiro candidato

O melhor primeiro teste parece ser o Grafana.

Motivos:

- workload simples
- um pod
- dados pequenos
- problema atual suspeito: SQLite sobre NFS

## Como seria a migracao do Grafana

1. instalar Longhorn
2. criar PVC Longhorn para o Grafana
3. parar o deployment do Grafana
4. criar pod temporario montando:
   - PVC antigo NFS
   - PVC novo Longhorn
5. copiar os dados:
   - `grafana.db`
   - `plugins`
   - outros arquivos necessarios de `/var/lib/grafana`
6. alterar o deployment do Grafana para usar o PVC Longhorn
7. subir o Grafana
8. validar login, dashboards, datasource Loki e Explore
9. manter o NFS como backup

## O que nao fazer primeiro

Nao usar como primeira migracao:

- Forgejo
- MariaDB do Forgejo
- outros workloads mais sensiveis

Motivo:

- mais risco
- mais chance de downtime e erro

## Vantagens esperadas

- menos dependencia da VM NFS
- storage mais nativo de Kubernetes
- replicacao entre nos
- melhor caminho para apps stateful pequenos e medios

## Cuidados

- Longhorn adiciona complexidade ao cluster
- usa disco local dos nos
- precisa observar bem o comportamento no Raspberry
- migracao deve ser feita uma app por vez

## Decisao atual

- manter o NFS funcionando
- estudar Longhorn com calma
- preparar primeiro os dois nodes Talos
- usar o `grafana-test` como candidato mais provavel para a primeira migracao
