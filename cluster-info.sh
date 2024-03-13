#!/bin/bash

NC='\033[0m'
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'


k8s_object (){
  # ingress
  if [[ ${2} == "ingress" ]]; then 
    echo "Get info ingress:"
    kubectl -n ${1} get ${2} -oyaml > ingress.yaml
    echo "kubectl -n ${1} get ${2} -oyaml"

    #object
    echo "# infor ${2} of namespace save in host.yaml"
    length=$(yq e '.items | length' ingress.yaml)
    if [[ -e host.yaml ]]; then 
        rm host.yaml
    fi
    for ((index=0;index<$length;index++)); 
    do
        yq e .items[$index].spec.rules[].host ingress.yaml >> host.yaml
        yq e .items[$index].spec.rules[].http.paths[] ingress.yaml  >> host.yaml
        echo --- >> host.yaml
    done
  fi

  #pvc
  if [[ ${2} == "pvc" ]]; then 
    echo "Get info pvc:"
    kubectl -n ${1} get ${2} -oyaml > raw-pvc.yaml
    echo "kubectl -n ${1} get ${2} -oyaml"

    #object
    echo "# infor ${2} of namespace save in pvc.yaml"
    length=$(yq e '.items | length' raw-pvc.yaml)
    if [[ -e pvc.yaml ]]; then 
        rm pvc.yaml
    fi
    for ((index=0;index<$length;index++)); 
    do
        yq e .items[$index]  raw-pvc.yaml >> pvc.yaml
        echo --- >> pvc.yaml
    done
  fi

  #configmap
  if [[ ${2} == "configmap" ]]; then 
    echo "Get all configmap of namespace save in all-cm.yaml"
    kubectl -n ${1} get ${2} | grep -v .crt | awk 'NR>1 {print $1}' > configmap.tmp
    if [[ -e all-cm.yaml ]]; then
        rm all-cm.yaml
    fi
    while IFS= read -r line; do
        kubectl -n $1 get configmap ${line} -oyaml>> all-cm.yaml
    done < configmap.tmp
  fi

  #secret
  if [[ ${2} == "secret" ]]; then 
    echo "Get all secret of namespace save in all-secret.yaml"
    kubectl -n ${1} get ${2} | grep -i opaque | awk '{print $1}' > configmap.tmp
    if [[ -e all-secret.yaml ]]; then
        rm all-secret.yaml
    fi
    while IFS= read -r line; do
        kubectl -n $1 get secret ${line} -oyaml>> all-secret.yaml
    done < configmap.tmp
  fi
}

# //path domain jq -r '.items[].spec.rules[].http.paths[]'
# //domain  jq -r '.items[].spec.rules[].host'

k8s_coredns () {
    echo "Get info coredns save in coredns-deploy.yaml"
    kubectl -n kube-system get deployments.apps coredns -oyaml > raw-coredns-deploy.yaml
    yq eval 'del(.status)' raw-coredns-deploy.yaml > coredns-deploy.yaml
    # rm raw-coredns-deploy.yaml
    coredns_image=$(yq e .spec.template.spec.containers[].image coredns-deploy.yaml)
    echo "coredns_image: " $coredns_image
    echo '#annotations' 
    echo  $(yq e .metadata.annotations raw-coredns-deploy.yaml)
    echo '#labels'
    echo  $(yq e .metadata.labels raw-coredns-deploy.yaml) 
}

ocp_coredns () {
    echo "Get info coredns save in coredns-daemonset.yaml"
    oc -n openshift-dns get daemonsets.apps dns-default -oyaml > raw-coredns-daemonset.yaml
    
}


ocp_configmap(){
    echo "Get all configmap of namespace save in all-cm.yaml"
    oc -n ${1} get ${2} | grep -v .crt | awk 'NR>1 {print $1}' > ocp_cm.tmp
}

k8s_cluster_info(){
    echo "Get info k8s cluster. kubectl get node -owide"
    kubectl get no -owide > cluster-info.txt
    echo VERSION = $(cat cluster-info.txt | awk 'NR>1 {print $5}'| sort |uniq)
    echo OS-IMAGE = $(cat cluster-info.txt | awk 'NR>1 {print $8, $9, $10}' | sort |uniq)
    echo KERNEL-VERSION = $(cat cluster-info.txt | awk 'NR>1 {print $11}'| sort |uniq)
    echo CONTAINER-RUNTIME = $(cat cluster-info.txt | awk 'NR>1 {print $12}'| sort |uniq )
}


ocp_cluster_info(){
    echo "Get info k8s cluster. kubectl get node -owide"
    oc get no -owide > ocp-cluster-info.txt
    echo VERSION = $(cat cluster-info.txt | awk 'NR>1 {print $5}'| sort |uniq)
    # echo OS-IMAGE = $(cat cluster-info.txt | awk 'NR>1 {print $8, $9, $10}' | sort |uniq)
    echo KERNEL-VERSION = $(cat cluster-info.txt | awk 'NR>1 {print $15}'| sort |uniq)
    echo CONTAINER-RUNTIME = $(cat cluster-info.txt | awk 'NR>1 {print $16}'| sort |uniq )
}

k8s_cni_cluster() {
    # get cni of cluster
    echo "Get config cni save in cni_daemonset.yaml"
    cni=$(kubectl -n kube-system get daemonsets.apps | awk 'NR>1 {print $1}' | egrep -Ei 'calico|cilium')
    echo 'Get cni of cluster: ' $cni
    kubectl -n kube-system get daemonsets.apps $cni -oyaml > raw_daemonset_cni.yaml
    yq eval 'del(.status)' raw_daemonset_cni.yaml > cni_daemonset.yaml
    cni_version=$(yq e .spec.template.spec.containers[].image cni_daemonset.yaml)
    echo "cni_version: " $cni_version
}


help () {
    echo -e "${GREEN}A supporting tool for get component of k8s cluster"
    echo
    echo -e "${GREEN}Syntax: ${0} [ -n | -o | -cluster_info |-coredns | -cni_cluster"
    echo -e "Options:"
    echo -e "    -cluster_info                Get information of k8s cluster"
    echo -e "    -cni_cluster                 Get information of cni k8s cluster"
    echo -e "    -coredns                     Get information of coredns k8s cluster"
    echo -e "    -n                           Namespaces in k8s cluster"
    echo -e "    -o                           Objects per Namespace in k8s cluster (ingress, pvc, configmap)"
    echo -e "--------------------------------------------------------------------------------"
    echo -e "Examples:"
    echo -e "+ cluster_info.sh -n default -o ingress"
    echo -e "+ cluster_info.sh -coredns"
    echo -e "Author: marco${NC}"
}

if [[ ${1} == '' ]] || [[ ${1} == '-help' ]]; then
    help
fi

if [[ ${1} == '-n' ]]; then
    k8s_object $2 $4
fi

if [[ ${1} == '-o' ]]; then
    k8s_object $4 $2
fi

if [[ ${1} == '-cluster_info' ]]; then
    k8s_cluster_info
fi

if [[ ${1} == '-coredns' ]]; then
    k8s_coredns
fi

if [[ ${1} == '-cni_cluster' ]]; then
    k8s_cni_cluster
fi