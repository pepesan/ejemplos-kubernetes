#!/bin/bash
HELM_DEPLOYMENT=nginx-helm
helm rollback $HELM_DEPLOYMENT 1

