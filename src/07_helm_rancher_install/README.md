# Helm para K8s

## Instalación de Helm
Para instalar Helm 3 lo podemos hacer mediante binarios y sistenmas de paquetes
### Debian/Ubuntu
```shell
curl https://baltocdn.com/helm/signing.asc | gpg --dearmor | sudo tee /usr/share/keyrings/helm.gpg > /dev/null
sudo apt-get install apt-transport-https --yes
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/helm.gpg] https://baltocdn.com/helm/stable/debian/ all main" | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list
sudo apt-get update
sudo apt-get install helm
```
## Instalación de Rancher
Revisar la tabla de compatibilidades: https://www.suse.com/suse-rancher/support-matrix/all-supported-versions/rancher-v2-8-4/
Por ejemplo la versión 2.8.4 es compatible desde la versión 1.25 a la 1.28 de K8s

