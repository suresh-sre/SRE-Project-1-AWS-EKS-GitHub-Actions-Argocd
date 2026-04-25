terraform {
  backend "s3" {
    bucket         = "terraform-state-cicd-pipeline-1"
    key            = "eks-cluster/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    use_lockfile   = true
  }
}
