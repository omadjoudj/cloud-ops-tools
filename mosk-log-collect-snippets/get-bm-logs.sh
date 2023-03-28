#!/bin/bash

NAMESPACE=$1

## Logs:

kubectl logs -n kaas --all-containers --timestamps deployment/baremetal-provider > baremetal-provider.log
kubectl logs -n kaas --all-containers --timestamps deployment/baremetal-operator > baremetal-operator.log
kubectl logs -n kaas --all-containers --timestamps deployment/kaas-ipam > kaas-ipam.log

## Objects:

kubectl get -n $NAMESPACE -o yaml BareMetalHostCredential > BareMetalHostCredential.all.yaml
kubectl get -n $NAMESPACE -o yaml BareMetalHost > BareMetalHost.all.yaml
kubectl get -n $NAMESPACE -o yaml BareMetalHostProfile > BareMetalHostProfile.all.yaml
kubectl get -n $NAMESPACE -o yaml L2Template > L2Template.all.yaml
kubectl get -n $NAMESPACE -o yaml LCMMachine > LCMMachine.all.yaml
kubectl get -n $NAMESPACE -o yaml IPAMHost > IPAMHost.all.yaml


kubectl get -n $NAMESPACE -o wide BareMetalHostCredential > BareMetalHostCredential.all.wide.txt
kubectl get -n $NAMESPACE -o wide BareMetalHost > BareMetalHost.all.wide.txt
kubectl get -n $NAMESPACE -o wide BareMetalHostProfile > BareMetalHostProfile.all.wide.txt
kubectl get -n $NAMESPACE -o wide L2Template > L2Template.all.wide.txt
kubectl get -n $NAMESPACE -o wide LCMMachine > LCMMachine.all.wide.txt
kubectl get -n $NAMESPACE -o wide IPAMHost > IPAMHost.all.wide.txt
