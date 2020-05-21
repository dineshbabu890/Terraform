#!/usr/bin/groovy

@Library(['com.optum.jenkins.pipelines.templates.terraform@v0.3.1', 'com.optum.jenkins.pipeline.library@master']) _


properties([
    buildDiscarder(logRotator( numToKeepStr: '5')),
])
    
pipeline {
  agent none
  stages {
  
    stage('Nonprod deployments') {
      steps { 
          withCredentials([azureServicePrincipal(credentialsId: 'azure-nonprod-2',
            subscriptionIdVariable: 'TF_VAR_subscription_id',
            clientIdVariable: 'TF_VAR_azure_client_id', 
            clientSecretVariable: 'TF_VAR_azure_client_secret',
            tenantIdVariable: 'TF_VAR_tenant_id'),
          usernamePassword(credentialsId: 'ocdgdo', usernameVariable: 'TF_VAR_artifactory_user', passwordVariable: 'TF_VAR_artifactory_pw' ),
          azureServicePrincipal(credentialsId: 'azure-aks-server-nonprod',
            subscriptionIdVariable: 'notused1',
            clientIdVariable: 'notused2', 
            clientSecretVariable: 'TF_VAR_aks_server_secret',
            tenantIdVariable: 'notused3')]) {
              

           TerraformPipeline("docker-azure-slave")
    
        } // withCredentials
      } // steps
    } //stage dev
   
  
    stage ('Deploy Prod') {
      when {
       branch 'master'
      }
      steps {
      withCredentials([azureServicePrincipal(credentialsId: 'azure-prod',
            subscriptionIdVariable: 'TF_VAR_subscription_id',
            clientIdVariable: 'TF_VAR_azure_client_id', 
            clientSecretVariable: 'TF_VAR_azure_client_secret',
            tenantIdVariable: 'TF_VAR_tenant_id'),
          usernamePassword(credentialsId: 'ocdgdo', usernameVariable: 'TF_VAR_artifactory_user', passwordVariable: 'TF_VAR_artifactory_pw' ),
          azureServicePrincipal(credentialsId: 'azure-aks-server-prod',
            subscriptionIdVariable: 'notused1',
            clientIdVariable: 'notused2', 
            clientSecretVariable: 'TF_VAR_aks_server_secret',
           tenantIdVariable: 'notused3')]) {
              
         //withEnv(["TF_LOG=TRACE"]) {
           TerraformPipeline("docker-azure-slave")
         //}
        } //withcredentials
      } // steps
    } // stage prod

  } // stages
} // pipeline
        
    

