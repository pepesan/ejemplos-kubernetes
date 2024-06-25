# Uso de Hashicorp Vault
## Despliegue con Docker Compose
```shell
docker compose up -d
```
## Comprobaciones con contenedor
### Entramos al contenedor
```shell
docker compose run vault-client /bin/bash
```
### Ejecutamos los comandos
```shell
# comprobamos el estado de la conexión
vault status
# creamos el vault secret
vault secrets enable -version=2 -path=my.secrets kv
# creamos una entrada con dos valores
vault kv put my.secrets/dev username=test_user password=test_password
# comprobamos que hemos introducido los valores
vault kv get -format=json my.secrets/dev | jq ".data.data"
```
