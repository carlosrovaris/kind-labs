#!/bin/bash

create_kind_cluster(){
    kind get clusters | grep -q rovaris
    CheckCluster=$(echo $?)
    if [ $CheckCluster -eq 0 ]; then
        kind delete clusters rovaris
    fi

    kind create cluster --name rovaris --config config.yml
    ECKIND=$(echo $?)
    if [ $ECKIND -eq 1 ]; then
        echo "Falha ao subir o Kind!!!!!"
        exit 1
    fi
}

install_cni_wave(){
    echo -e '\033[36;1m \n\n###### Instalando o CNI - WAVE \033[m'
    kubectl apply -f "https://cloud.weave.works/k8s/net?k8s-version=$(kubectl version | base64 | tr -d '\n')"
    kubectl get nodes
}

install_metallb(){
    echo -e '\033[36;1m \n\n###### Instalando o METALLB \033[m'
    kubectl create ns metallb

    # Add or update bitnami repo
    helm repo list | grep -q bitnami
    RepoMetalLB=$(echo $?)
    if [ $RepoMetalLB -eq 1 ]; then
        helm repo add metallb https://metallb.github.io/metallb
    else
        helm repo update
    fi

    # Criando o stack do Metrics-Server
    helm install metallb metallb/metallb -n metallb -f metallb/values.yml
}

install_ingress_nginx(){
    echo -e '\033[36;1m \n\n###### Instalando o NGINX INGRESS \033[m'
    kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml

    kubectl wait --namespace ingress-nginx \
    --for=condition=ready pod \
    --selector=app.kubernetes.io/component=controller \
    --timeout=90s

    # kubectl create -f ingress-example.yml
}

install_metric_server(){
    echo -e '\033[36;1m \n\n###### Instalando o METRIC SERVER \033[m'

    # Add or update bitnami repo
    helm repo list | grep -q bitnami
    RepoBitnami=$(echo $?)
    if [ $RepoBitnami -eq 1 ]; then
        helm repo add bitnami https://charts.bitnami.com/bitnami  
    else
        helm repo update
    fi

    # Criando o stack do Metrics-Server
    helm install --namespace kube-system metrics-server bitnami/metrics-server --set apiService.create=true  --version 5.11.3 -f $(pwd)/metricsserver/values.yaml
}


install_dashboard(){
    #Instalação
    kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.3.1/aio/deploy/recommended.yaml
    kubectl create -f k8sdashboard/k8s-dashboard-adminuser.yml

    #Token para acessar o Dashboard:
    kubectl -n kubernetes-dashboard describe secret "$(kubectl -n kubernetes-dashboard get secret | grep admin-user | awk '{ print $1 }')"
    kubectl proxy &

    # Acessar a URL abaixo com o token fornecido pelos comandos acima:
    echo "http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/"
}

install_nfs(){
    echo -e '\033[36;1m \n\n###### Instalando o NFS Client \033[m'
    helm repo add nfs-subdir-external-provisioner https://kubernetes-sigs.github.io/nfs-subdir-external-provisioner/
    helm install nfs-subdir-external-provisioner nfs-subdir-external-provisioner/nfs-subdir-external-provisioner \
    --set nfs.server=192.168.0.40 \
    --set nfs.path=/share/kind
}

install_nginx_cm(){
    echo -e '\033[36;1m \n\n###### Nginx ConfigMap\033[m'
    kubectl create cm nginx-index-custom01 --from-file configmap/nginx1/index_custom_rovaris1.html
    kubectl create cm nginx-index-custom02 --from-file configmap/nginx2/index_custom_rovaris2.html
    kubectl create -f configmap/nginx1/
    kubectl create -f configmap/nginx2/
    kubectl create -f configmap/ingress-nginx-cm.yml
}


main(){
    create_kind_cluster
    install_cni_wave
    install_metallb
    install_metric_server
    # install_dashboard
    # install_ingress_nginx
    # install_nfs
    # install_nginx_cm
}
main
