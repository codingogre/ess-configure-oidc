# ess-configure-oidc
This project provides a script that automates configuring OIDC for the Elasticsearch Service (ESS).  OIDC requires Kibana URLs that are not available until after the cluster is created, therefore mechanisms like Terraform https://registry.terraform.io/providers/elastic/ec/latest/docs cannot be used to *fully* configure a cluster. This inconvenience is remedied by having Terraform call the ess-configure-oidc.sh script which will download the cluster topology by cluster ID, download the Kibana URL, and inject an OIDC configuration of your choice.  Terraform is recommended by the author, but there is no assumptions nor dependencies on the ES Terraform provider.

## Requirements for ess-configure-oidc.sh

### Software Requirements

* ecctl  
ecctl is a CLI utility that uses ESS REST APIs to automate tasks.  
Download ecctl here: https://www.elastic.co/downloads/ecctl  

* jq (https://stedolan.github.io/jq/)  
jq is like sed for JSON data.  

If you use OS X you can easily install these using brew   

### ESS Requirements
* API Key  
An API key is needed by ecctl so it can authenticate to ESS  
https://www.elastic.co/guide/en/cloud/current/ec-restful-api.html

Instructions for how to create an ESS API key is here:  
https://www.elastic.co/guide/en/cloud/current/ec-api-authentication.html
