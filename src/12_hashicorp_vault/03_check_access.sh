#!/bin/bash

export VAULT_ADDR="http://localhost:8200"
export VAULT_TOKEN="vault-plaintext-root-token"

vault status

## Salida
#Key             Value
#---             -----
#Seal Type       shamir
#Initialized     true
#Sealed          false
#Total Shares    1
#Threshold       1
#Version         1.13.3
#Build Date      2023-06-06T18:12:37Z
#Storage Type    inmem
#Cluster Name    vault-cluster-c0f7780f
#Cluster ID      5260a7a1-458b-149a-8acc-2790ac35df1b
#HA Enabled      false