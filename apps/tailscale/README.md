# Tailscale Operator

1. Aplique o namespace:

```bash
kubectl apply -f tailscale/namespace.yaml
```

2. Copie o exemplo do secret e preencha `client_id` e `client_secret`:

```bash
cp tailscale/operator-oauth-secret.example.yaml tailscale/operator-oauth-secret.yaml
```

3. Aplique o secret:

```bash
kubectl apply -f tailscale/operator-oauth-secret.yaml
```

4. Adicione o chart repo e instale o operator:

```bash
helm repo add tailscale https://pkgs.tailscale.com/helmcharts
helm repo update
helm upgrade --install tailscale-operator tailscale/tailscale-operator \
  -n tailscale \
  --set-string oauth.clientId="SEU_CLIENT_ID" \
  --set-string oauth.clientSecret="SEU_CLIENT_SECRET" \
  --wait
```

5. Verifique:

```bash
kubectl get pods -n tailscale
kubectl get ingressclass
```
