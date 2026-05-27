# WireGuard on Talos

## Objetivo

Subir o WireGuard no cluster Talos/Kubernetes para aprender:

- `Deployment` ou `StatefulSet`
- `Service` UDP
- `Secret`
- `PersistentVolumeClaim`
- fixar workload em no especifico
- como o Talos lida com rede e seguranca

## Estrategia

Primeiro usar o cluster apenas como laboratorio.

- nao desligar a VM Ubuntu ainda
- subir o WireGuard no Talos
- testar tudo
- comparar com a VM atual
- so depois decidir se vale migrar

## Decisoes atuais

- usar `Deployment`
- usar `hostNetwork`
- nao usar `Service` no primeiro momento
- prender o workload em um node com label dedicada
- usar `wg-easy`
- usar `8080/tcp` para a interface web
- usar `51820/udp` para o WireGuard
- acesso somente local/laboratorio no primeiro momento

## Multi-arquitetura

Para este projeto, a primeira coisa importante e separar 2 conceitos:

- imagem multi-arquitetura
- agendamento do workload no node certo

No caso do `wg-easy`, a imagem oficial ja suporta arquiteturas modernas como `x86_64` e `arm64`.
Entao, para um cluster misto `amd64 + arm64`, nao precisamos manter duas imagens diferentes so por causa da arquitetura.

O que passa a importar e:

- usar uma imagem oficial multi-arch
- fixar o workload em um node escolhido de forma explicita

Para aprender do jeito certo, o manifesto usa label dedicada em vez de hostname hardcoded:

```yaml
affinity:
  nodeAffinity:
    requiredDuringSchedulingIgnoredDuringExecution:
      nodeSelectorTerms:
        - matchExpressions:
            - key: homelab.role/wireguard
              operator: In
              values:
                - "true"
```

Assim, voce pode mover o WireGuard entre:

- um node `amd64`
- um node `arm64`

sem mudar a imagem, apenas mudando a label do node.

Exemplo de label:

```bash
kubectl label node worker-prox homelab.role/wireguard=true --overwrite
```

Se no futuro quiser migrar para o Raspberry Pi:

```bash
kubectl label node worker-prox homelab.role/wireguard-
kubectl label node worker-rasp homelab.role/wireguard=true --overwrite
```

Observacao importante:

- para `WireGuard`, faz sentido prender o workload em um node especifico
- clientes VPN apontam para IP/porta de um host real
- entao multi-arch aqui nao significa "rodar em qualquer node ao mesmo tempo"
- significa "a mesma imagem pode rodar tanto no amd64 quanto no arm64"

## IMPORTANTE: troca de CNI

Para testar Cilium, foi necessario ajustar os machine configs para:

```yaml
cluster:
  network:
    cni:
      name: none
```

Mesmo depois disso, o `Flannel` antigo continuou rodando no cluster.

Entao tambem foi necessario remover manualmente o `DaemonSet` antigo:

```bash
kubectl --kubeconfig /home/coder/talos/kubeconfig delete daemonset kube-flannel -n kube-system
```

Sem isso, apagar apenas o pod do Flannel nao funciona, porque o `DaemonSet` recria o pod.

## IMPORTANTE: Pod Security

Para este projeto, existe grande chance de precisar de namespace com Pod Security `privileged`.

Fazer isso logo no inicio para nao esquecer:

```bash
kubectl --kubeconfig /home/coder/talos/kubeconfig create namespace wireguard

kubectl --kubeconfig /home/coder/talos/kubeconfig label namespace wireguard \
  pod-security.kubernetes.io/enforce=privileged \
  pod-security.kubernetes.io/audit=privileged \
  pod-security.kubernetes.io/warn=privileged --overwrite
```

Motivo:

- WireGuard mexe com rede de baixo nivel
- pode exigir capabilities e ajustes que um namespace restrito bloquearia
- isso ja evitou dor de cabeca antes com outros componentes

## O que decidir antes de criar manifests

1. Qual imagem usar:
   - `ghcr.io/wg-easy/wg-easy:15`
2. Onde o workload vai rodar:
   - em um node com label `homelab.role/wireguard=true`
3. Como expor:
   - direto pela rede do host com `hostNetwork`
4. O que precisa persistir:
   - chaves
   - config
   - peers
   - volume montado em `/etc/wireguard`
5. Se vai usar:
   - `hostNetwork`
   - sem `Service` no primeiro momento

## Ordem sugerida

1. Escolher a imagem do WireGuard.
2. Criar namespace dedicado.
3. Criar `Secret` para variaveis sensiveis.
4. Criar `PVC` para persistencia.
5. Criar `Deployment` preso no `worker`.
6. Testar acesso direto no IP do worker.
7. Testar acesso externo/local.
8. Validar persistencia apos restart.
9. Comparar com a VM Ubuntu atual.

## Possiveis dificuldades

- portas UDP no host
- `hostNetwork` vs `NodePort`
- permissoes/capabilities para WireGuard
- persistencia de config e chaves
- diferenca entre rede do pod e rede do host
- regras de firewall/NAT fora do cluster

## Proximo passo

Montar os manifests com base inicial do `wg-easy`.

## O que o manifesto atual ensina

- `hostNetwork: true`
  - o pod usa a rede do node
  - isso simplifica UDP e reduz surpresa com tunel VPN

- `hostPort`
  - deixa explicito que o node vai abrir `8080/tcp` e `51820/udp`
  - como o pod ja usa `hostNetwork`, isso serve mais como documentacao operacional

- `nodeAffinity`
  - evita acoplamento com hostname antigo
  - permite mover entre `amd64` e `arm64` so com label

- `PVC`
  - mantem peers, chaves e configuracao em `/etc/wireguard`

- capability `NET_ADMIN`
  - necessaria para o WireGuard
  - `SYS_MODULE` continuou fora porque no Talos isso costuma falhar

## Variaveis iniciais do wg-easy

- `PORT=8080`
- `HOST=0.0.0.0`
- `INSECURE=true`
- `DISABLE_IPV6=true`

## Portas

- web UI:
  - `8080/tcp`
- tunnel WireGuard:
  - `51820/udp`

## Persistencia

- usar `PVC`
- montar em:
  - `/etc/wireguard`

## Troubleshooting que apareceu

### Capabilities no Talos

No `Deployment` do `wg-easy`, tentar usar:

- `NET_ADMIN`
- `SYS_MODULE`

causou erro de permissao no Talos.

O `SYS_MODULE` nao foi permitido.

Conclusao pratica:

- para este workload, deixar apenas:
  - `NET_ADMIN`

### Problema antigo com Flannel e local-path

Antes de trocar para Cilium, o `Flannel` estava causando problemas com o `local-path-provisioner`.

Isso gerava erros de rede e atrapalhava `PVC` e helper pods.

Depois da troca para `Cilium`, esse problema deixou de incomodar.
