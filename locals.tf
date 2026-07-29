data "aws_caller_identity" "current" {}

locals {
  common_tags = {
    Name = "url-shortener"
  }

  # Um trust statement por repositorio autorizado. Indexado por apelido
  # para nao duplicar o bloco a cada repo novo.
  github_repos = {
    app = {
      repository = var.github_repository
      subjects   = var.github_subjects
    }
    terraform = {
      repository = var.github_repository_terraform
      subjects   = var.github_subjects_terraform
    }
  }

  github_actions_trust = {
    for key, repo in local.github_repos : key => [{
      actions    = ["sts:AssumeRoleWithWebIdentity"]
      principals = [{ type = "Federated", identifiers = [module.github_oidc.arn] }]

      # O `sub` ja carrega owner@ownerid/repo@repoid, entao os IDs numericos
      # protegem contra rename sem precisar de condicoes separadas.
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
      ]
    }]
  }
}
