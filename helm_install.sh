set -ex

export HELM_VERSION="2.14.1"
export KUBECTL_VERSION="1.14.2"

CLUSTER_NAME=$1
RESOURCE_GROUP=$2
TILLER_IMAGE=$3

. /etc/profile.d/jenkins.sh 

set -ex


az login --service-principal -u $TF_VAR_azure_client_id -p $TF_VAR_azure_client_secret --tenant $TF_VAR_tenant_id
az aks get-credentials -n $CLUSTER_NAME -g $RESOURCE_GROUP --admin
az aks list


kubectl apply -f ocdp-namespace.yaml
kubectl apply -f helm-rbac.yaml

helm init --service-account tiller --tiller-image $TILLER_IMAGE --upgrade






