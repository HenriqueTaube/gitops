docker pull factory.talos.dev/metal-installer/SEU_SCHEMATIC_ID:v1.12.6
docker tag factory.talos.dev/metal-installer/SEU_SCHEMATIC_ID:v1.12.6 \
 forgejo.seudominio/SEU_NAMESPACE/talos-installer:v1.12.6
docker push forgejo.seudominio/SEU_NAMESPACE/talos-installer:v1.12.6

