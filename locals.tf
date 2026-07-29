data "aws_caller_identity" "current" {}

locals {
  common_tags = {
    Name = "url-shortener"
  }

  github_actions_trust = [{
    actions    = ["sts:AssumeRoleWithWebIdentity"]
    principals = [{ type = "Federated", identifiers = [module.github_oidc.arn] }]

    conditions = [
      {
        test     = "StringEquals"
        variable = "${module.github_oidc.host}:aud"
        values   = ["sts.amazonaws.com"]
      },
      {
        test     = "StringLike"
        variable = "${module.github_oidc.host}:sub"
        values   = [for s in var.github_subjects : "repo:${var.github_repository}:${s}"]
      },
    ]
  }]
}
