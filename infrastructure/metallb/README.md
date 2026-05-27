# MetalLB

## Modo Layer2 na rede local

Este cluster usa `kube-proxy` em modo `nftables`, nao `ipvs`.

Por causa disso:

- nao e necessario ajustar `strictARP`
- nao e necessario fazer a preparacao de `IPVS` do `kube-proxy`

Comando para verificar:

```bash
kubectl -n kube-system get ds kube-proxy -o yaml
```

Procurar por:

```text
--proxy-mode=nftables
```

## Quando usar Layer2

Usar `Layer2` quando:

- o cluster esta em uma LAN comum de casa ou escritorio
- o objetivo e dar IPs de `LoadBalancer` para os services dentro da sub-rede local
- nao existe necessidade de configurar `BGP` no roteador ou switch

`Layer2` e o caminho mais simples para usar `MetalLB` em rede local.

## Pre-requisitos

Antes de criar o pool:

1. Escolher uma faixa de IPs na mesma sub-rede dos nodes.
2. Garantir que essa faixa nao esta sendo usada pelo DHCP.
3. Garantir que esses IPs nao estao em uso por outros dispositivos.
4. Reservar essa faixa apenas para o `MetalLB`.

Exemplo de faixa:

```text
192.168.1.200-192.168.1.220
```

## Passo 1: Instalar o MetalLB

Exemplo de instalacao estavel:

```bash
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.15.3/config/manifests/metallb-native.yaml
```

Verificar:

```bash
kubectl get pods -n metallb-system -o wide
```

Esperado:

- `controller` em `Running`
- um `speaker` em cada node

## Passo 2: Criar um pool de IPs

Criar um manifesto `IPAddressPool`.

Exemplo:

```yaml
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: default-pool
  namespace: metallb-system
spec:
  addresses:
    - 192.168.1.200-192.168.1.220
```

Aplicar:

```bash
kubectl apply -f ipaddresspool.yaml
```

## Passo 3: Criar um anuncio Layer2

Criar um manifesto `L2Advertisement`.

Exemplo:

```yaml
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: default-l2
  namespace: metallb-system
spec: {}
```

Aplicar:

```bash
kubectl apply -f l2advertisement.yaml
```

## Passo 4: Verificar os recursos do MetalLB

```bash
kubectl get ipaddresspools.metallb.io -n metallb-system
kubectl get l2advertisements.metallb.io -n metallb-system
```

## Passo 5: Testar com um service LoadBalancer

Criar ou ajustar um service com:

```yaml
spec:
  type: LoadBalancer
```

Verificacao:

```bash
kubectl get svc -A
```

Esperado:

- o service recebe um `EXTERNAL-IP`
- esse IP pertence a faixa configurada no `MetalLB`

## Passo 6: Testar a partir da LAN

De outra maquina da rede local:

```bash
ping EXTERNAL_IP
curl http://EXTERNAL_IP
```

Ou acessar direto pelo navegador.

## Comandos uteis

Ver os pods do MetalLB:

```bash
kubectl get pods -n metallb-system -o wide
```

Ver eventos:

```bash
kubectl get events -n metallb-system --sort-by=.metadata.creationTimestamp
```

Descrever o service:

```bash
kubectl describe svc NAMESPACE/NAME
```

## Observacoes

- `Layer2` normalmente e suficiente para homelab.
- `BGP` so faz sentido se o roteador ou switch suportar BGP e houver necessidade de roteamento mais avancado.
- o `MetalLB` apenas entrega o IP externo; o service ainda depende de pods saudaveis por tras.

## Estado atual no cluster

O `MetalLB` foi adicionado no cluster sem problemas relevantes.

Estado validado:

- `controller` em `Running`
- `speaker` em todos os nodes
- pool de IPs funcionando normalmente
- anuncios `Layer2` funcionando na LAN

Servicos ja testados com IP fixo:

- `Forgejo`
- `Grafana`
- `Loki`

Todos ja estao funcionando com:

- `type: LoadBalancer`
- IP fixo na LAN
- sem `NodePort` por tras

Observacao importante:

- para remover `NodePort` de services antigos, foi necessario recriar o service depois de ajustar:

```yaml
allocateLoadBalancerNodePorts: false
```

Em alguns casos, alterar um service existente nao remove o `NodePort` antigo automaticamente.
Apagar e recriar o service resolve isso de forma limpa.
