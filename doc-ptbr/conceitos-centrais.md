# Conceitos Centrais

## Tipos de Arquivo

### `.lisp`

Arquivos normais de Common Lisp. BABEL é um sistema ASDF chamado `:babel-world` e um pacote chamado `:babel`.

Arquivos importantes:

* `src/main.lisp` — entrada, inicialização, `babel-eval`, helpers de REPL
* `src/worlds.lisp` — cenas demo e macro `world`
* `src/layer0.lisp` — primitivas de geometria
* `src/registry.lisp` — metadados e registro das macros BABEL
* `src/inventor.lisp` — camadas manuais e invenção de macros
* `src/ui.lisp` — overlay GUI e editor de código
* `src/renderer.lisp` — loop SDL2/OpenGL e desenho

### `.world`

Arquivo de mundo salvo. Guarda um rótulo e as formas Lisp necessárias para reconstruir um mundo.

### `.voc`

Vocabulário salvo. Preserva definições de macros BABEL registradas para reutilizar ou mesclar em outra sessão.

### Formatos de exportação

BABEL pode exportar a geometria atual como:

* `.obj` — intercâmbio 3D geral
* `.svg` — desenho wireframe projetado
* `.svg` em quatro vistas — quatro projeções em um arquivo
* `.edn` — representação de dados de vértices e arestas

## Modelo de Mundo

Um mundo BABEL é um programa Lisp que emite geometria wireframe.

Os buffers principais são:

* `*vertex-buffer*` — vértices acumulados
* `*edge-buffer*` — pares de índices de arestas

Um mundo normalmente não retorna um objeto de malha. Ele executa funções como `box`, `sphere`, `fortress` ou `terrain`; essas funções adicionam vértices e arestas aos buffers. O renderizador lê esses buffers e desenha a cena atual.

## Modelo de Vocabulário

BABEL trata funções geométricas reutilizáveis como entradas de vocabulário.

Uma entrada registrada guarda:

* nome
* camada
* lista de parâmetros
* corpo Lisp
* dependências
* pontuação
* complexidade
* contagem de uso
* string de documentação
* geração

As camadas importam. Uma macro de nível maior deve depender apenas de primitivas ou macros de camadas menores. Isso mantém o vocabulário gerado mais fácil de inspecionar.

## Modelo de Camadas

O vocabulário manual inicial é:

* Layer 0 — emissores wireframe como `box`, `sphere`, `plane`, `arch`, `wall-segment`, `spire`
* Layer 1 — formas compostas simples como `tower`, `dome`, `colonnade`, `terrain`, `plateau`
* Layer 2 — peças arquitetônicas como `battlement` e `keep`
* Layer 3 — estruturas completas como `fortress`
* Layer 4 — arranjos maiores como `walled-city`
* Layer 5 — composições de alto nível como `citadel`, `twin-cities` e `monastery`

O inventor pode propor novos corpos de macro usando o vocabulário existente.

## Tempo de Carga Versus Tempo de Mundo

O código do BABEL mistura dois modos:

### Tempo de carga/build

Acontece quando SBCL carrega o projeto ou quando você chama funções do sistema:

* carregamento ASDF
* configuração de pacote
* `initialize`
* `bootstrap-vocabulary!`
* registro de macros
* chamadas de salvar/carregar/exportar

### Tempo de avaliação do mundo

Acontece quando uma cena é reconstruída:

* `babel-eval`
* `run-world`
* `world`
* chamadas de funções geométricas
* loops e `let` dentro de um mundo
* emissão de vértices e arestas

Uma forma dentro de `babel-eval` é Common Lisp real. Ela pode usar loops, condicionais, matemática, bindings locais e funções geométricas do BABEL.

## Modelo do Renderizador

A janela SDL2/OpenGL possui um loop de eventos. O renderizador:

1. lida com entrada
2. reconstrói geometria quando marcada como suja
3. atualiza a câmera
4. desenha a cena wireframe
5. desenha grade, gizmo, GUI, editor e overlays de estatísticas

Para trabalho interativo no REPL, execute a janela em uma thread de fundo com `run-threaded`.
