#include "ExpresionLogica.hpp"

#include <cstdint>
#include <string>
#include <vector>

namespace {
std::vector<std::uint32_t> decodificarUtf8(const std::string& texto) {
    std::vector<std::uint32_t> puntos;
    for (std::size_t indice = 0; indice < texto.size();) {
        const unsigned char inicial = static_cast<unsigned char>(texto[indice]);
        std::uint32_t punto = 0;
        std::size_t longitud = 1;
        if (inicial < 0x80) {
            punto = inicial;
        } else if ((inicial & 0xE0) == 0xC0 && indice + 1 < texto.size()) {
            punto = inicial & 0x1F;
            longitud = 2;
        } else if ((inicial & 0xF0) == 0xE0 && indice + 2 < texto.size()) {
            punto = inicial & 0x0F;
            longitud = 3;
        } else if ((inicial & 0xF8) == 0xF0 && indice + 3 < texto.size()) {
            punto = inicial & 0x07;
            longitud = 4;
        } else {
            puntos.push_back(inicial);
            ++indice;
            continue;
        }
        for (std::size_t desplazamiento = 1; desplazamiento < longitud; ++desplazamiento) {
            punto = (punto << 6) | (static_cast<unsigned char>(texto[indice + desplazamiento]) & 0x3F);
        }
        puntos.push_back(punto);
        indice += longitud;
    }
    return puntos;
}

void codificarUtf8(std::uint32_t punto, std::string& salida) {
    if (punto <= 0x7F) {
        salida.push_back(static_cast<char>(punto));
    } else if (punto <= 0x7FF) {
        salida.push_back(static_cast<char>(0xC0 | (punto >> 6)));
        salida.push_back(static_cast<char>(0x80 | (punto & 0x3F)));
    } else if (punto <= 0xFFFF) {
        salida.push_back(static_cast<char>(0xE0 | (punto >> 12)));
        salida.push_back(static_cast<char>(0x80 | ((punto >> 6) & 0x3F)));
        salida.push_back(static_cast<char>(0x80 | (punto & 0x3F)));
    } else {
        salida.push_back(static_cast<char>(0xF0 | (punto >> 18)));
        salida.push_back(static_cast<char>(0x80 | ((punto >> 12) & 0x3F)));
        salida.push_back(static_cast<char>(0x80 | ((punto >> 6) & 0x3F)));
        salida.push_back(static_cast<char>(0x80 | (punto & 0x3F)));
    }
}

int precedencia(OperadorLogico operador) {
    switch (operador) {
    case OperadorLogico::Bicondicional: return 1;
    case OperadorLogico::Implicacion: return 2;
    case OperadorLogico::Disyuncion: return 3;
    case OperadorLogico::Conjuncion: return 4;
    case OperadorLogico::Negacion: return 5;
    case OperadorLogico::Atomo: return 6;
    }
    return 0;
}

std::string textoOperador(OperadorLogico operador) {
    switch (operador) {
    case OperadorLogico::Conjuncion: return "∧";
    case OperadorLogico::Disyuncion: return "∨";
    case OperadorLogico::Implicacion: return "→";
    case OperadorLogico::Bicondicional: return "↔";
    default: return {};
    }
}

std::string renderizar(const Formula& formula, int padre = 0, bool ladoDerecho = false,
                       OperadorLogico operadorPadre = OperadorLogico::Atomo) {
    if (!formula) return {};
    const int propia = precedencia(formula->operador);
    std::string resultado;
    if (formula->operador == OperadorLogico::Atomo) {
        resultado = formula->atomo;
    } else if (formula->operador == OperadorLogico::Negacion) {
        resultado = "¬" + renderizar(formula->izquierda, propia);
    } else {
        resultado = renderizar(formula->izquierda, propia, false, formula->operador) + " "
            + textoOperador(formula->operador) + " "
            + renderizar(formula->derecha, propia, true, formula->operador);
    }
    bool requiereParentesis = propia < padre;
    if (propia == padre && padre != 0 && formula->operador != operadorPadre) requiereParentesis = true;
    if (propia == padre && !ladoDerecho && operadorPadre == OperadorLogico::Implicacion
        && formula->operador == OperadorLogico::Implicacion) {
        requiereParentesis = true;
    }
    if (propia == padre && ladoDerecho && operadorPadre == OperadorLogico::Bicondicional) {
        requiereParentesis = true;
    }
    return requiereParentesis ? "(" + resultado + ")" : resultado;
}
}

Formula crearAtomo(const std::string& letra) {
    auto formula = std::make_shared<ExpresionLogica>();
    formula->operador = OperadorLogico::Atomo;
    formula->atomo = letra;
    return formula;
}

Formula crearNegacion(const Formula& formula) {
    auto resultado = std::make_shared<ExpresionLogica>();
    resultado->operador = OperadorLogico::Negacion;
    resultado->izquierda = formula;
    return resultado;
}

Formula crearBinaria(OperadorLogico operador, const Formula& izquierda, const Formula& derecha) {
    auto resultado = std::make_shared<ExpresionLogica>();
    resultado->operador = operador;
    resultado->izquierda = izquierda;
    resultado->derecha = derecha;
    return resultado;
}

std::string mostrarFormula(const Formula& formula) {
    return renderizar(formula);
}

std::string claveNormalizada(const std::string& texto) {
    const auto puntos = decodificarUtf8(texto);
    std::string salida;
    bool espacioPendiente = false;
    for (std::size_t indice = 0; indice < puntos.size(); ++indice) {
        std::uint32_t punto = puntos[indice];
        if (punto == ' ' || punto == '\t' || punto == '\r' || punto == '\n') {
            espacioPendiente = !salida.empty();
            continue;
        }
        if (espacioPendiente) {
            salida.push_back(' ');
            espacioPendiente = false;
        }
        if (punto >= 'A' && punto <= 'Z') punto += 'a' - 'A';
        if (punto == 'n' && indice + 1 < puntos.size() && puntos[indice + 1] == 0x0303) {
            codificarUtf8(0x00F1, salida);
            ++indice;
            continue;
        }
        if (punto >= 0x0300 && punto <= 0x036F) continue;
        switch (punto) {
        case 0x00C1: case 0x00E1: punto = 'a'; break;
        case 0x00C9: case 0x00E9: punto = 'e'; break;
        case 0x00CD: case 0x00ED: punto = 'i'; break;
        case 0x00D3: case 0x00F3: punto = 'o'; break;
        case 0x00DA: case 0x00FA: case 0x00DC: case 0x00FC: punto = 'u'; break;
        case 0x00D1: punto = 0x00F1; break;
        default: break;
        }
        codificarUtf8(punto, salida);
    }
    return salida;
}
