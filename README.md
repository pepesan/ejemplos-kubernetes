# Ejemplos de Kubernetes

## Instalación de minukube y kubectl
```bash
./00_install_minikube_kubectl_helm.sh
```
## Lanzamiento del minukube
```bash
./01_minikube_start.sh
```
## Parada del minukube
```bash
./02_minikube_stop.sh
```
## Borrado del minukube
```bash
./03_minikube_delete.sh
```
## Arreglo del fallo de dns

Entrar al minikube por ssh

```bash
minikube ssh
```
Verificar que no resuelve el dns
```bash
nslookup google.com
```
Modificar el /etc/resolve.conf
```bash
sudo sh -c 'printf "nameserver 8.8.8.8\nnameserver 1.1.1.1\n" > /etc/resolv.conf'
```
Comprobar que ya resuelve correctamente
```bash
nslookup google.com
```

