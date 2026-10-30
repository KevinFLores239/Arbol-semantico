#include "LectorReglas.hpp"

#include <cctype>
#include <sstream>
#include <stdexcept>
#include <string>
#include <unordered_map>
#include <utility>
#include <vector>

namespace {
enum class TipoToken { Palabra, Y, O, No, Si, Entonces, Bicondicional, Abre, Cierra };

struct Token {
    TipoToken tipo;
    std::string texto;
};

std::string reemplazar(std::string texto, const std::string& origen, const std::string& destino) {
    std::size_t posicion = 0;
    while ((posicion = texto.find(origen, posicion)) != std::string::npos) {
        texto.replace(posicion, origen.size(), destino);
        posicion += destino.size();
    }
    return texto;
}

std::string minusculasUtf8(std::string texto) {
    const std::pair<const char*, const char*> cambios[] = {
        {"Á", "á"}, {"É", "é"}, {"Í", "í"}, {"Ó", "ó"}, {"Ú", "ú"},
        {"Ü", "ü"}, {"Ñ", "ñ"}
    };
    for (const auto& cambio : cambios) texto = reemplazar(std::move(texto), cambio.first, cambio.second);
    for (char& caracter : texto) {
        const unsigned char valor = static_cast<unsigned char>(caracter);
        if (valor < 0x80) caracter = static_cast<char>(std::tolower(valor));
    }
    return texto;
}

bool separador(unsigned char caracter) {
    if (caracter >= 0x80) return false;
    return std::isspace(caracter) || caracter == ',' || caracter == '.' || caracter == ';'
        || caracter == ':' || caracter == '!' || caracter == '?' || caracter == '\''
        || caracter == '"' || caracter == '`';
}

std::vector<Token> tokenizar(const std::string& texto) {
    std::vector<std::string> palabras;
    std::string actual;
    const std::string limpio = minusculasUtf8(texto);
    auto terminarPalabra = [&] {
        if (!actual.empty()) {
            palabras.push_back(std::move(actual));
            actual.clear();
        }
    };
    for (unsigned char caracter : limpio) {
        if (caracter == '(' || caracter == ')') {
            terminarPalabra();
            palabras.emplace_back(1, static_cast<char>(caracter));
        } else if (separador(caracter)) {
            terminarPalabra();
        } else {
            actual.push_back(static_cast<char>(caracter));
        }
    }
    terminarPalabra();

    std::vector<Token> tokens;
    for (std::size_t indice = 0; indice < palabras.size();) {
        const std::string& palabra = palabras[indice];
        if (palabra == "si" && indice + 3 < palabras.size() && palabras[indice + 1] == "y"
            && palabras[indice + 2] == "solo" && palabras[indice + 3] == "si") {
            tokens.push_back({TipoToken::Bicondicional, "si y solo si"});
            indice += 4;
        } else if (palabra == "(") {
            tokens.push_back({TipoToken::Abre, palabra});
            ++indice;
        } else if (palabra == ")") {
            tokens.push_back({TipoToken::Cierra, palabra});
            ++indice;
        } else if (palabra == "y") {
            tokens.push_back({TipoToken::Y, palabra});
            ++indice;
        } else if (palabra == "o") {
            tokens.push_back({TipoToken::O, palabra});
            ++indice;
        } else if (palabra == "no") {
            tokens.push_back({TipoToken::No, palabra});
            ++indice;
        } else if (palabra == "si") {
            tokens.push_back({TipoToken::Si, palabra});
            ++indice;
        } else if (palabra == "entonces") {
            tokens.push_back({TipoToken::Entonces, palabra});
            ++indice;
        } else {
            tokens.push_back({TipoToken::Palabra, palabra});
            ++indice;
        }
    }
    return tokens;
}

class AnalizadorLinea {
public:
    AnalizadorLinea(const std::vector<Token>& tokens, std::vector<AtomoRegistrado>& atomos,
                    std::unordered_map<std::string, std::string>& letras)
        : tokens_(tokens), atomos_(atomos), letras_(letras) {}

    Formula analizar() {
        Formula resultado = leerBicondicional();
        if (posicion_ != tokens_.size()) {
            if (actual()->tipo == TipoToken::Entonces) {
                throw std::runtime_error("«entonces» aparece sin un «si» correspondiente.");
            }
            if (actual()->tipo == TipoToken::Cierra) {
                throw std::runtime_error("Hay un paréntesis de cierre sin su apertura.");
            }
            throw std::runtime_error("No se pudo interpretar la expresión cerca de «" + actual()->texto + "».");
        }
        return resultado;
    }

private:
    const Token* actual() const {
        return posicion_ < tokens_.size() ? &tokens_[posicion_] : nullptr;
    }

    bool aceptar(TipoToken tipo) {
        if (actual() && actual()->tipo == tipo) {
            ++posicion_;
            return true;
        }
        return false;
    }

    Formula leerBicondicional() {
        Formula izquierda = leerImplicacion();
        while (aceptar(TipoToken::Bicondicional)) {
            Formula derecha = leerImplicacion();
            izquierda = crearBinaria(OperadorLogico::Bicondicional, izquierda, derecha);
        }
        return izquierda;
    }

    Formula leerImplicacion() {
        if (aceptar(TipoToken::Si)) {
            if (!actual()) throw std::runtime_error("La regla empieza con «si» pero no contiene «entonces».");
            Formula condicion = leerDisyuncion();
            if (!aceptar(TipoToken::Entonces)) {
                throw std::runtime_error("La regla empieza con «si» pero no contiene «entonces».");
            }
            if (!actual()) throw std::runtime_error("Falta la proposición después de «entonces».");
            Formula consecuencia = leerImplicacion();
            return crearBinaria(OperadorLogico::Implicacion, condicion, consecuencia);
        }
        return leerDisyuncion();
    }

    Formula leerDisyuncion() {
        Formula izquierda = leerConjuncion();
        while (aceptar(TipoToken::O)) {
            Formula derecha = leerConjuncion();
            izquierda = crearBinaria(OperadorLogico::Disyuncion, izquierda, derecha);
        }
        return izquierda;
    }

    Formula leerConjuncion() {
        Formula izquierda = leerUnaria();
        while (aceptar(TipoToken::Y)) {
            Formula derecha = leerUnaria();
            izquierda = crearBinaria(OperadorLogico::Conjuncion, izquierda, derecha);
        }
        return izquierda;
    }

    Formula leerUnaria() {
        if (aceptar(TipoToken::No)) {
            if (!actual() || actual()->tipo == TipoToken::Cierra || actual()->tipo == TipoToken::Entonces
                || actual()->tipo == TipoToken::Y || actual()->tipo == TipoToken::O) {
                throw std::runtime_error("«no» debe ir seguido de una proposición.");
            }
            return crearNegacion(leerUnaria());
        }
        if (aceptar(TipoToken::Abre)) {
            Formula dentro = leerBicondicional();
            if (!aceptar(TipoToken::Cierra)) {
                throw std::runtime_error("Hay un paréntesis de apertura sin su cierre.");
            }
            return dentro;
        }
        if (aceptar(TipoToken::Cierra)) {
            throw std::runtime_error("Hay un paréntesis de cierre sin su apertura.");
        }
        if (!actual() || actual()->tipo != TipoToken::Palabra) {
            throw std::runtime_error("Se esperaba una proposición simple.");
        }

        std::string significado;
        while (actual() && actual()->tipo == TipoToken::Palabra) {
            if (!significado.empty()) significado.push_back(' ');
            significado += tokens_[posicion_].texto;
            ++posicion_;
        }
        const std::string clave = claveNormalizada(significado);
        auto encontrada = letras_.find(clave);
        if (encontrada == letras_.end()) {
            const std::size_t numero = atomos_.size();
            std::string letra;
            if (numero < 11) {
                letra = static_cast<char>('p' + numero);
            } else {
                letra = "p" + std::to_string(numero - 10);
            }
            encontrada = letras_.emplace(clave, letra).first;
            atomos_.push_back({letra, significado, clave});
        }
        return crearAtomo(encontrada->second);
    }

    const std::vector<Token>& tokens_;
    std::vector<AtomoRegistrado>& atomos_;
    std::unordered_map<std::string, std::string>& letras_;
    std::size_t posicion_ = 0;
};
}

ResultadoLectura LectorReglas::analizar(const std::string& texto) const {
    ResultadoLectura resultado;
    std::unordered_map<std::string, std::string> letras;
    std::istringstream entrada(texto);
    std::string linea;
    std::vector<std::string> lineas;
    while (std::getline(entrada, linea)) {
        if (!linea.empty() && linea.back() == '\r') linea.pop_back();
        lineas.push_back(linea);
    }
    if (lineas.empty() && !texto.empty()) lineas.push_back(texto);
    if (lineas.empty()) {
        resultado.error = "La entrada está vacía: escribe al menos una regla.";
        return resultado;
    }

    for (std::size_t indice = 0; indice < lineas.size(); ++indice) {
        const std::string& original = lineas[indice];
        if (original.find_first_not_of(" \t\r") == std::string::npos) {
            resultado.error = "La línea " + std::to_string(indice + 1)
                + " está vacía. Cada línea debe contener una regla o un hecho.";
            return resultado;
        }
        const auto tokens = tokenizar(original);
        if (tokens.empty()) {
            resultado.error = "La línea " + std::to_string(indice + 1) + " no contiene una proposición.";
            return resultado;
        }
        try {
            AnalizadorLinea analizador(tokens, resultado.atomos, letras);
            resultado.reglas.push_back({original, analizador.analizar()});
        } catch (const std::exception& error) {
            resultado.error = "Error en la línea " + std::to_string(indice + 1) + ": " + error.what();
            return resultado;
        }
    }
    resultado.correcto = true;
    return resultado;
}
