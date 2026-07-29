data "aws_caller_identity" "current" {}

locals {
  common_tags = {
    Name = "url-shortener"
  }

  github_repos = {
    app = {
      repository    = var.github_repository
      repository_id = var.github_repository_id
      subjects      = var.github_subjects
    }
    terraform = {
      repository    = var.github_repository_terraform
      repository_id = var.github_repository_terraform_id
      subjects      = var.github_subjects_terraform
    }
  }

  github_actions_trust = {
    for key, repo in local.github_repos : key => [{
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
          values   = [for s in repo.subjects : "repo:${repo.repository}:${s}"]
        },

        {
          test     = "StringEquals"
          variable = "${module.github_oidc.host}:repository_id"
          values   = [repo.repository_id]
        },
        {
          test     = "StringEquals"
          variable = "${module.github_oidc.host}:repository_owner_id"
          values   = [var.github_repository_owner_id]
        },
      ]
    }]
  }
}
