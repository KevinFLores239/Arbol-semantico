# Árbol semántico

Motor de inferencia proposicional en español, escrito en C++17 estándar con una ventana nativa de macOS usando AppKit. Convierte reglas en fórmulas y construye un tableau para analizar la consistencia de la base de conocimiento. No depende de Qt, Homebrew, qmake ni bibliotecas externas.

## Requisitos

- macOS con Xcode Command Line Tools instaladas (`clang++`, `make`).
- AppKit viene incluido con el SDK de macOS; no requiere instalaciones adicionales.

## Compilar

En Terminal, desde la raíz del repositorio:

```sh
make
```

El objetivo predeterminado compila y abre la ventana del analizador con el ejemplo precargado. El ejecutable se crea en `bin/ArbolSemantico`; los objetos incrementales se guardan en `bin/obj/`. Objetivos disponibles:

```sh
make          # Compila y abre la ventana
make build    # Compila sin abrir la ventana
make start    # Abre la ventana
make test     # Ejecuta pruebas automáticas sin abrir la GUI
make clean    # Elimina objetos y ejecutable
make rebuild  # Limpia y compila desde cero
```

## Usar

La ventana contiene un editor multilínea editable con el ejemplo precargado, botones para analizar, cargar el ejemplo y limpiar la entrada, además del menú **Archivo** con esas mismas acciones. El reporte muestra átomos, fórmulas, árbol textual y modelos. Sustituye el ejemplo por tus reglas, una por línea, y pulsa **Analizar**. También puedes usar **⌘R**. Para usar la versión de consola:

```sh
./bin/ArbolSemantico --terminal
```

Para validar los casos integrados sin abrir la ventana:

```sh
make test
```

## Ejemplo

Entrada:

```text
Si es de día, entonces voy a trabajar
Si llueve, entonces no voy a trabajar
Es de día
```

Fórmulas:

```text
R1: p → q
R2: r → ¬q
R3: p
```

Átomos: `p = es de día`, `q = voy a trabajar`, `r = llueve`.

Resultado: dos ramas cerradas y una abierta con el modelo `p = V, q = V, r = F`. La base de conocimiento es consistente.

## Conectivos y precedencia

| Expresión | Símbolo | Lectura |
| --- | --- | --- |
| `no A` | `¬A` | Negación |
| `A y B` | `A ∧ B` | Conjunción |
| `A o B` | `A ∨ B` | Disyunción |
| `Si A, entonces B` | `A → B` | Implicación |
| `A si y solo si B` | `A ↔ B` | Bicondicional |

Precedencia, de mayor a menor: `¬`, `∧`, `∨`, `→`, `↔`. Se permiten paréntesis explícitos.

## Pruebas recomendadas

| Entrada | Resultado esperado |
| --- | --- |
| El ejemplo de arriba | Dos ramas cerradas, una abierta; modelo `p=V, q=V, r=F`. |
| `ES DE DÍA` y `es de dia.` en líneas separadas | Un único átomo por normalización de mayúsculas y acentos. |
| `niño` y `nino` en líneas separadas | Dos átomos distintos; la `ñ` no se reduce a `n`. |
| `Voy a trabajar` y `No voy a trabajar` | Un átomo `p`; una rama cerrada por `p` y `¬p`. |
| `Llueve si y solo si hace frío` | Fórmula `p ↔ q` y dos ramas abiertas. |
| `Llueve o hace frío y es de día` | Fórmula `p ∨ q ∧ r`, porque `∧` precede a `∨`. |
| `Si (Si llueve entonces hace frío), entonces llevo paraguas` | Conserva los paréntesis: `(p → q) → r`. |
| `Si llueve, voy a trabajar` | Error en esa línea: falta `entonces`. |
| `no` | Error: falta la proposición negada. |
| `(Llueve y hace frío` o `Llueve)` | Error por paréntesis desbalanceados. |
| Dos reglas separadas por una línea vacía | Error indicando la línea vacía. |

`make test` ejecuta pruebas de estos comportamientos, incluidos el caso completo de consistencia, la asignación del modelo, las nueve expansiones tableau, acentos, negación, bicondicional, precedencia, agrupación y errores sintácticos.

## Limitaciones

- El analizador es proposicional: no interpreta cuantificadores, variables, tiempos verbales ni la estructura interna de cada frase.
- `y`, `o`, `no`, `si`, `entonces` y `si y solo si` son palabras reservadas cuando aparecen solas; no hay sintaxis de escape para incluirlas dentro de un átomo.
- La implicación se escribe como `Si ... entonces ...`; no se admite `->` como sintaxis de entrada.
- Una regla se escribe por línea. Una línea vacía intermedia se reporta como error.
- `libre` significa que el átomo no está restringido por esa rama, no es un tercer valor de verdad.
- La cantidad de ramas puede crecer exponencialmente con las fórmulas ramificantes.
- La representación de entrada espera UTF-8, que es la codificación habitual de Terminal en macOS.

## Estructura

```text
assets/                 Recursos opcionales
bin/                    Ejecutable local
  obj/                  Archivos objeto
include/                Declaraciones C++ (.hpp)
src/                    Implementaciones C++ (.cpp) y ventana AppKit (.mm)
makefile                Compilación con clang++ y enlace al framework AppKit
README.md               Documentación
```
