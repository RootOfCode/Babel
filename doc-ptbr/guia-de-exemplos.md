# Guia de Exemplos

BABEL inclui cenas embutidas, arquivos `.world` salvos, um tour de REPL e um exemplo de importação.

## Tour Guiado no REPL

Use:

```lisp
(load "repl-tour.lisp")
```

O tour demonstra carregamento, inicialização, abertura da janela, avaliação de mundos, inspeção de macros e salvar/exportar.

## Exemplo de Importação

`examples/import-example.lisp` é um ponto de partida para o botão IMPORT da GUI. Copie ou edite esse arquivo e importe pelo editor de código estrutural.

## Cenas Embutidas

As cenas vivem em `src/worlds.lisp` e seus snippets de editor ficam em `src/scene-source.lisp`.

Navegue pela GUI ou pelo REPL:

```lisp
(babel:set-scene! 0)
(babel:next-scene!)
(babel:prev-scene!)
```

## Cena 0 — Layer-0 Sampler

Mostra primitivas como box, sphere, cone, torus, plane, arch e line.

## Cena 1 — Tower Row

Linha de torres com dome. Boa para entender formas compostas de Layer 1.

## Cena 2 — Fortress

Fortaleza Layer 3 com keeps, muralhas, arco de portão e construções menores.

## Cena 3 — Walled City

Cena Layer 4 maior com fronteira de fortaleza, keeps, colonnades e domes.

## Cena 4 — Towers of Babel

Composição radial abstrata de torres.

## Cena 5 — Orbital Ring Stations

Arranjo circular/radial de estruturas e linhas de conexão.

## Cena 6 — Cave / Strata Cross-Section

Composição vertical com superfície, estratos, formas subterrâneas e fortaleza.

## Cena 7 — Terrain Landscape

Combina terreno procedural com arquitetura.

## Cena 8 — Grand Cathedral

Exemplo arquitetônico grande com nave, transepto, apse, torres, arcos, buttresses, claustros e muralhas.

## Cena 9 — Amphitheatre

Exemplo radial de arquibancadas em camadas.

## Cena 10 — Procedural City Grid

Cena procedural em estilo grade urbana.

## Mundos Salvos

O diretório `worlds/` inclui arquivos `.world` como:

* `The_Basilica_Of_Broken_Skies.world`
* `The_Cathedral_of_Spires.world`
* `The_Great_Aqueduct.world`
* `The_Necropolis_of_Ahk-Meren.world`
* `The_Obsidian_Monastery.world`
* `backpack.world`

Carregue um pelo REPL:

```lisp
(babel:load-world-file! #P"worlds/The_Cathedral_of_Spires.world")
```

## Escrevendo Seu Próprio Exemplo

```lisp
(babel:babel-eval
  (world (:seed 123)
    (plane 0.0 0.0 240.0 240.0 0.0)
    (citadel 0.0 0.0 50.0 10.0)
    (loop for i from 0 below 8
          for a = (* 2.0 pi (/ i 8))
          do (keep (* 80.0 (cos a))
                   (* 80.0 (sin a))
                   2.0
                   5))))
```

O padrão normal é começar por chão/terreno, compor vocabulário e usar loops para repetição.
