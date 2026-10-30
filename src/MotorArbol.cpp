#include "MotorArbol.hpp"

#include <unordered_map>
#include <vector>

namespace {
struct Expansion {
    bool ramifica = false;
    std::vector<std::vector<Formula>> grupos;
};

Formula negar(const Formula& formula) {
    if (formula && formula->operador == OperadorLogico::Negacion) return formula->izquierda;
    return crearNegacion(formula);
}

Expansion obtenerExpansion(const Formula& formula) {
    if (!formula) return {};
    if (formula->operador == OperadorLogico::Negacion) {
        const Formula interior = formula->izquierda;
        if (!interior) return {};
        switch (interior->operador) {
        case OperadorLogico::Atomo:
            return {};
        case OperadorLogico::Negacion:
            return {false, {{interior->izquierda}}};
        case OperadorLogico::Conjuncion:
            return {true, {{negar(interior->izquierda)}, {negar(interior->derecha)}}};
        case OperadorLogico::Disyuncion:
            return {false, {{negar(interior->izquierda), negar(interior->derecha)}}};
        case OperadorLogico::Implicacion:
            return {false, {{interior->izquierda, negar(interior->derecha)}}};
        case OperadorLogico::Bicondicional:
            return {true, {{interior->izquierda, negar(interior->derecha)},
                           {negar(interior->izquierda), interior->derecha}}};
        }
    }

    switch (formula->operador) {
    case OperadorLogico::Atomo:
    case OperadorLogico::Negacion:
        return {};
    case OperadorLogico::Conjuncion:
        return {false, {{formula->izquierda, formula->derecha}}};
    case OperadorLogico::Disyuncion:
        return {true, {{formula->izquierda}, {formula->derecha}}};
    case OperadorLogico::Implicacion:
        return {true, {{negar(formula->izquierda)}, {formula->derecha}}};
    case OperadorLogico::Bicondicional:
        return {true, {{formula->izquierda, formula->derecha},
                       {negar(formula->izquierda), negar(formula->derecha)}}};
    }
    return {};
}

bool esLiteral(const Formula& formula) {
    return formula && (formula->operador == OperadorLogico::Atomo
        || (formula->operador == OperadorLogico::Negacion && formula->izquierda
            && formula->izquierda->operador == OperadorLogico::Atomo));
}

bool detectarContradiccion(const NodoRama& nodo, std::string& mensaje) {
    std::unordered_map<std::string, bool> polaridades;
    for (const FormulaEnRama& entrada : nodo.formulas) {
        if (!esLiteral(entrada.formula)) continue;
        const bool negada = entrada.formula->operador == OperadorLogico::Negacion;
        const std::string& letra = negada ? entrada.formula->izquierda->atomo : entrada.formula->atomo;
        const auto anterior = polaridades.find(letra);
        if (anterior != polaridades.end() && anterior->second != negada) {
            mensaje = negada
                ? letra + " y ¬" + letra
                : "¬" + letra + " y " + letra;
            return true;
        }
        polaridades.insert_or_assign(letra, negada);
    }
    return false;
}

void registrarModelo(const NodoRama& nodo, const std::vector<AtomoRegistrado>& atomos,
                     ResultadoArbol& resultado) {
    std::unordered_map<std::string, std::string> valores;
    for (const FormulaEnRama& entrada : nodo.formulas) {
        if (!esLiteral(entrada.formula)) continue;
        const bool negada = entrada.formula->operador == OperadorLogico::Negacion;
        const std::string& letra = negada ? entrada.formula->izquierda->atomo : entrada.formula->atomo;
        valores.emplace(letra, negada ? "F" : "V");
    }

    ModeloRama modelo;
    modelo.idRama = nodo.id;
    for (const AtomoRegistrado& atomo : atomos) {
        const auto valor = valores.find(atomo.letra);
        modelo.valores.push_back({atomo.letra, valor == valores.end() ? "libre" : valor->second});
    }
    resultado.modelos.push_back(modelo);
}

void resolver(NodoRama& nodo, const std::vector<AtomoRegistrado>& atomos,
              ResultadoArbol& resultado, int& siguienteId) {
    std::string contradiccion;
    if (detectarContradiccion(nodo, contradiccion)) {
        nodo.cerrada = true;
        nodo.contradiccion = contradiccion;
        ++resultado.ramasCerradas;
        return;
    }

    std::size_t indiceExpansion = nodo.formulas.size();
    Expansion elegida;
    for (int fase = 0; fase < 2 && indiceExpansion == nodo.formulas.size(); ++fase) {
        for (std::size_t indice = 0; indice < nodo.formulas.size(); ++indice) {
            if (nodo.formulas[indice].aplicada) continue;
            Expansion candidata = obtenerExpansion(nodo.formulas[indice].formula);
            if (candidata.grupos.empty() || candidata.ramifica != (fase == 1)) continue;
            indiceExpansion = indice;
            elegida = std::move(candidata);
            break;
        }
    }

    if (indiceExpansion == nodo.formulas.size()) {
        ++resultado.ramasAbiertas;
        registrarModelo(nodo, atomos, resultado);
        return;
    }

    nodo.formulas[indiceExpansion].aplicada = true;
    if (!elegida.ramifica) {
        for (const Formula& formula : elegida.grupos.front()) nodo.formulas.push_back({formula, false});
        resolver(nodo, atomos, resultado, siguienteId);
        return;
    }

    for (const std::vector<Formula>& grupo : elegida.grupos) {
        NodoRama hijo;
        hijo.id = siguienteId++;
        hijo.formulas = nodo.formulas;
        for (const Formula& formula : grupo) hijo.formulas.push_back({formula, false});
        nodo.hijos.push_back(std::move(hijo));
    }
    for (NodoRama& hijo : nodo.hijos) resolver(hijo, atomos, resultado, siguienteId);
}
}

ResultadoArbol MotorArbol::construir(const ResultadoLectura& base) const {
    ResultadoArbol resultado;
    resultado.raiz.id = 1;
    if (!base.correcto) return resultado;
    for (const ReglaLeida& regla : base.reglas) resultado.raiz.formulas.push_back({regla.formula, false});
    int siguienteId = 2;
    resolver(resultado.raiz, base.atomos, resultado, siguienteId);
    return resultado;
}