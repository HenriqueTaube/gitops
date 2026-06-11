# Troubleshooting — Homelab GitOps

Registro de problemas encontrados e soluções aplicadas no cluster.

---

## 1. Flux: primeiro reconcile após bootstrap

### Sintoma
`flux check` mostra `bootstrapped: false` e Kustomizations ficam presas em `Reconciliation in progress`.

### Causa
A chave SOPS age não estava no cluster e as Kustomizations não tinham a seção `decryption` configurada.

### Solução

**1. Adicionar a chave age ao cluster:**
```bash
kubectl create secret generic sops-age \
  --namespace=flux-system \
  --from-file=age.agekey=$HOME/.config/sops/age/keys.txt
```

**2. Adicionar `decryption` em todas as Kustomizations** (`platform.yaml`, `apps.yaml`, `infrastructure.yaml`):
```yaml
spec:
  decryption:
    provider: sops
    secretRef:
      name: sops-age
```

**3. Reiniciar o kustomize-controller para reconhecer a chave:**
```bash
kubectl rollout restart deployment/kustomize-controller -n flux-system
flux reconcile kustomization platform --with-source -n flux-system
```

**4. Se secrets já existirem com valores criptografados, deletar para forçar recriação:**
```bash
kubectl delete secret <nome-do-secret> -n <namespace>
flux reconcile kustomization <nome> --with-source -n flux-system
```

### Diagnóstico
```bash
# Ver status das Kustomizations
flux get kustomizations -A

# Ver se a Kustomization tem decryption configurado
kubectl get kustomization <nome> -n flux-system -o yaml | grep -A5 decryption

# Acompanhar logs do reconcile
flux logs --kind=Kustomization --name=<nome> -n flux-system -f
```

---

## 2. Secrets com valor criptografado (ENC[AES256_GCM...])

### Sintoma
Pod falha com erro de autenticação usando literalmente o texto `ENC[AES256_GCM,data:...]` como valor de variável de ambiente.

### Causa
O secret foi aplicado no cluster antes da chave SOPS estar configurada. O kustomize-controller aplicou o conteúdo cru do Git sem descriptografar.

### Solução
```bash
# Deletar o secret corrompido
kubectl delete secret <nome> -n <namespace>

# Forçar reconcile (o Flux recria com valores descriptografados)
flux reconcile kustomization <kustomization-que-gerencia-o-secret> --with-source -n flux-system

# Verificar se o valor está correto após recriação
kubectl get secret <nome> -n <namespace> -o jsonpath='{.data.<campo>}' | base64 -d
```

---

## 3. Nginx: `chown` falha com `Operation not permitted`

### Sintoma
```
chown("/var/cache/nginx/client_temp", 101) failed (1: Operation not permitted)
```

### Causa
A imagem `nginx:alpine` precisa rodar como root durante a inicialização para fazer `chown` nos diretórios de cache. Com `allowPrivilegeEscalation: false` no `securityContext`, isso é bloqueado.

### Solução
Trocar a imagem base no Dockerfile para `nginxinc/nginx-unprivileged:alpine`, que roda inteiramente como UID 101 sem precisar de root. Ajustar a porta de 80 para 8080 (portas < 1024 exigem privilégios):

```dockerfile
FROM nginxinc/nginx-unprivileged:alpine
COPY --from=build /app/dist /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf
EXPOSE 8080
```

```nginx
server {
    listen 8080;
    # ...
}
```

Atualizar o `containerPort` no Deployment e o `targetPort` nos Services para `8080`. O `port` externo do Service pode continuar `80`.

Remover `NET_BIND_SERVICE` do `securityContext` pois não é mais necessário.

---

## 4. MetalLB: LoadBalancer fica `<pending>`

### Sintoma
`kubectl get svc` mostra `EXTERNAL-IP: <pending>` indefinidamente.

### Causa A: L2Advertisement sem `ipAddressPools`
O recurso `L2Advertisement` foi criado sem referenciar o pool de IPs.

**Diagnóstico:**
```bash
kubectl get l2advertisement -A -o yaml | grep -A5 spec
```

**Solução:**
```yaml
# infrastructure/metallb/overlays/homelab/l2.yaml
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: l2
  namespace: metallb-system
spec:
  ipAddressPools:
    - homelab-pool
```

```bash
# Aplicar imediatamente sem esperar o Flux
kubectl patch l2advertisement l2 -n metallb-system \
  --type=merge -p '{"spec":{"ipAddressPools":["homelab-pool"]}}'
```

### Causa B: IP solicitado já em uso por outro Service
O `loadBalancerIP` configurado no Service já está alocado para outro serviço.

**Diagnóstico:**
```bash
kubectl get svc -A | grep LoadBalancer
```

**Solução:** alterar o `loadBalancerIP` para um IP disponível no range do pool.

**IPs alocados no homelab (pool: 192.168.1.190–195):**
| IP | Serviço |
|----|---------|
| 192.168.1.190 | grafana |
| 192.168.1.191 | forgejo |
| 192.168.1.192 | loki |
| 192.168.1.193 | agente-ingles |
| 192.168.1.194 | site-orcamentos |
| 192.168.1.195 | wireguard |

---

## 5. Diagnóstico geral útil

```bash
# Status geral do Flux
flux check
flux get kustomizations -A
flux get sources git -A

# Forçar reconcile
flux reconcile kustomization <nome> --with-source -n flux-system

# Logs de erro dos controllers
flux logs --all-namespaces --level=error

# Ver se pod está respondendo internamente
kubectl exec -n <namespace> deployment/<nome> -- wget -qO- http://127.0.0.1:<porta>

# Ver portas em escuta dentro do container
kubectl exec -n <namespace> <pod> -- cat /proc/net/tcp
```
