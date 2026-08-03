variable "name" {
  description = "Nome do security group. Tambem prefixa o nome das regras criadas."
  type        = string
}

variable "description" {
  description = "Descricao do security group."
  type        = string
  default     = null
}

variable "vpc_id" {
  description = "Id VPC"
  type        = string
}

variable "ingress_rules" {
  description = <<-EOT
    Regras de entrada, indexadas por nome logico. A chave do mapa nomeia a regra
    e e a identidade dela no state — renomear a chave recria a regra.

    Cada regra aceita exatamente uma origem: cidr_ipv4, cidr_ipv6,
    prefix_list_id ou referenced_security_group_id.

    Exemplo:
      {
        https-ipv4 = { cidr_ipv4 = "0.0.0.0/0", from_port = 443, ip_protocol = "tcp" }
        app        = { referenced_security_group_id = module.alb_sg.id, from_port = 8080, ip_protocol = "tcp" }
      }
  EOT
  type = map(object({
    description                  = optional(string)
    ip_protocol                  = optional(string, "tcp")
    from_port                    = optional(number)
    to_port                      = optional(number)
    cidr_ipv4                    = optional(string)
    cidr_ipv6                    = optional(string)
    prefix_list_id               = optional(string)
    referenced_security_group_id = optional(string)
  }))
  default = {}

  validation {
    condition = alltrue([
      for r in var.ingress_rules : length(compact([
        r.cidr_ipv4, r.cidr_ipv6, r.prefix_list_id, r.referenced_security_group_id
      ])) == 1
    ])
    error_message = "Cada regra de ingress precisa de exatamente uma origem: cidr_ipv4, cidr_ipv6, prefix_list_id ou referenced_security_group_id."
  }

  validation {
    condition     = alltrue([for r in var.ingress_rules : r.ip_protocol == "-1" || r.from_port != null])
    error_message = "from_port e obrigatorio quando ip_protocol nao e \"-1\"."
  }
}

variable "egress_rules" {
  description = <<-EOT
    Regras de saida, indexadas por nome logico. Mesmo formato de ingress_rules.
    Sem nenhuma regra o security group nao permite trafego de saida — a regra
    default da AWS nao e criada por aws_security_group sozinho.

    Exemplo (libera tudo):
      { all = { cidr_ipv4 = "0.0.0.0/0", ip_protocol = "-1" } }
  EOT
  type = map(object({
    description                  = optional(string)
    ip_protocol                  = optional(string, "tcp")
    from_port                    = optional(number)
    to_port                      = optional(number)
    cidr_ipv4                    = optional(string)
    cidr_ipv6                    = optional(string)
    prefix_list_id               = optional(string)
    referenced_security_group_id = optional(string)
  }))
  default = {}

  validation {
    condition = alltrue([
      for r in var.egress_rules : length(compact([
        r.cidr_ipv4, r.cidr_ipv6, r.prefix_list_id, r.referenced_security_group_id
      ])) == 1
    ])
    error_message = "Cada regra de egress precisa de exatamente um destino: cidr_ipv4, cidr_ipv6, prefix_list_id ou referenced_security_group_id."
  }

  validation {
    condition     = alltrue([for r in var.egress_rules : r.ip_protocol == "-1" || r.from_port != null])
    error_message = "from_port e obrigatorio quando ip_protocol nao e \"-1\"."
  }
}

variable "tags" {
  description = "Tags adicionais aplicadas no security group e nas regras."
  type        = map(string)
  default     = {}
}
