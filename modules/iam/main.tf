##########################
# Trust policy
##########################

data "aws_iam_policy_document" "assume_role" {
  dynamic "statement" {
    for_each = var.trust_statements

    content {
      effect  = statement.value.effect
      actions = statement.value.actions

      dynamic "principals" {
        for_each = statement.value.principals

        content {
          type        = principals.value.type
          identifiers = principals.value.identifiers
        }
      }

      dynamic "condition" {
        for_each = statement.value.conditions

        content {
          test     = condition.value.test
          variable = condition.value.variable
          values   = condition.value.values
        }
      }
    }
  }
}

##########################
# Role
##########################


resource "aws_iam_role" "this" {
  count = var.prevent_destroy ? 0 : 1

  name                 = var.name
  description          = var.description
  path                 = var.path
  max_session_duration = var.max_session_duration
  assume_role_policy   = data.aws_iam_policy_document.assume_role.json

  tags = merge({ Name = var.name }, var.tags)
}

resource "aws_iam_role" "protected" {
  count = var.prevent_destroy ? 1 : 0

  name                 = var.name
  description          = var.description
  path                 = var.path
  max_session_duration = var.max_session_duration
  assume_role_policy   = data.aws_iam_policy_document.assume_role.json

  tags = merge({ Name = var.name }, var.tags)

  lifecycle {
    prevent_destroy = true
  }
}

locals {
  role_name      = one(concat(aws_iam_role.this[*].name, aws_iam_role.protected[*].name))
  role_arn       = one(concat(aws_iam_role.this[*].arn, aws_iam_role.protected[*].arn))
  role_unique_id = one(concat(aws_iam_role.this[*].unique_id, aws_iam_role.protected[*].unique_id))
}

##########################
# Politicas
##########################

data "aws_iam_policy_document" "this" {
  for_each = var.policies

  statement {
    effect    = each.value.effect
    actions   = each.value.actions
    resources = each.value.resources
  }
}

resource "aws_iam_policy" "this" {
  for_each = var.policies

  name   = "${var.name}-${each.key}"
  path   = var.path
  policy = data.aws_iam_policy_document.this[each.key].json

  tags = merge({ Name = "${var.name}-${each.key}" }, var.tags)
}

resource "aws_iam_role_policy_attachment" "this" {
  for_each = aws_iam_policy.this

  role       = local.role_name
  policy_arn = each.value.arn
}

resource "aws_iam_role_policy_attachment" "managed" {
  for_each = toset(var.managed_policy_arns)

  role       = local.role_name
  policy_arn = each.value
}
