# Talos Codex Notes

## Estado atual

- Cluster Talos funcionando com:
  - `controlplane-proxmox`
  - `worker-codex`
- CNI atual:
  - `flannel`
- Container registry do Forgejo confirmado em:
  - `192.168.1.54:3000`
- Imagem do app publicada em:
  - `192.168.1.54:3000/henrique/codex-api:latest`
- App rodando no Kubernetes no namespace:
  - `codex`
- Exposicao atual:
  - `NodePort`
  - `http://192.168.1.85:30080`

## Projeto do app

- Pasta do projeto:
  - `/home/coder/talos/codex`
- Arquivos principais:
  - `/home/coder/talos/codex/app.py`
  - `/home/coder/talos/codex/requirements.txt`
  - `/home/coder/talos/codex/Dockerfile`
  - `/home/coder/talos/codex/.dockerignore`
  - `/home/coder/talos/codex/.gitignore`
  - `/home/coder/talos/codex/secret.yaml`
  - `/home/coder/talos/codex/pvc.yaml`
  - `/home/coder/talos/codex/deployment.yaml`
  - `/home/coder/talos/codex/service.yaml`

## App codex

- Framework:
  - `FastAPI`
- Endpoints atuais:
  - `GET /health`
  - `POST /chat`
- Persistencia:
  - historico salvo em `/data/history`
- Variaveis importantes:
  - `OPENAI_API_KEY`
  - `OPENAI_MODEL`
  - `DATA_DIR`

## Problema com a API OpenAI

- O app ficou funcional, mas a conta/projeto da API retornou:
  - `429 insufficient_quota`
- Isso significa:
  - o app esta chamando a API corretamente
  - a chave esta valida
  - mas o projeto/conta da API esta sem cota disponivel ou sem billing adequado
- Importante:
  - ChatGPT / Codex na interface e API da OpenAI sao cobrancas separadas

## Secret

- Nome do secret:
  - `codex-openai`
- O app espera a chave nesta env:
  - `OPENAI_API_KEY`
- Melhor pratica:
  - manter placeholder no YAML
  - aplicar a chave real localmente na hora do `kubectl apply`

## Storage

- Provisioner instalado:
  - `local-path`
- PVC usado pelo app:
  - `codex-data`
- StorageClass usada:
  - `local-path`

## Namespace

- Namespace dedicado criado:
  - `codex`
- Todos os manifests do app devem usar:
  - `namespace: codex`
- Tambem foi necessario liberar Pod Security em:
  - `codex`
  - `local-path-storage`

Comandos uteis:

```bash
kubectl --kubeconfig /home/coder/talos/kubeconfig label namespace codex \
  pod-security.kubernetes.io/enforce=privileged \
  pod-security.kubernetes.io/audit=privileged \
  pod-security.kubernetes.io/warn=privileged --overwrite

kubectl --kubeconfig /home/coder/talos/kubeconfig label namespace local-path-storage \
  pod-security.kubernetes.io/enforce=privileged \
  pod-security.kubernetes.io/audit=privileged \
  pod-security.kubernetes.io/warn=privileged --overwrite
```

## Registry do Forgejo

- Registry verificado com:
  - `/v2/`
- O Forgejo estava servindo registry em HTTP, nao HTTPS
- No host local foi necessario configurar Docker insecure registry
- No worker Talos foi necessario configurar mirror HTTP em:
  - `/home/coder/talos/worker.yaml`

Trecho importante:

```yaml
registries:
  mirrors:
    192.168.1.54:3000:
      endpoints:
        - http://192.168.1.54:3000
```

Depois aplicar no worker:

```bash
talosctl apply-config --nodes 192.168.1.85 --file /home/coder/talos/worker.yaml
talosctl reboot --nodes 192.168.1.85
```

## Build da imagem

- O worker `worker-codex` e `arm64`
- Build feito em host `amd64` gerou erro:
  - `exec format error`
- Solucao:
  - usar `buildx` para gerar imagem `linux/arm64`

Fluxo:

```bash
docker run --privileged --rm tonistiigi/binfmt --install all
docker buildx build --platform linux/arm64 \
  -t 192.168.1.54:3000/henrique/codex-api:latest \
  --push .
```

## Fluxo de update do app

Quando mudar o `app.py`:

1. Testar localmente.
2. Rebuildar a imagem.
3. Fazer push para o registry do Forgejo.
4. Reaplicar ou reiniciar o `Deployment`.

Exemplo:

```bash
docker buildx build --platform linux/arm64 \
  -t 192.168.1.54:3000/henrique/codex-api:latest \
  --push .

kubectl --kubeconfig /home/coder/talos/kubeconfig delete pod -n codex -l app=codex-api
```

## Troubleshooting que apareceu

- `adjusting time...`
  - problema inicial de boot/rede no Talos
- `x509: certificate signed by unknown authority`
  - acesso inicial ao Talos antes de usar `--insecure` ou `talosconfig`
- troca de hostname no Talos
  - Kubernetes manteve os nodes antigos e os novos
  - foi necessario apagar os objetos antigos do tipo `Node`
- instalar `cilium` por cima do `flannel`
  - causou conflito de CNI
  - foi necessario remover o Cilium, limpar taints e reiniciar os nos
- `cni0 already has an IP address different from ...`
  - resolvido com reboot dos nos
- PVC `Pending`
  - primeiro sem `storageClassName`
  - depois barrado por Pod Security do `local-path-storage`
- `ImagePullBackOff`
  - registry HTTP sendo acessado como HTTPS
- `exec format error`
  - imagem `amd64` tentando rodar no worker `arm64`

## Dica pratica

- Em varios momentos o reboot dos nos ajudou a limpar estado residual de rede e configuracao.
- Mesmo assim, primeiro sempre vale olhar:
  - `kubectl describe`
  - `kubectl logs`
  - `talosctl health`

## Git

- Recomendado versionar somente:
  - `/home/coder/talos/codex`
- Nao versionar a raiz inteira de `/home/coder/talos`, porque la existem arquivos sensiveis de cluster:
  - `/home/coder/talos/kubeconfig`
  - `/home/coder/talos/talosconfig`
  - `/home/coder/talos/controlplane.yaml`
  - `/home/coder/talos/worker.yaml`

## Proximas ideias

- testar migracao de `flannel` para `cilium` so para aprender
- subir outro app no cluster:
  - `Uptime Kuma`
  - `MinIO`
  - `Argo CD`
