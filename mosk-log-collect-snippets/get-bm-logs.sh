#!/bin/bash
# Dont use bash/sh specific stuff since it might be needed on Windows

NAMESPACE=$1

## Logs:

kubectl logs -n kaas --all-containers --timestamps deployment/baremetal-provider > baremetal-provider.log
kubectl logs -n kaas --all-containers --timestamps deployment/baremetal-operator > baremetal-operator.log
kubectl logs -n kaas --all-containers --timestamps deployment/kaas-ipam > kaas-ipam.log
kubectl logs -n kaas --all-containers --timestamps deployment/ironic> ironic.log
kubectl logs -n kaas --all-containers --timestamps deployment/dnsmasq> dnsmasq.log


## Objects:

kubectl get -n $NAMESPACE -o json machine > machine.all.json
kubectl get -n $NAMESPACE -o json BareMetalHostCredential > BareMetalHostCredential.all.json
kubectl get -n $NAMESPACE -o json BareMetalHost > BareMetalHost.all.json
kubectl get -n $NAMESPACE -o json BareMetalHostProfile > BareMetalHostProfile.all.json
kubectl get -n $NAMESPACE -o json L2Template > L2Template.all.json
kubectl get -n $NAMESPACE -o json LCMMachine > LCMMachine.all.json
kubectl get -n $NAMESPACE -o json IPAMHost > IPAMHost.all.json


kubectl get -n $NAMESPACE -o wide machine > machine.all.wide.txt
kubectl get -n $NAMESPACE -o wide BareMetalHostCredential > BareMetalHostCredential.all.wide.txt
kubectl get -n $NAMESPACE -o wide BareMetalHost > BareMetalHost.all.wide.txt
kubectl get -n $NAMESPACE -o wide BareMetalHostProfile > BareMetalHostProfile.all.wide.txt
kubectl get -n $NAMESPACE -o wide L2Template > L2Template.all.wide.txt
kubectl get -n $NAMESPACE -o wide LCMMachine > LCMMachine.all.wide.txt
kubectl get -n $NAMESPACE -o wide IPAMHost > IPAMHost.all.wide.txt
