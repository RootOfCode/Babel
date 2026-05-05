# Como o BABEL Funciona

Este documento explica o BABEL como um pipeline de linguagem e renderização ao vivo, não apenas como uma lista de funções.

## Versão Curta

Uma sessão típica funciona assim:

1. SBCL carrega o sistema ASDF `:babel-world`.
2. `babel:initialize` prepara o diretório de saída e inicializa o vocabulário.
3. `babel:run-threaded` abre a janela SDL2/OpenGL sem bloquear o REPL.
4. Uma cena é selecionada, importada, editada ou avaliada pelo REPL.
5. A função da cena limpa os buffers e emite vértices e arestas.
6. O renderizador desenha a cena wireframe e os overlays da GUI/editor.
7. Comandos de salvar/exportar escrevem mundos, vocabulários, screenshots ou geometria.

## Modelo de Arquivos Fonte

```text
src/package.lisp      interface pública exportada
src/main.lisp         startup, initialize, run-threaded, babel-eval
src/worlds.lisp       cenas embutidas e macro world
src/geometry.lisp     emissores de vértices/arestas
src/layer0.lisp       primitivas públicas de geometria
src/registry.lisp     estrutura babel-macro e registro
src/inventor.lisp     bootstrap de vocabulário e invenção
src/evolution.lisp    mutação e crossover
src/scoring.lisp      pontuação de fitness das macros
src/renderer.lisp     renderizador SDL2/OpenGL
src/ui.lisp           overlay GUI e editor de código
src/persistence.lisp  .world, .voc, sessão, undo
src/export.lisp       exportadores OBJ, SVG, EDN
```

## Inicialização

`initialize` é a entrada normal depois de carregar o sistema.

```lisp
(babel:initialize)
```

Ela prepara o diretório de saída, registra as camadas de vocabulário, imprime o banner e pode validar cenas embutidas.

## Pipeline de Avaliação de Mundo

`babel-eval` é a interface principal de programação ao vivo.

```lisp
(babel:babel-eval
  (plane 0.0 0.0 180.0 180.0 0.0)
  (fortress 0.0 0.0 45.0))
```

Internamente ela:

1. guarda as formas fonte originais em `*current-world-source*`
2. reescreve nomes BABEL não qualificados para o pacote `:babel`
3. cria uma thunk que executa as formas
4. entrega a thunk para `run-world`
5. marca a geometria como suja para o renderizador reconstruir os arrays

## Macro `world`

Cenas embutidas normalmente usam `world`:

```lisp
(world (:seed 42)
  (plane 0.0 0.0 200.0 200.0 0.0)
  (fortress 0.0 0.0 40.0))
```

`world` fixa a seed aleatória, limpa a geometria e avalia o corpo. Isso facilita cenas procedurais reproduzíveis.

## Emissão de Geometria

Emissores de baixo nível criam vértices e arestas. As primitivas públicas chamam esses emissores.

Exemplos:

* `box` emite os oito vértices e doze arestas de uma caixa
* `sphere` chama `emit-sphere-edges`
* `arch` chama `emit-arch-edges`
* `terrain` chama `emit-terrain-edges`

O renderizador não precisa saber qual macro produziu cada aresta. Ele recebe buffers planos de vértices e arestas.

## Registro e Instalação de Macros

O registro mapeia nomes de macros para registros `babel-macro`. Um registro inclui corpo, parâmetros, dependências, camada, pontuação e documentação.

`register-macro!` registra metadados e define uma função Lisp chamável para uso imediato nos mundos.

## Invenção e Evolução

O inventor cria candidatos a partir de templates e vocabulário existente. Um candidato precisa evitar dependências circulares, terminar, emitir geometria, não duplicar um corpo existente e respeitar limite de arestas.

A evolução pode substituir chamadas, adicionar repetição, deslocar argumentos e fazer crossover entre corpos de macro. Variantes aceitas entram no registro como novo vocabulário.

## Pipeline do Editor

Quando o editor aplica código:

1. o buffer é lido como formas Lisp
2. formatos comuns de cena são normalizados
3. o corpo resultante é avaliado como mundo
4. se funcionar, a cena atual muda
5. se falhar, a cena anterior continua ativa e o erro aparece

## Pipeline de Exportação

Exportadores leem os buffers atuais de vértices/arestas e escrevem o formato solicitado. Use `export-all!` para gerar um pacote com OBJ, SVG, SVG em quatro vistas e EDN.
