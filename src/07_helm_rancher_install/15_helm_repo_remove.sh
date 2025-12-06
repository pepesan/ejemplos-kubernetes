#!/bin/bash
REPO_TYPE=stable
# borrar repo rancher
helm repo remove rancher-$REPO_TYPE
# borrar repo jetstack
helm repo remove jetstack

