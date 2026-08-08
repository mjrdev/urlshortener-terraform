# ADR 0012 — README de modulo gerado por terraform-docs

- **Status:** aceito
- **Data:** 2026-08-08

## Contexto

Cada modulo em `modules/` tem dezenas de inputs, boa parte com `optional()` e
default. Tabela de inputs/outputs escrita a mao desatualiza no primeiro PR que
acrescenta uma variavel, e a documentacao errada e pior que a ausente — manda a
pessoa passar um input que nao existe mais.

## Decisao

A referencia de inputs, outputs, recursos e providers de cada modulo e **gerada**
por terraform-docs, configurada em `.terraform-docs.yml`, e injetada no `README.md`
entre os marcadores `BEGIN_TF_DOCS` / `END_TF_DOCS`. O texto escrito a mao fora dos
marcadores — o que o modulo faz, exemplos de uso, pegadinhas — e preservado a cada
regeneracao.

Depois de mexer em variaveis ou outputs de qualquer modulo:

```bash
terraform-docs markdown table --recursive --recursive-path modules --config .terraform-docs.yml .
```

A descricao de cada variavel no `variables.tf` e, portanto, a fonte do que sai na
tabela — e onde o esforco de escrita deve ir.

## Alternativas consideradas

- **Tabelas escritas a mao** — desatualizam sem que nada quebre.
- **So os `variables.tf` como documentacao** — funciona para quem le o codigo, mas
  nao da uma visao do modulo em uma pagina, com defaults e obrigatoriedade.
- **Hook de pre-commit rodando o terraform-docs** — garantiria a atualizacao
  automatica; nao esta configurado hoje, e um candidato claro de melhoria.

## Consequencias

- A tabela nunca mente sobre quais inputs existem, desde que o comando seja rodado.
- **Nada forca a regeneracao**: nao ha check no CI nem pre-commit, entao um README
  desatualizado passa em PR sem alarme. A disciplina e manual.
- Editar a mao qualquer coisa dentro dos marcadores e trabalho perdido — a proxima
  execucao sobrescreve.
- Descricao de variavel deixa de ser detalhe: e o texto que a documentacao publica.
  Vale gastar tempo nela, inclusive com exemplos em heredoc, como em
  `modules/security-group/variables.tf`.
- Os textos ficam em portugues sem acentos, como o resto do repositorio.
