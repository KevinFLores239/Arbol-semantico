#pragma once

#include "LectorReglas.hpp"

#include <string>
#include <vector>

struct FormulaEnRama {
    Formula formula;
    bool aplicada = false;
};

struct NodoRama {
    int id = 0;
    std::vector<FormulaEnRama> formulas;
    std::vector<NodoRama> hijos;
    bool cerrada = false;
    std::string contradiccion;
};

struct AsignacionAtomo {
    std::string letra;
    std::string valor;
};

struct ModeloRama {
    int idRama = 0;
    std::vector<AsignacionAtomo> valores;
};

struct ResultadoArbol {
    NodoRama raiz;
    std::vector<ModeloRama> modelos;
    int ramasCerradas = 0;
    int ramasAbiertas = 0;
};

class MotorArbol {
public:
    ResultadoArbol construir(const ResultadoLectura& base) const;
};