#/bin/bash

# Arguments
# 1 name of acr registry
# 2 acr login URL from terraform (optumcarecontainerregistry.azurecr.io) from ${azurerm_container_registry.acr.login_server}
# 3 source URL (docker.repo1.uhc.com)
# 4 source username
# 5 source password
# 6 target username / azure client id
# 7 target password / azure client secret
# 8 image details (kubernetes-helm/tiller:v2.14.3)


set  -ex # will cause script to fail if any one of the following commands fail

az login --service-principal -u $TF_VAR_azure_client_id -p $TF_VAR_azure_client_secret --tenant $TF_VAR_tenant_id

az acr login --name $1 ;
echo "Logged into ACR";

docker login $3 -u $4 -p $5 ;
echo "Logged into $3";

docker pull $3/$8;
echo "Pulled the image $3/$8";

docker login $2 -u $6 -p $7;
echo "Logged into $2";

docker tag $3/$8 $2/$8;
echo "Tagged $2/$8"

docker push $2/$8;
echo "Pushed $2/$8"