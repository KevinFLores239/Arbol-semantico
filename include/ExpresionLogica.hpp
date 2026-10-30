#pragma once

#include <memory>
#include <string>

enum class OperadorLogico {
    Atomo,
    Negacion,
    Conjuncion,
    Disyuncion,
    Implicacion,
    Bicondicional
};

struct ExpresionLogica;
using Formula = std::shared_ptr<ExpresionLogica>;

struct ExpresionLogica {
    OperadorLogico operador = OperadorLogico::Atomo;
    std::string atomo;
    Formula izquierda;
    Formula derecha;
};

Formula crearAtomo(const std::string& letra);
Formula crearNegacion(const Formula& formula);
Formula crearBinaria(OperadorLogico operador, const Formula& izquierda, const Formula& derecha);
std::string mostrarFormula(const Formula& formula);
std::string claveNormalizada(const std::string& texto);