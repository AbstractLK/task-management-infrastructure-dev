module "vpc" {
  source       = "./modules/vpc"
  vpc_cidr     = "10.0.0.0/16"
  cluster_name = var.cluster_name
}

module "eks" {
  source             = "./modules/eks"
  cluster_name       = var.cluster_name
  private_subnet_ids = module.vpc.private_subnet_ids
  all_subnet_ids     = concat(module.vpc.public_subnet_ids, module.vpc.private_subnet_ids)
}