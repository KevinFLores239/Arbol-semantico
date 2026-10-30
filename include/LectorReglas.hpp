#pragma once

#include "ExpresionLogica.hpp"

#include <string>
#include <vector>

struct AtomoRegistrado {
    std::string letra;
    std::string significado;
    std::string clave;
};

struct ReglaLeida {
    std::string textoOriginal;
    Formula formula;
};

struct ResultadoLectura {
    bool correcto = false;
    std::string error;
    std::vector<AtomoRegistrado> atomos;
    std::vector<ReglaLeida> reglas;
};

class LectorReglas {
public:
    ResultadoLectura analizar(const std::string& texto) const;
};