# Traefik no cluster

Instalacao baseada na documentacao oficial do Traefik com Helm:

- https://doc.traefik.io/traefik/v3.3/getting-started/install-traefik/
- https://doc.traefik.io/traefik/v3.6/reference/install-configuration/providers/kubernetes/kubernetes-ingress/

O objetivo aqui foi usar:

- `Traefik` como ingress controller
- `Ingress` tradicional do Kubernetes
- `MetalLB` para entregar um IP fixo na LAN
- apps internos expostos como `ClusterIP`

## Arquivos desta pasta

- [namespace.yaml](/home/henrique/talos/traefik/namespace.yaml)
- [values.yaml](/home/henrique/talos/traefik/values.yaml)

## Fluxo da rede

O desenho final ficou assim:

```text
cliente -> 192.168.1.194 -> Traefik -> Ingress -> Service ClusterIP -> Pod
```

Ponto importante:

- o IP fixo da LAN fica no `Service LoadBalancer` do `Traefik`
- os apps deixam de ter `LoadBalancer` proprio
- cada app fica com `Service type=ClusterIP`
- o `Ingress` decide qual app recebe a requisicao

## Instalacao

Adicionar o repo do chart:

```bash
helm repo add traefik https://traefik.github.io/charts
helm repo update
```

Criar o namespace:

```bash
kubectl --kubeconfig /home/henrique/talos/kubeconfig apply -f /home/henrique/talos/traefik/namespace.yaml
```

Instalar com Helm:

```bash
helm upgrade --install traefik traefik/traefik \
  -n traefik \
  --create-namespace \
  -f /home/henrique/talos/traefik/values.yaml
```

## O que foi configurado no values

O [values.yaml](/home/henrique/talos/traefik/values.yaml) faz o seguinte:

- sobe `2 replicas` do Traefik
- cria a `IngressClass` chamada `traefik`
- habilita o provider `kubernetesIngress`
- publica o endpoint correto usando `publishedService`
- cria um `Service type=LoadBalancer`
- pede o IP `192.168.1.194` ao `MetalLB`
- expoe:
  - `web` em `80`
  - `websecure` em `443`
- redireciona `80 -> 443`
- habilita TLS no entrypoint `websecure`

## Validacao

Comandos uteis:

```bash
kubectl --kubeconfig /home/henrique/talos/kubeconfig get pods -n traefik -o wide
kubectl --kubeconfig /home/henrique/talos/kubeconfig get svc -n traefik
kubectl --kubeconfig /home/henrique/talos/kubeconfig get ingressclass
kubectl --kubeconfig /home/henrique/talos/kubeconfig describe svc traefik -n traefik
helm list -n traefik
```

Esperado:

- pods do Traefik em `Running`
- `Service` `traefik` com `EXTERNAL-IP` `192.168.1.194`
- `IngressClass` `traefik` criada

## DNS local para teste

Se o hostname do `Ingress` ainda nao existir no seu DNS local, o acesso no browser nao vai abrir mesmo com o `Ingress` funcionando.

Para testes iniciais, foi necessario adicionar no cliente uma entrada em `/etc/hosts` apontando o hostname do app para o IP do `Traefik`.

Exemplo:

```text
192.168.1.194 agente-ingles.home.arpa
```

Depois disso, o acesso passa a funcionar por:

```text
https://agente-ingles.home.arpa
```

Validacao rapida:

```bash
getent hosts agente-ingles.home.arpa
```

## Como expor apps

Para usar o Traefik:

1. o app deve ter `Service type=ClusterIP`
2. criar um recurso `Ingress`
3. no `Ingress`, usar:

```yaml
spec:
  ingressClassName: traefik
```

Exemplo de annotations comuns:

```yaml
metadata:
  annotations:
    traefik.ingress.kubernetes.io/router.entrypoints: websecure
    traefik.ingress.kubernetes.io/router.tls: "true"
```

## Observacao sobre HTTPS

Neste ponto o Traefik ja recebe trafego em `443`, mas isso nao significa automaticamente certificado publico valido.

Ou seja:

- o fluxo HTTPS ja existe
- o certificado confiavel para browser/API ainda e o proximo passo

Os caminhos depois daqui sao:

- `Traefik + cert-manager`
- `Traefik + Tailscale`
