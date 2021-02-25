# AWS provider
provider "aws" {
//  region  = "eu-west-1"
  region     = "us-east-1"
//  shared_credentials_file = pathexpand(var.shared_credentials_file)
  token      = var.aws_session_token
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key
}

# Template provider
// this is needed to template the json for
// the ECR task definition
provider "template" {
}

# Random generator provider
// used jsut to generate a random password used in this demo
provider "random" {
}
