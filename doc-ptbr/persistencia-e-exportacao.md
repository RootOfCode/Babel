# Persistência e Exportação

BABEL separa persistência de fonte, persistência de vocabulário, persistência de sessão e exportação de geometria.

## Diretório de Saída

A maioria dos helpers escreve no diretório de saída do BABEL.

```lisp
babel:*output-dir*
(babel:babel-out "arquivo.ext")
```

Esse diretório normalmente é criado durante `initialize`.

## Arquivos de Mundo

Um `.world` guarda rótulo e formas fonte de um mundo.

```lisp
(babel:save-world-file! (babel:babel-out "meu-mundo.world") "meu-mundo")
(babel:load-world-file! (babel:babel-out "meu-mundo.world"))
```

`babel-eval` atualiza `*current-world-source*`, que é usado por `save-world-file!`.

## Arquivos de Vocabulário

Um `.voc` guarda definições de macros registradas.

```lisp
(babel:save-vocabulary! (babel:babel-out "meu-vocab.voc"))
(babel:load-vocabulary! (babel:babel-out "meu-vocab.voc"))
```

Para mesclar vocabulário carregado com o registro atual:

```lisp
(babel:load-vocabulary! (babel:babel-out "extra.voc") :merge t)
```

## Sessão

```lisp
(babel:save-session! (babel:babel-out "sessao/"))
(babel:load-session! (babel:babel-out "sessao/"))
```

## Undo

```lisp
(babel:world-undo!)
```

A GUI também expõe undo pelo teclado.

## Exportação de Geometria

### OBJ

```lisp
(babel:export-obj!)
(babel:export-obj! (babel:babel-out "cena.obj"))
```

### SVG

```lisp
(babel:export-svg!)
(babel:export-svg! (babel:babel-out "cena.svg"))
```

### SVG em Quatro Vistas

```lisp
(babel:export-svg-quad!)
(babel:export-svg-quad! (babel:babel-out "cena-quad.svg"))
```

### EDN

```lisp
(babel:export-edn!)
(babel:export-edn! (babel:babel-out "cena.edn"))
```

### Exportar Tudo

```lisp
(babel:export-all!)
(babel:export-all! (babel:babel-out "export/"))
```

`export-all!` é o caminho mais simples para gerar OBJ, SVG, SVG quad e EDN da cena atual.

## Notas Práticas

* Salve `.world` quando quiser fonte capaz de reconstruir a cena.
* Salve `.voc` quando quiser vocabulário gerado/customizado reutilizável.
* Exporte OBJ/SVG/EDN quando quiser snapshots de geometria.
* Use `.world` e `.voc` juntos quando o mundo depender de vocabulário inventado.
