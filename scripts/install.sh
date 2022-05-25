#!/usr/bin/env bash

# Applys all files within the directory to kubernetes
# $1 - The directory to apply
# $2 - The namespace
k8s_apply_folder () {
  if [ "$#" == "2" ]; then
    kubectl apply -f $1/. --namespace $2
  elif [ "$#" == "1"]; then
    kubectl apply -f $1/.
  fi
}

SCRIPTS_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
ROOT_DIR="$(dirname $SCRIPTS_DIR)"
DB_DIR="$ROOT_DIR/database"
GLOBAL_DIR="$ROOT_DIR/global"
NETWORKING_DIR="$ROOT_DIR/networking"

PROD_NAMESPACE="sro"
QA_NAMESPACE="sro-qa"
DEV_NAMESPACE="sro-dev"

echo "Applying global configuration"
kubectl apply -f $GLOBAL_DIR/.

echo "Configuring databases"
k8s_apply_folder "$DB_DIR/postgresql" "$PROD_NAMESPACE"
k8s_apply_folder "$DB_DIR/postgresql" "$QA_NAMESPACE"
k8s_apply_folder "$DB_DIR/postgresql" "$DEV_NAMESPACE"