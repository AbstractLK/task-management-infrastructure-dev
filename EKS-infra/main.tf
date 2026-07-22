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


# ==========================================
# SECRETS MANAGEMENT (SSM, IRSA, & ESO)
# ==========================================

# 1. Store the Secrets in AWS SSM Parameter Store
resource "aws_ssm_parameter" "mongodb_uri" {
  name  = "/task-management/MONGODB_URI"
  type  = "SecureString"
  value = var.mongodb_uri
}

resource "aws_ssm_parameter" "jwt_secret" {
  name  = "/task-management/JWT_SECRET"
  type  = "SecureString"
  value = var.jwt_secret
}

# 2. Create the IAM Role for the Kubernetes ServiceAccount (IRSA)
data "aws_iam_policy_document" "eso_assume_role" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"
    principals {
      type        = "Federated"
      identifiers = [module.eks.oidc_provider_arn]
    }
    condition {
      test     = "StringEquals"
      variable = "${replace(module.eks.oidc_provider_url, "https://", "")}:sub"
      # This matches the ServiceAccount we will add to your Helm chart
      values   = ["system:serviceaccount:default:eso-service-account"]
    }
  }
}

resource "aws_iam_role" "eso_role" {
  name               = "eso-service-account-role"
  assume_role_policy = data.aws_iam_policy_document.eso_assume_role.json
}

# Attach SSM Read-Only permissions to the role
resource "aws_iam_role_policy_attachment" "eso_ssm_policy" {
  role       = aws_iam_role.eso_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMReadOnlyAccess"
}