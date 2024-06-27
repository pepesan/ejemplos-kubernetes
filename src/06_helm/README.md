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

## Crear un nuevo chart
```shell
cd charts
helm create nombre-chart
```
## Modificar el chart
```shell
cd nombre-chart
```
Aquí modificamos lo que necesitemos