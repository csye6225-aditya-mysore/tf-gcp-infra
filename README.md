# tf-gcp-infra
Repository for holding infrastructure as code.
1. Steps to provision infrastructure
 - Download the git repository (or clone it)
 - Create a tfvars file to hold the variable values for the ones that are mentioned in variables.tf
 - Install terraform 
 - Run "terraform init" in the root directory
 - Run "terraform validate" 
 - Run "terraform apply -var-file"path to your tfvars file""

2. Steps to destroy infrastructure
 - terraform destroy