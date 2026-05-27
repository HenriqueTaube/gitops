SO FALTA O WIREGUARD DEIXAR EM FAILLOVER E DEPOOIS COMEÇAR O GITOPS



# Talos Notes

## Licoes importantes do cluster

### Flannel e troca de CNI

Quando fomos trocar a CNI do cluster, apareceu um ponto importante:

- nao basta mudar a configuracao do Talos e reiniciar
- o `Flannel` antigo pode continuar rodando no cluster

Para preparar o cluster para outra CNI, foi necessario:

1. Ajustar os machine configs para:

```yaml
cluster:
  network:
    cni:
      name: none
```

2. Aplicar a configuracao nos nos Talos.
3. Reiniciar os nos.
4. Remover manualmente o `DaemonSet` antigo do Flannel:

```bash
kubectl --kubeconfig /home/coder/talos/kubeconfig delete daemonset kube-flannel -n kube-system
```

Observacao:

- apagar apenas o pod do Flannel nao resolve
- o `DaemonSet` recria o pod automaticamente
- em varios momentos o `Flannel` tambem atrapalhou o `local-path-provisioner`
- isso impactou `PVC`, helper pods e scheduling
- depois que o cluster ficou com `Cilium`, essa dor de cabeca deixou de incomodar

### Instalacao do Cilium no Talos

Instalar o Cilium com os valores padrao nao funcionou no Talos.

Erro que apareceu:

- `unable to apply caps: operation not permitted`

Foi necessario reinstalar com overrides especificos para Talos:

```bash
export KUBECONFIG=/home/coder/talos/kubeconfig

cilium install \
  --set ipam.mode=kubernetes \
  --set kubeProxyReplacement=false \
  --set securityContext.capabilities.ciliumAgent="{CHOWN,KILL,NET_ADMIN,NET_RAW,IPC_LOCK,SYS_ADMIN,SYS_RESOURCE,DAC_OVERRIDE,FOWNER,SETGID,SETUID}" \
  --set securityContext.capabilities.cleanCiliumState="{NET_ADMIN,SYS_ADMIN,SYS_RESOURCE}" \
  --set cgroup.autoMount.enabled=false \
  --set cgroup.hostRoot=/sys/fs/cgroup
```

Depois conferir:

```bash
cilium status
kubectl --kubeconfig /home/coder/talos/kubeconfig get pods -n kube-system -o wide
```

### Namespace e permissoes

Boa pratica para novos projetos no cluster:

1. Criar namespace dedicado.
2. Aplicar labels de Pod Security necessarias logo no inicio.

Exemplo:

```bash
kubectl --kubeconfig /home/coder/talos/kubeconfig create namespace NOME_DO_PROJETO

kubectl --kubeconfig /home/coder/talos/kubeconfig label namespace NOME_DO_PROJETO \
  pod-security.kubernetes.io/enforce=privileged \
  pod-security.kubernetes.io/audit=privileged \
  pod-security.kubernetes.io/warn=privileged --overwrite
```

Motivo:

- varios workloads podem falhar por Pod Security sem mensagem obvia no comeco
- storage helpers e workloads de rede tendem a sofrer com isso
- fazer isso cedo evita perder tempo depois

### Extensoes e ferramentas no Talos

Ponto importante para nao perder tempo:

- quando faltar alguma ferramenta de sistema no Talos, o caminho correto normalmente nao e "instalar no node"
- o caminho correto e gerar uma nova imagem do Talos com as `systemExtensions` necessarias
- depois fazer `talosctl upgrade` no node usando essa imagem

Exemplo real que apareceu com o Longhorn:

- foi necessario adicionar:
  - `siderolabs/iscsi-tools`
  - `siderolabs/util-linux-tools`
- isso nao entrou via `apply-config`
- isso entrou por `talos-schematic.yaml` + `Image Factory` + `talosctl upgrade`

Resumo pratico:

- configuracao do node: `worker-*.yaml`
- extensoes do sistema operacional: nova imagem do Talos

Regra mental boa:

- se o problema e configuracao, usar `apply-config`
- se o problema e ferramenta binaria/servico do host, pensar em `systemExtensions` e upgrade de imagem

###Conflito de IP no `worker-rasp`

Um problema real que apareceu no cluster foi conflito de IP na rede local:

- o `worker-rasp` estava com `192.168.1.153`
- esse IP entrou em conflito com um equipamento `TP-Link`
- depois disso apareceram sintomas estranhos de rede e DNS no cluster

Sintomas observados:

- `Longhorn` travando no `worker-rasp`
- `DuckDNS` sem funcionar
- falhas de resolucao DNS e acesso entre pods/servicos nesse node

Correcao aplicada:

- mudar o IP do `worker-rasp` de `192.168.1.153` para `192.168.1.154`
- reiniciar os workers

Licao pratica:

- antes de investigar storage ou aplicacao, validar se nao existe conflito de IP na LAN
- quando um node muda de IP, reiniciar pode ajudar a limpar estado residual de rede no Talos/Cilium

### Entrar no shell de um container

Para entrar no shell de um pod/deployment:

```bash
kubectl --kubeconfig /home/coder/talos/kubeconfig exec -it -n NAMESPACE deploy/NOME_DO_DEPLOYMENT -- sh
```

Exemplo:

```bash
kubectl --kubeconfig /home/coder/talos/kubeconfig exec -it -n wireguard deploy/wg-easy -- sh
```

### Executar comando direto no container

Tambem da para rodar um comando unico sem abrir shell:

```bash
kubectl --kubeconfig /home/coder/talos/kubeconfig exec -n NAMESPACE deploy/NOME_DO_DEPLOYMENT -- COMANDO
```

Exemplo:

```bash
kubectl --kubeconfig /home/coder/talos/kubeconfig exec -n wireguard deploy/wg-easy -- ls -la /etc/wireguard
```

### Service `LoadBalancer`

No Kubernetes, `LoadBalancer` serve para expor um `Service` para fora do cluster usando um IP proprio.

Resumo rapido:

- `ClusterIP`: acesso apenas dentro do cluster
- `NodePort`: abre uma porta em todos os nodes
- `LoadBalancer`: entrega um IP dedicado para acessar o service

No cluster caseiro com Talos, `LoadBalancer` precisa de algum mecanismo para anunciar esse IP na rede, por exemplo:

- `MetalLB`
- recursos de `LoadBalancer` do `Cilium`

Sem isso, o service pode ficar com `EXTERNAL-IP` pendente.

### Exemplo com o Grafana

Hoje o Grafana pode estar rodando no `worker-rasp` `192.168.1.154`, mas como o service esta em `NodePort`, ainda da para acessar pelo IP do `worker-prox` `192.168.1.152`.

Isso acontece porque o `NodePort` abre a porta em todos os nodes e o cluster encaminha o trafego para o pod correto.

Com `LoadBalancer`, a ideia muda:

- o Grafana ganha um IP proprio da LAN
- o acesso passa a ser sempre por esse IP fixo
- se o pod mudar de node, o IP de acesso continua o mesmo

Exemplo conceitual:

- `worker-prox`: `192.168.1.152`
- `worker-rasp`: `192.168.1.154`
- `grafana LoadBalancer`: `192.168.1.160`

Em vez de acessar por IP de node + porta alta, o acesso ficaria assim:

```text
http://192.168.1.160
```

Exemplo de service:

```yaml
spec:
  type: LoadBalancer
  loadBalancerIP: 192.168.1.160
  ports:
    - port: 80
      targetPort: 3000
```

Observacao importante:

- `LoadBalancer` deixa o acesso mais limpo e desacoplado do IP dos nodes
- isso ajuda em failover de acesso
- mas nao garante alta disponibilidade sozinho
- com apenas `1 replica` do Grafana, ainda existe indisponibilidade se o pod precisar subir em outro node
- para HA de verdade, pensar em `2 replicas`, storage confiavel e banco persistente adequado

Estado atual observado:

- o Grafana segue funcionando depois da migracao
- o workload foi testado nos dois workers
- o acesso por `NodePort` continua funcional enquanto `LoadBalancer` ainda nao foi configurado
- o proximo passo de rede e configurar `MetalLB` para expor services com IP proprio na LAN

### Toolbox para editar arquivos com nano

Quando a imagem do pod nao tem shell bom ou editor, usar o `ktoolbox` para abrir um pod auxiliar com a imagem de toolbox.

Formato:

```bash
ktoolbox NAMESPACE NOME_DO_POD PVC [MOUNT_PATH]
```

Exemplo com o Forgejo:

### Troubleshooting: `worker-rasp` preso no IP antigo do Cilium

Problema real que apareceu:

- o `worker-rasp` saiu da Ethernet onboard do Raspberry Pi e passou a usar adaptador USB
- nesse processo o node mudou de IP:
  - `192.168.1.156`
  - depois `192.168.1.90`
  - depois `192.168.1.91`
- depois disso o `Cilium` ficou preso no estado antigo do node

Sintomas observados:

- `kubectl get nodes -o wide` mostrava o node com `192.168.1.91`
- `kubectl get ciliumnodes` continuava mostrando `worker-rasp` com `192.168.1.156`
- pod do `Cilium` no rasp travava no init container `config`
- logs mostravam:

```text
ipAddr=https://10.96.0.1:443
connect: network is unreachable
```

Licao importante:

- apagar o `CiliumNode` antigo sozinho nao resolveu
- reiniciar pod do `Cilium` sozinho nao resolveu
- mudar `k8sServiceHost` via Helm values sozinho nao resolveu

O que resolveu:

1. Apagar o `CiliumNode` antigo:

```bash
kubectl delete ciliumnode worker-rasp
```

2. Forcar o `Cilium` a usar o IP real do control plane em vez de depender de `10.96.0.1:443` no bootstrap.

Foi necessario patchar o `DaemonSet` do `Cilium` e o `Deployment` do `cilium-operator` com:

- `KUBERNETES_SERVICE_HOST=192.168.1.113`
- `KUBERNETES_SERVICE_PORT=6443`

3. Reiniciar os pods de rede:

```bash
kubectl -n kube-system delete pod -l k8s-app=cilium
kubectl -n kube-system delete pod -l name=cilium-operator
kubectl -n kube-system delete pod -l k8s-app=cilium-envoy
```

Sinal de que o fix entrou:

- o init container `config` passou a completar com `Exit Code: 0`
- o pod novo do `Cilium` no `worker-rasp` saiu do estado travado

Resumo pratico:

- quando trocar NIC ou IP de node no Talos/Cilium, validar:

```bash
kubectl get nodes -o wide
kubectl get ciliumnodes
kubectl -n kube-system logs POD_DO_CILIUM -c config
```

- se `Node` e `CiliumNode` ficarem com IPs diferentes, ha estado residual
- se o `Cilium` insistir em `10.96.0.1:443` e travar no bootstrap, usar o IP real do control plane pode destravar

Conclusao final do incidente:

- o problema principal nao era a placa Ethernet onboard do Raspberry Pi 5
- o problema principal era falta de energia/corrente disponivel no USB do Pi 5
- quando o `worker-rasp` usou adaptador USB-Ethernet junto com SSD/perifericos USB, a rede ficou instavel
- isso gerou sintomas em cascata no Talos API, no `Cilium` e no estado do node

Correcao final aplicada:

- voltar temporariamente para a Ethernet onboard
- mover o SSD para um hub USB com alimentacao externa

Licao pratica:

- no Raspberry Pi 5, antes de culpar Talos, Cilium ou a NIC onboard, validar limite de energia USB
- adaptador USB-Ethernet + SSD USB + outros acessorios podem causar instabilidade se a alimentacao nao estiver folgada
- se possivel, usar hub alimentado externamente para SSD/perifericos mais pesados

#'nada resolveu no rasp' 
## Comportamento do DNS no Talos com `hostDNS` Continuação do trouble ###

  Atualmente os dois workers estão com isso habilitado no Talos:

  ```yaml
  machine:
    features:
      hostDNS:
        enabled: true
        forwardKubeDNSToHost: true

  ### O que isso significa

  Com hostDNS.enabled: true, o Talos sobe um resolvedor/cache DNS local no próprio node.

  Com forwardKubeDNSToHost: true, o CoreDNS do Kubernetes encaminha as consultas DNS para o DNS local do Talos, em vez
  de ir direto para os resolvers upstream.

  Nesse modo, o Talos usa o IP link-local:

  169.254.116.108

  Esse IP não é o DNS upstream real. Ele é apenas o endpoint local do DNS do Talos usado nesse caminho de
  encaminhamento.

  ### Distinção importante

  Aqui existem duas camadas diferentes:

  1. Endpoint local do DNS do Talos
     Exemplo:

     169.254.116.108

  2. DNS upstream real usado pelo Talos
     Exemplo:

     192.168.1.233:53

     ou

     1.1.1.1:53

  Então ver 169.254.116.108 não significa que o Pi-hole está sendo ignorado. Significa apenas que o encaminhamento via
  hostDNS do Talos está ativo.

  ### Comportamento observado atualmente

  #### worker-prox

  O worker-prox está com hostDNS habilitado e forwardKubeDNSToHost: true, e mesmo assim o DNS funciona normalmente.

  Exemplo de upstream observado:

  192.168.1.233:53

  Ou seja, nesse node o hostDNS do Talos está habilitado e funcionando normalmente.

  #### worker-rasp

  O worker-rasp também está com hostDNS habilitado e forwardKubeDNSToHost: true, mas o comportamento do DNS não está
  normal quando usa a configuração anterior com Pi-hole.

  Em momentos diferentes ele mostrou:

  - caminho local do Talos via 169.254.116.108
  - instabilidade no upstream DNS
  - teste/fallback com 1.1.1.1

  Então o problema não é simplesmente “apareceu um IP 169.254.x.x”. Essa parte é esperada quando forwardKubeDNSToHost
  está habilitado.

  O problema real é que o worker-rasp não se comporta igual ao worker-prox, mesmo os dois tendo a mesma configuração
  de hostDNS.

  ### Conclusão

  - 169.254.116.108 é esperado quando forwardKubeDNSToHost: true
  - o worker-prox funciona normalmente com essa feature ligada
  - o worker-rasp não está se comportando normalmente mesmo com a mesma feature ligada
  - isso indica que o problema não é a existência do hostDNS por si só
  - a diferença real provavelmente está no upstream DNS efetivo, em algo específico do node, ou em instabilidade entre
    o worker-rasp e o resolvedor configurado

  ### Comandos úteis

  Ver os resolvers efetivos:

  tn <ip-do-node> get resolvers
  tn <ip-do-node> get dnsupstream

  Ver os logs do DNS do Talos:

  tn <ip-do-node> logs dns-resolve-cache

  Ver o que um pod/container enxerga:

  cat /etc/resolv.conf
  nslookup google.com

  ### Observações para testes futuros

  Algumas variações possíveis para teste:

  1. Manter hostDNS.enabled: true e mudar para:

     forwardKubeDNSToHost: false
     Isso remove o caminho CoreDNS -> hostDNS do Talos, mas mantém o DNS local do host ativo no node.
     Isso remove o caminho CoreDNS -> hostDNS do Talos, mas mantém o DNS local do host ativo no node.

  2. Desabilitar completamente o host DNS:

     hostDNS:
       enabled: false

     Isso remove a camada de DNS local do Talos por completo.

  3. Forçar um resolvedor específico com:

     machine:
       network:
         nameservers:
           - 192.168.1.233

     ou:

     machine:
       network:
         nameservers:
           - 1.1.1.1



### Estado atual: MetalLB e Longhorn

Estado atual validado no cluster:

- `MetalLB` funcionando sem problemas relevantes
- `Longhorn` funcionando

Sobre o `MetalLB`:

- instalado em modo `Layer2`
- pool de IPs funcionando na LAN
- anuncios `Layer2` funcionando normalmente
- `Forgejo`, `Grafana` e `Loki` ja estao com IP fixo
- esses services ja estao funcionando sem `NodePort` por tras

Licao pratica:

- em services antigos que vieram de `NodePort`, apenas mudar para `LoadBalancer` nem sempre remove o `NodePort`
- para remover o `NodePort` antigo, em alguns casos foi necessario apagar e recriar o service
- usar:

```yaml
allocateLoadBalancerNodePorts: false
```

Sobre o `Longhorn`:

- esta operacional no cluster
- dependeu das extensoes corretas no Talos
- depois que o ambiente estabilizou, passou a funcionar normalmente

Proximo passo:

- configurar melhor a alta disponibilidade dos workloads
- preparar failover real para os pods por tras dos services expostos

Ideias praticas para a proxima etapa:

- aumentar replicas dos workloads criticos quando fizer sentido
- revisar `readinessProbe` e `livenessProbe`
- distribuir replicas entre nodes diferentes
- evitar depender de apenas um pod para services importantes
- validar comportamento de failover quando um worker sair do ar
- testar se os IPs do `MetalLB` continuam acessiveis quando o pod muda de node

```bash
ktoolbox forgejo forgejo-5d97dd6f9c-dn6b6 forgejo-data /data
```

Exemplo com o WireGuard:

```bash
ktoolbox wireguard NOME_DO_POD wireguard-data /etc/wireguard
```

Depois de entrar:

```bash
ls /data
nano /data/gitea/conf/app.ini
```

### Cleanup do CloudNativePG antigo

Depois da migracao do Grafana para o novo `CloudNativePG` em `Longhorn`, o laboratorio antigo pode ser removido.

Antes de apagar:

1. confirmar que o `grafana/deployment.yaml` ja aponta para o host novo
2. confirmar que o Grafana segue funcionando depois de reboot dos nodes
3. procurar referencias antigas no repositorio e no cluster

Checagens uteis:

```bash
rg -n "pg-lab-rw|cloudnativepg-lab|pg-lab" /home/coder/talos
kubectl get all -A | grep pg-lab
```

Se estiver tudo limpo, a ordem de remocao recomendada e:

```bash
kubectl delete -f /home/coder/talos/cloudnativepg/cluster.yaml
kubectl -n cloudnativepg-lab get pvc
kubectl delete -f /home/coder/talos/cloudnativepg/secret.yaml
kubectl delete -f /home/coder/talos/cloudnativepg/pv.yaml
kubectl delete -f /home/coder/talos/cloudnativepg/storageclass.yaml
kubectl delete -f /home/coder/talos/cloudnativepg/namespace.yaml
```

Observacao:

- se o PV antigo estiver com `Retain`, ele pode sobrar mesmo depois do cluster ser apagado
- isso e esperado
- nesse caso, limpar o PV/PVC residual depois da validacao final

Estado final observado:

- o laboratorio antigo `cloudnativepg-lab` foi removido
- o `Grafana` ficou funcional usando o banco novo em `Longhorn`
- os leftovers antigos de storage podem ser limpos depois da validacao final

### Estado atual do Forgejo

Migracao concluida:

- o `Forgejo` esta funcionando no cluster
- os dados do app foram copiados para um volume em `Longhorn`
- o `MariaDB` do Forgejo tambem foi migrado para `Longhorn`
- login, interface e operacao basica voltaram a funcionar

Validacao observada:

- o `Forgejo` funcionou com workload rodando em `worker-prox`
- o cluster tambem foi validado com `Grafana` funcionando nos dois workers
- isso da confianca de que `worker-prox` e `worker-rasp` estao aptos para os workloads principais

Pendencia de infraestrutura:

- configurar `MetalLB` para usar `LoadBalancer` na rede local
- depois disso, avaliar quais services vale a pena expor com IP proprio, por exemplo `Grafana` e `Forgejo`
