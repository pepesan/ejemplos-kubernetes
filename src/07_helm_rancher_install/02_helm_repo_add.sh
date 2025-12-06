#!/bin/bash
REPO_TYPE=latest
helm repo add rancher-$REPO_TYPE https://releases.rancher.com/server-charts/$REPO_TYPE

