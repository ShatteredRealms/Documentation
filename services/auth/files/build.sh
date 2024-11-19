#!/bin/bash

TAG="1.1.13"
REPO="779965382548.dkr.ecr.us-east-1.amazonaws.com/sro/keycloak"
IMAGE="$REPO:$TAG"

docker build --tag $IMAGE -f keycloak.Dockerfile .
docker push $IMAGE
