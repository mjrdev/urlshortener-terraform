# modules/<nome>

<Um paragrafo: o que o modulo cria e para que serve neste stack.>

<Um ou dois paragrafos com o que nao e obvio: comportamento condicional de algum input,
limite da AWS que restringe `name`, o que recria recurso, escolha de custo. Corte se o
modulo for realmente simples — o README do `modules/ecr` tem tres paragrafos, e isso e
o suficiente.>

```hcl
module "<nome_no_root>" {
  source = "./modules/<nome>"

  name = "urlshortener-<nome>"
  # ... os inputs que realmente se usa aqui, nao todos os disponiveis
}
```

<!-- BEGIN_TF_DOCS -->
<!-- END_TF_DOCS -->
