# Documentação do BABEL

Este diretório contém a documentação em português do Brasil para o BABEL.

## Conteúdo

### Guia principal

* [Começando](comecando.md)
* [Conceitos Centrais](conceitos-centrais.md)
* [Como o BABEL Funciona](como-o-babel-funciona.md)
* [Referência da DSL de Mundos](referencia-da-dsl-de-mundos.md)
* [Fluxo da GUI](fluxo-da-gui.md)
* [Persistência e Exportação](persistencia-e-exportacao.md)
* [Guia de Exemplos](guia-de-exemplos.md)

### Referência detalhada

* [Referência de Primitivas Layer 0](referencia/primitivas.md)
* [Referência de Vocabulário](referencia/vocabulario.md)
* [Escrita de Programas de Mundo](referencia/mundos.md)
* [Referência do Sistema de IA](referencia/sistema-de-ia.md)
* [Referência de Persistência](referencia/persistencia.md)
* [README legado antes da atualização](referencia/leia-me-legado-antes-da-atualizacao.md)

## O que é o BABEL

BABEL é um sistema em Common Lisp para programação ao vivo de mundos wireframe 3D.

Ele permite descrever:

* mundos como formas Lisp
* geometria com primitivas de Layer 0 como caixas, esferas, arcos, planos, torres, muralhas e terreno
* estruturas arquitetônicas de nível mais alto por macros registradas no BABEL
* vocabulários reutilizáveis com arquivos `.voc`
* fonte de mundos com arquivos `.world`
* exportações de geometria como OBJ, SVG, SVG em quatro vistas e EDN

O sistema roda em SBCL e usa SDL2/OpenGL para a janela interativa. Os mundos não são carregados de um conjunto fixo de assets; eles são programas que emitem geometria.

## Escopo Atual

O BABEL hoje é focado em:

* SBCL e Quicklisp
* renderização wireframe com SDL2 e OpenGL 2.1
* cenas procedurais arquitetônicas, abstratas, de terreno e cidade
* controles GUI e edição de código estrutural dentro da janela
* invenção, pontuação, mutação e crossover de macros
* formatos simples de persistência/exportação para experimentos

Ele ainda não é uma engine completa de jogos, editor completo de malhas, simulador físico, pacote de animação ou sandbox seguro para código Lisp não confiável.

## Ordem Recomendada de Leitura

1. [Começando](comecando.md)
2. [Conceitos Centrais](conceitos-centrais.md)
3. [Como o BABEL Funciona](como-o-babel-funciona.md)
4. [Referência da DSL de Mundos](referencia-da-dsl-de-mundos.md)
5. [Fluxo da GUI](fluxo-da-gui.md)
6. [Persistência e Exportação](persistencia-e-exportacao.md)
7. [Guia de Exemplos](guia-de-exemplos.md)
8. [Referência Detalhada](referencia/primitivas.md)
