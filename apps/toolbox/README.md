# Toolbox para Kubernetes

## Objetivo

Criar uma imagem separada para debug e manutencao no cluster.

Essa imagem nao e para rodar aplicacao.
Ela e para:

- entrar com shell confortavel
- inspecionar rede
- editar arquivos
- testar DNS
- validar conectividade
- usar PVCs temporariamente

## Por Que Separar da Imagem da Aplicacao

A imagem da aplicacao deve ficar minima e previsivel.

A toolbox existe para:

- nao poluir a imagem da aplicacao
- ter ferramentas de terminal no cluster
- facilitar manutencao e troubleshooting

## Ferramentas Planejadas

- `bash`
- `zsh`
- `oh-my-zsh`
- tema `agnoster`
- `vim`
- `nano`
- `curl`
- `wget`
- `jq`
- `less`
- `git`
- `tree`
- `file`
- `procps`
- `htop`
- `lsof`
- `iproute2`
- `iptables`
- `iputils-ping`
- `dnsutils`
- `netcat-openbsd`
- `nmap`
- `traceroute`
- `mtr-tiny`
- `openssl`
- `telnet`
- `tcpdump`
- `tmux`
- `rsync`
- `zip`
- `unzip`

## Base

Vamos usar:

```dockerfile
FROM debian:bookworm-slim
```

## Shell Padrao

A toolbox agora sobe com:

- `zsh`
- `oh-my-zsh`
- tema `agnoster`

Observacao:

- o tema `agnoster` fica melhor com fonte Powerline ou Nerd Font no terminal cliente
- sem isso, alguns simbolos podem aparecer quebrados

## Build Local

```bash
cd /home/coder/talos/toolbox
./build-local.sh
```

Isso gera:

```text
toolbox-k8s:dev
```

## Build Multi-arquitetura

```bash
cd /home/coder/talos/toolbox
IMAGE_REPO=192.168.1.54:3000/henrique/toolbox \
IMAGE_TAG=0.1.0 \
./build-multiarch.sh
```

## Uso Rapido no Cluster

Shell temporario:

```bash
kubectl -n default run toolbox --rm -it \
  --image=192.168.1.54:3000/henrique/toolbox:0.1.0 \
  -- bash
```

## Observacao sobre atualizacao da imagem

Ao usar a toolbox em nodes diferentes, apareceu um ponto importante:

- confiar apenas em `:latest` pode ser confuso
- o node pode reutilizar a imagem que ja estava em cache
- isso atrapalha principalmente quando a imagem foi rebuildada para corrigir suporte multi-arquitetura

Sinal tipico:

- `kubectl describe pod ...` mostra:
  - `image already present on machine`

Recomendacoes:

1. definir `imagePullPolicy: Always` nos pods de maintenance
2. preferir tags novas em cada rebuild importante, por exemplo:
   - `0.1.1`
   - `0.1.2`
   - `pgtools-1`

Exemplo:

```yaml
image: 192.168.1.152:30090/henrique/toolbox:0.1.1
imagePullPolicy: Always
```

Isso evita ficar preso em imagem antiga cacheada no node.

## Proximo Passo

Criar a imagem e depois publicar no Forgejo.
