#include "LectorReglas.hpp"
#include "MotorArbol.hpp"

#include <iostream>
#include <sstream>
#include <string>
#include <vector>

namespace {
const std::string ejemplo =
    "Si es de día, entonces voy a trabajar\n"
    "Si llueve, entonces no voy a trabajar\n"
    "Es de día\n";

void mostrarArbol(const NodoRama& nodo, const std::string& prefijo = "", bool ultimo = true) {
    std::cout << prefijo << (nodo.id == 1 ? "" : (ultimo ? "└── " : "├── "))
              << "Nodo " << nodo.id << '\n';
    const std::string contenido = prefijo + (nodo.id == 1 ? "" : (ultimo ? "    " : "│   "));
    for (const FormulaEnRama& entrada : nodo.formulas) {
        std::cout << contenido << (entrada.aplicada ? "  ✓ " : "  · ")
                  << mostrarFormula(entrada.formula) << '\n';
    }
    if (nodo.hijos.empty()) {
        if (nodo.cerrada) {
            std::cout << contenido << "  ✕ RAMA CERRADA: " << nodo.contradiccion << '\n';
        } else {
            std::cout << contenido << "  ✓ RAMA ABIERTA\n";
        }
        return;
    }
    for (std::size_t indice = 0; indice < nodo.hijos.size(); ++indice) {
        mostrarArbol(nodo.hijos[indice], contenido, indice + 1 == nodo.hijos.size());
    }
}

bool comprobar(bool condicion, const std::string& nombre) {
    std::cout << (condicion ? "[OK] " : "[FALLO] ") << nombre << '\n';
    return condicion;
}

int ejecutarPruebas() {
    LectorReglas lector;
    MotorArbol motor;
    bool todasCorrectas = true;

    const ResultadoLectura caso = lector.analizar(ejemplo);
    todasCorrectas &= comprobar(caso.correcto, "Lee el ejemplo base");
    if (caso.correcto) {
        const ResultadoArbol arbol = motor.construir(caso);
        todasCorrectas &= comprobar(caso.atomos.size() == 3
            && caso.atomos[0].significado == "es de día"
            && caso.atomos[1].significado == "voy a trabajar"
            && caso.atomos[2].significado == "llueve", "Registra p, q y r en orden");
        todasCorrectas &= comprobar(mostrarFormula(caso.reglas[0].formula) == "p → q"
            && mostrarFormula(caso.reglas[1].formula) == "r → ¬q"
            && mostrarFormula(caso.reglas[2].formula) == "p", "Genera las tres fórmulas esperadas");
        todasCorrectas &= comprobar(arbol.ramasCerradas == 2 && arbol.ramasAbiertas == 1,
            "El tableau tiene dos ramas cerradas y una abierta");
        const bool modeloEsperado = arbol.modelos.size() == 1
            && arbol.modelos[0].valores.size() == 3
            && arbol.modelos[0].valores[0].valor == "V"
            && arbol.modelos[0].valores[1].valor == "V"
            && arbol.modelos[0].valores[2].valor == "F";
        todasCorrectas &= comprobar(modeloEsperado, "El modelo abierto es p=V, q=V, r=F");
    }

    const ResultadoLectura acentos = lector.analizar("ES DE DÍA\nes de dia.\n");
    todasCorrectas &= comprobar(acentos.correcto && acentos.atomos.size() == 1,
        "Normaliza mayúsculas y acentos al comparar átomos");
    const ResultadoLectura acentoCombinado = lector.analizar("ES DE DÍA\nes de dia");
    todasCorrectas &= comprobar(acentoCombinado.correcto && acentoCombinado.atomos.size() == 1,
        "Normaliza acentos Unicode combinantes");
    const ResultadoLectura ene = lector.analizar("niño\nnino");
    todasCorrectas &= comprobar(ene.correcto && ene.atomos.size() == 2,
        "Mantiene ñ distinta de n");

    const ResultadoLectura bicondicional = lector.analizar("Llueve si y solo si hace frío");
    if (bicondicional.correcto) {
        const ResultadoArbol arbol = motor.construir(bicondicional);
        todasCorrectas &= comprobar(mostrarFormula(bicondicional.reglas[0].formula) == "p ↔ q"
            && arbol.ramasAbiertas == 2, "Expande el bicondicional en dos ramas abiertas");
    } else {
        todasCorrectas &= comprobar(false, "Expande el bicondicional en dos ramas abiertas");
    }

    const ResultadoLectura negacion = lector.analizar("Voy a trabajar\nNo voy a trabajar");
    todasCorrectas &= comprobar(negacion.correcto && negacion.atomos.size() == 1
        && motor.construir(negacion).ramasCerradas == 1, "La negación reutiliza el átomo y cierra la rama");

    const ResultadoLectura sintaxis = lector.analizar("Si llueve, voy a trabajar");
    todasCorrectas &= comprobar(!sintaxis.correcto && sintaxis.error.find("entonces") != std::string::npos,
        "Informa si falta entonces");
    const ResultadoLectura parentesis = lector.analizar("Llueve)");
    todasCorrectas &= comprobar(!parentesis.correcto, "Detecta paréntesis desbalanceados");
    const ResultadoLectura precedencia = lector.analizar("Llueve o hace frío y es de día");
    todasCorrectas &= comprobar(precedencia.correcto
        && mostrarFormula(precedencia.reglas[0].formula) == "p ∨ q ∧ r",
        "Respeta la precedencia de conjunción sobre disyunción");
    const ResultadoLectura lineaVacia = lector.analizar("Llueve\n\nHace frío");
    todasCorrectas &= comprobar(!lineaVacia.correcto && lineaVacia.error.find("línea 2") != std::string::npos,
        "Informa una línea vacía intermedia");

    const ResultadoLectura implicacionAnidada = lector.analizar(
        "Si (Si llueve entonces hace frío), entonces llevo paraguas");
    todasCorrectas &= comprobar(implicacionAnidada.correcto
        && mostrarFormula(implicacionAnidada.reglas[0].formula) == "(p → q) → r",
        "Conserva paréntesis en implicación anidada");

    const auto probarExpansion = [&](const std::string& entrada, int cerradas, int abiertas,
                                     const std::string& nombre) {
        const ResultadoLectura lectura = lector.analizar(entrada);
        if (!lectura.correcto) return comprobar(false, nombre + ": " + lectura.error);
        const ResultadoArbol arbol = motor.construir(lectura);
        return comprobar(arbol.ramasCerradas == cerradas && arbol.ramasAbiertas == abiertas, nombre);
    };
    todasCorrectas &= probarExpansion("p y q", 0, 1, "Expansión no ramificante de ∧");
    todasCorrectas &= probarExpansion("No (p o q)", 0, 1, "Expansión no ramificante de ¬∨");
    todasCorrectas &= probarExpansion("No (Si p entonces q)", 0, 1, "Expansión no ramificante de ¬→");
    todasCorrectas &= probarExpansion("No no p", 0, 1, "Expansión no ramificante de ¬¬");
    todasCorrectas &= probarExpansion("p o q", 0, 2, "Expansión ramificante de ∨");
    todasCorrectas &= probarExpansion("Si p entonces q", 0, 2, "Expansión ramificante de →");
    todasCorrectas &= probarExpansion("p si y solo si q", 0, 2, "Expansión ramificante de ↔");
    todasCorrectas &= probarExpansion("No (p y q)", 0, 2, "Expansión ramificante de ¬∧");
    todasCorrectas &= probarExpansion("No (p si y solo si q)", 0, 2, "Expansión ramificante de ¬↔");

    std::cout << (todasCorrectas ? "Todas las pruebas pasaron.\n" : "Hay pruebas fallidas.\n");
    return todasCorrectas ? 0 : 1;
}

void mostrarResultado(const ResultadoLectura& lectura, const ResultadoArbol& arbol) {
    std::cout << "\nÁTOMOS\n";
    for (const AtomoRegistrado& atomo : lectura.atomos) {
        std::cout << "  " << atomo.letra << " = " << atomo.significado << '\n';
    }
    std::cout << "\nFÓRMULAS\n";
    for (std::size_t indice = 0; indice < lectura.reglas.size(); ++indice) {
        std::cout << "  R" << indice + 1 << ": " << lectura.reglas[indice].textoOriginal
                  << " → " << mostrarFormula(lectura.reglas[indice].formula) << '\n';
    }
    std::cout << "\nÁRBOL SEMÁNTICO\n";
    mostrarArbol(arbol.raiz);
    std::cout << "\nRESULTADOS\n  Ramas cerradas: " << arbol.ramasCerradas
              << "\n  Ramas abiertas: " << arbol.ramasAbiertas << '\n';
    if (arbol.ramasAbiertas == 0) {
        std::cout << "  La base de conocimiento es inconsistente.\n";
        return;
    }
    std::cout << "  La base de conocimiento es consistente.\n  Modelos:\n";
    for (const ModeloRama& modelo : arbol.modelos) {
        std::cout << "    Rama " << modelo.idRama << ": ";
        for (std::size_t indice = 0; indice < modelo.valores.size(); ++indice) {
            if (indice != 0) std::cout << ", ";
            std::cout << modelo.valores[indice].letra << " = " << modelo.valores[indice].valor;
        }
        std::cout << '\n';
    }
}
}

int ejecutarTerminal() {
    std::cout << "Árbol semántico - análisis proposicional\n"
              << "Pega las reglas, una por línea. Termina con Ctrl+D.\n"
              << "Si no escribes nada, se analizará el ejemplo incluido.\n\n";
    std::ostringstream contenido;
    std::string linea;
    while (std::getline(std::cin, linea)) contenido << linea << '\n';
    std::string entrada = contenido.str();
    if (entrada.empty()) entrada = ejemplo;

    LectorReglas lector;
    const ResultadoLectura lectura = lector.analizar(entrada);
    if (!lectura.correcto) {
        std::cerr << lectura.error << '\n';
        return 2;
    }
    MotorArbol motor;
    mostrarResultado(lectura, motor.construir(lectura));
    return 0;
}

int ejecutarVentanaMac();

int main(int argc, char* argv[]) {
    if (argc > 1 && std::string(argv[1]) == "--pruebas") return ejecutarPruebas();
    if (argc > 1 && std::string(argv[1]) == "--terminal") return ejecutarTerminal();
    return ejecutarVentanaMac();
}
