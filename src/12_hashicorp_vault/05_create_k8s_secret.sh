#!/bin/bash
export VAULT_TOKEN="vault-plaintext-root-token"
kubectl create secret generic vault-token --from-literal=token=$VAULT_TOKEN
