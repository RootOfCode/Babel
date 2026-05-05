# BABEL — Referência do Sistema de IA

> Página migrada do antigo diretório `docs/` para manter toda a documentação dentro das pastas de idioma. Nomes de funções, exemplos Lisp, formatos de arquivo e símbolos técnicos foram preservados para evitar perda de precisão.

BABEL's AI system has three components: the **Inventor** (creates new macros
from templates), the **Scorer** (evaluates their quality), and the **Evolver**
(mutates and cross-breeds the best ones).

---

## Invention

### Triggering invention

```lisp
;; Invent 3 macros at layer 6, up to 20 attempts each
(babel:invent-layer! 6 20 3)

;; Or press G in the window (invents one layer above the current maximum)
```

### How it works

```
1. TEMPLATE SELECTION
   Pick one of 9 composition templates at random.

2. HOLE FILLING
   Each placeholder in the template is replaced with a generated sub-form.
   Macro-call holes → weighted-random function from layers <= current-1
   Count holes      → integer 2–8
   Float holes      → architecture-appropriate random float
   Variable holes   → fresh unique symbol

3. ARG GENERATION
   Arguments for macro calls use parameter name heuristics:
   "floors", "steps", "count"  → integer 2–10
   "radius", "tube"            → float 1–8
   "height", "rise"            → float 2–15
   "width", "span", "size"     → float 5–40
   "x", "z", "cx", "cz"       → float -20..+20
   "taper", "density"          → float 0.1–0.5
   "x0", "z0"                  → float -25..-5
   "x1", "z1"                  → float 5..25
   "thickness"                 → float 0.5–2.5

4. VALIDATION
   Compile as anonymous lambda — never eval by name.
   Checks: no circular deps, tree depth <= 20, not a body duplicate,
   produces at least one edge when called with sample args,
   total edges <= 4000.

5. SCORING
   score = 0.18×economy + 0.22×novelty + 0.28×visual
         + 0.14×reuse  + 0.08×compat  + 0.10×connectivity

6. REGISTRATION
   (defun NAME PARAMS BODY) via eval.
   Added to *babel-registry*, immediately callable from world programs.
```

### Composition templates

| Template | Pattern | Good for |
|---|---|---|
| `repeat-pattern` | `(loop for I from 0 below N do CALL)` | Repeated elements |
| `sequential` | `(progn CALL-1 CALL-2)` | Combining two structures |
| `with-binding` | `(let ((V EXPR)) CALL)` | Shared computed value |
| `radial-arrangement` | Loop with cos/sin | Circular layouts |
| `vertical-stack` | Loop with Y offsets | Towers, floors |
| `grid-arrangement` | Nested loops on XZ | City blocks, arrays |
| `paired-symmetric` | Two calls mirrored on X | Bilateral symmetry |
| `bridged` | Two calls + wall-segment | Connected structures |
| `four-corners` | Four independent calls | Corner elements |

---

## Scoring

Each macro is scored across six dimensions. The composite score is stored
on the `babel-macro` struct and used by evolution and weighted sampling.

### Economy (weight 0.18)

Rewards achieving structural complexity with few dependencies.

```
economy = min(1.0, depth / (deps + 1))
```

A deep tree with few direct dependencies scores highly — it means the macro
leverages existing vocabulary efficiently.

### Novelty (weight 0.22)

Rewards geometry that spreads widely in space.

```
novelty = min(1.0, bounding-box-diagonal / 20.0)
```

Small, tight geometry scores low. A macro that fills a wide area scores high.

### Visual Interest (weight 0.28)

Rewards varied height — silhouette complexity.

```
visual = min(1.0, (max-y - min-y) / 10.0)
```

Flat geometry (all at y=0) scores zero. Tall, varied structures score high.
This is the highest-weighted dimension because height variation is the most
visually salient feature of architectural wireframes.

### Reusability (weight 0.14)

Rewards macros whose output varies meaningfully across different parameter sets.
Runs 6 sample evaluations with different args and measures the spread of
bounding box sizes.

```
reusability = min(1.0, (max-extent - min-extent) / 10.0)
```

A macro that always produces the same size regardless of params scores low.

### Compatibility (weight 0.08)

Rewards macros that are readily composable.

```
compat = min(1.0, 0.2 × num-dependencies)
```

Macros with more dependencies are more likely to be composable.

### Connectivity (weight 0.10)

Rewards macros that explicitly connect structures together. This biases the
AI toward generating architecturally coherent compositions rather than
scattered unconnected forms.

```
+0.35 if body uses wall-segment
+0.15 if body uses arch
+0.10 per let/let* binding (spatial coordination)
capped at 1.0
```

### Rescoring

```lisp
(babel:rescore-all!)   ; recompute scores for all layer > 0 macros
```

---

## Evolution

Evolution mutates and cross-breeds the top-scoring macros to produce variants.

### Triggering evolution

```lisp
(babel:evolve! 5)   ; 5 rounds of mutation + crossover
;; Or press E in the window (runs 3 rounds)
```

### Mutation operators

**`mutate-substitute-call!`** — replace a random call-site in the body
with a different randomly chosen BABEL function at the same layer.

**`mutate-add-repetition!`** — wrap the entire body in a `(loop for N from 0 below K do ...)` with K = 2–5.

**`mutate-offset-args!`** — walk the body and perturb all numeric literals
by ±20%, producing a geometrically similar but differently scaled variant.

**`crossover!`** — pick a random call-site from one macro's body and splice
it into a random call-site of another macro's body.

### Acceptance threshold

A variant is only registered if its score is at least 75% of the parent's
score. This prevents the population from drifting toward low-quality forms.

### Variant naming

Variants are named `PARENT-SUFFIX`:
- Substitution variants: `KEEP-SUB`
- Repetition variants: `KEEP-REP`
- Offset variants: `KEEP-OFF`
- Crossover variants: `KEEP-CROSS`

---

## Registry Internals

```lisp
*babel-registry*    ; hash-table: symbol → babel-macro
*generation*        ; monotonically increasing counter

;; Queries
(babel:macros-up-to-layer 3)        ; list of babel-macro structs
(babel:find-babel-macro 'fortress)  ; single lookup
(babel:babel-macro-names)           ; all registered names

;; Registration
(babel:register-macro! m)           ; installs defun + adds to registry
```

The registry is the single source of truth. `register-macro!` calls `eval`
with a `defun` form, so registered macros are real CL functions callable
from anywhere — they don't need any special dispatch.

---

## Growing a Deep Vocabulary

The recommended workflow for growing a vocabulary over a long session:

```lisp
;; 1. Open the window
(babel:initialize)
(babel:run-threaded)

;; 2. Grow several AI layers
(babel:invent-layer! 6 20 5)
(babel:invent-layer! 7 20 5)
(babel:invent-layer! 8 20 5)

;; 3. Evolve the best ones
(babel:evolve! 10)

;; 4. Rescore everything to reflect evolved variants
(babel:rescore-all!)

;; 5. Inspect what you have
(babel:print-top-macros 15)
(babel:list-macros-by-layer)

;; 6. Use the best AI macros in a world
(babel:babel-eval
  (macro-7-1234 0.0 0.0)
  (plane 0.0 0.0 200.0 200.0 0.0))

;; 7. Save the vocabulary for later
(babel:save-vocabulary! (babel:babel-out "session-vocab.voc"))
```