# Referência da DSL de Mundos

Esta é uma referência prática da interface pública de programação de mundos do BABEL.

## Como Ler a DSL

Dentro de `babel-eval` ou `world`, as formas são Common Lisp comum que normalmente chamam funções geométricas. Uma forma pode:

* emitir vértices e arestas
* rodar loops e condicionais
* chamar entradas do vocabulário registrado
* chamar helpers escritos manualmente
* guardar fonte para persistência `.world`

## Formas de Entrada

### `initialize`

```lisp
(babel:initialize)
```

Inicializa vocabulário, diretório de saída e validações opcionais.

### `run-threaded`

```lisp
(babel:run-threaded)
```

Abre a janela em uma thread de fundo. É o modo recomendado para REPL.

### `run`

```lisp
(babel:run)
```

Abre o renderizador na thread atual. Útil para scripts, mas bloqueia o REPL.

### `babel-eval`

```lisp
(babel:babel-eval
  (plane 0.0 0.0 200.0 200.0 0.0)
  (fortress 0.0 0.0 50.0))
```

Avalia um corpo de mundo e torna esse resultado a cena ativa.

### `show-macro`

```lisp
(babel:show-macro keep 0.0 0.0 2.5 6)
```

Mostra uma única chamada de macro como cena atual.

### `world`

```lisp
(world (:seed 42)
  (plane 0.0 0.0 120.0 120.0 0.0)
  (tower 0.0 0.0 8 3.0 0.1))
```

Limpa geometria, fixa a seed aleatória e executa o corpo.

## Primitivas de Layer 0

```lisp
(box x y z w h d)
(sphere x y z r steps)
(babel-line x0 y0 z0 x1 y1 z1)
(plane cx cz w d y)
(cone x y z r h steps)
(torus x y z r tube steps)
(arch x y z span rise width style)
(wall-segment x0 z0 x1 z1 y-base height thickness)
(half-dome x y z r steps)
(cylinder x y z r h steps)
(pyramid x y z base-w base-d height)
(vault x y z span length steps)
(staircase x y z width n-steps step-h step-d)
(spire x y z height base-r sides)
(flying-buttress wall-x wall-y wall-z pier-x pier-y pier-z thickness)
```

Essas funções são os blocos básicos do mundo wireframe.

## Terreno

```lisp
(terrain cx cz width depth resolution amplitude)
(plateau cx cz width depth y-base wall-height)
```

`terrain` gera terreno procedural. `plateau` cria uma plataforma elevada com paredes verticais.

## Vocabulário Manual

### Layer 1

```lisp
(tower x z floors radius taper)
(dome x y z radius steps)
(colonnade x z length n-pillars pillar-r pillar-h)
```

### Layer 2

```lisp
(battlement x y z wall-len wall-w wall-h crenels)
(keep x z base-r floors)
```

### Layer 3

```lisp
(fortress cx cz size)
```

### Layer 4

```lisp
(walled-city cx cz size density)
```

### Layer 5

```lisp
(citadel cx cz size platform-h)
(twin-cities cx cz city-size spacing)
(monastery cx cz size)
```

## Navegação de Cena

```lisp
(babel:set-scene! 2)
(babel:next-scene!)
(babel:prev-scene!)
```

## Inspeção

```lisp
(babel:list-macros-by-layer)
(babel:? 'babel:fortress)
(babel:print-macro-tree 'babel:fortress)
(babel:print-top-macros 10)
(babel:macro-geometry-stats 'babel:keep)
```

Use inspeção quando tiver dúvida sobre assinatura, dependências, pontuação ou geometria gerada.

## Registro de Macro Customizada

```lisp
(in-package :babel)

(let* ((body '(loop for i from 0 below count
                    for a = (* 2.0 pi (/ i count))
                    do (keep (* radius (cos a))
                             (* radius (sin a))
                             base-r floors)))
       (m (make-babel-macro
           :name 'ring-of-keeps
           :layer 3
           :params '(radius count base-r floors)
           :body body
           :dependencies '(keep)
           :complexity (tree-depth body)
           :score 0.85
           :usage-count 0
           :invented-at 0
           :doc "Arranjo circular de keeps.")))
  (register-macro! m))
```

Regras práticas:

* use camada maior que as macros chamadas
* liste todas as dependências BABEL
* mantenha o corpo como s-expression citada
* evite loops sem limite em vocabulário gerado
