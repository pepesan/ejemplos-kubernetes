#!/bin/bash

export VAULT_ADDR="http://localhost:8200"
export VAULT_TOKEN="vault-plaintext-root-token"

# comprobación del acceso
vault status

# creación de un engine con un path asociado y un par de clave/valor
# kv (tipo de engine)
# put (meter un valor)
# -mount nombre del engine
# nombre del path asociado (donde metes los clave/valor)
# clave=valor
vault kv put -mount=my.secrets my-database username=test password=root

vault secrets list

vault kv list -mount=my.secrets

vault kv list -mount=my.secrets my-database
