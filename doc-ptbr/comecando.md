# Começando

## Requisitos

* SBCL 2.0 ou mais novo
* Quicklisp
* arquivos de desenvolvimento do SDL2
* suporte OpenGL no sistema

Em sistemas Debian/Ubuntu:

```bash
sudo apt update
sudo apt install sbcl libsdl2-dev
```

Quicklisp é necessário porque o sistema ASDF depende de bibliotecas como `sdl2`, `cl-opengl`, `cl-glu`, `alexandria`, `bordeaux-threads` e `cffi`.

## Primeira Instalação

Na raiz do projeto:

```bash
chmod +x install.sh run.sh
./install.sh
```

O script instala/prepara dependências, limpa caches antigos quando necessário, carrega o sistema, inicializa o BABEL e abre a GUI.

## Execução Normal

Depois da primeira configuração bem-sucedida:

```bash
./run.sh
```

Esse é o jeito mais simples de abrir o fluxo dentro da janela.

## Execução via Quicklisp / REPL

Se você já tem Quicklisp e SBCL:

```lisp
(pushnew #P"/path/to/Babel/" asdf:*central-registry* :test #'equal)
(ql:quickload :babel-world)
(babel:initialize)
(babel:run-threaded)
```

Depois avalie um mundo ao vivo:

```lisp
(babel:babel-eval
  (plane 0.0 0.0 200.0 200.0 0.0)
  (fortress 0.0 0.0 50.0))
```

Use `run-threaded` para trabalhar no REPL. Chamar `(babel:run)` diretamente bloqueia a thread atual porque o SDL assume o loop de eventos.

## Mundo Mínimo

```lisp
(babel:babel-eval
  (plane 0.0 0.0 120.0 120.0 0.0)
  (box 0.0 5.0 0.0 10.0 10.0 10.0)
  (arch 0.0 0.0 -12.0 12.0 8.0 2.0 :gothic))
```

Isso limpa a cena atual, emite um plano, adiciona uma caixa e depois um arco gótico.

## Primeiras Ações na GUI

Quando a janela abrir:

* use o painel esquerdo para selecionar cenas embutidas
* use `FIT`, `ISO`, `TOP` e `FRONT` para controlar a câmera
* use `EDITOR` ou `F3` para abrir o editor de código estrutural
* edite o código e pressione `APPLY` ou `F5`
* use ações de `.world`, OBJ, SVG, screenshot ou exportação completa pela GUI

## Notas Comuns de Inicialização

* Se o REPL travar, você provavelmente chamou `(babel:run)` diretamente. Use `(babel:run-threaded)`.
* Se o SDL2 falhar ao carregar, instale o pacote de desenvolvimento do SDL2.
* Se o Quicklisp não encontrar o sistema, adicione a raiz do projeto em `asdf:*central-registry*` ou coloque o projeto em `~/quicklisp/local-projects/`.
* Se uma edição de código falhar, a cena anterior continua ativa e o editor mostra o erro.
