# Fluxo da GUI

BABEL possui uma GUI dentro da própria janela SDL2/OpenGL. Ela existe para permitir uso sem depender apenas do REPL.

## Áreas Principais

### Painel Esquerdo

Controla seleção de cenas, câmera/display, geração, salvar/exportar e overlays.

### Barra Superior de Visualização

A barra flutuante possui ações rápidas:

* `FIT` — enquadra o objeto atual
* `ISO` — vista isométrica
* `TOP` — vista de cima
* `FRONT` — vista frontal
* `GRID` — liga/desliga grade
* `WIRE` — alterna espessura do wireframe
* `STATS` — mostra/esconde inspetor
* `THEME` — alterna tema da UI
* `FONT-` / `FONT+` — muda tamanho da fonte do editor
* `TPL` — carrega template de código
* `SAVE` — salva o buffer em `output/babel-live-code.lisp`

### Inspetor da Cena

Mostra contagem de vértices, arestas, macros, modo de cor, estado da grade, bounding box, distância da câmera e estado sujo do editor.

### Editor de Código Estrutural

Edita o código Lisp da cena atual ou do arquivo importado. Possui seleção, copiar, cortar, colar, aplicar, recarregar, importar, hot reload, escala de fonte e salvar.

## Mouse

| Entrada | Ação |
|---|---|
| Clique em botões | Executa ações da GUI |
| Arrastar esquerdo fora da GUI | Orbita câmera |
| Arrastar direito fora da GUI | Pan da câmera |
| Scroll fora do editor | Zoom |
| Scroll no editor | Rola código |
| Arrastar no editor | Seleciona código |
| Shift-clique ou Shift-arrastar | Estende seleção |

## Atalhos

| Tecla | Ação |
|---|---|
| `F2` | Mostra/esconde GUI |
| `F3` | Mostra/esconde editor |
| `F4` | Mostra/esconde inspetor |
| `F5` | Aplica código editado |
| `F6` / `Ctrl+C` / `Cmd+C` | Copia seleção ou buffer inteiro |
| `F7` / `Ctrl+V` / `Cmd+V` | Cola do clipboard |
| `F8` | Importa arquivo de código |
| `F9` | Alterna hot reload |
| `F10` | Alterna tema |
| `F11` | Enquadra câmera |
| `H` | Ajuda |
| `Esc` | Desfoca editor ou fecha overlay |
| `Z` | Undo do mundo |

## Importação e Hot Reload

O botão de importação tenta abrir o seletor de arquivos do sistema. Se nenhum helper estiver disponível, BABEL usa caminhos comuns como `import.lisp`, `output/import.lisp` e `code.lisp`.

Depois de importar um arquivo, o hot reload observa mudanças e reaplica o código automaticamente.

## Edição Segura

Se o código editado tiver erro de leitura ou avaliação:

* a cena 3D antiga continua ativa
* o editor mostra o erro
* o buffer editado fica disponível para correção

## Fluxo Recomendado

1. Escolha uma cena embutida.
2. Pressione `F3` ou `EDITOR`.
3. Modifique o código estrutural.
4. Pressione `F5` ou `APPLY`.
5. Use `FIT` para enquadrar.
6. Salve `.world` ou exporte a geometria.
