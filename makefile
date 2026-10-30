CXX = clang++
CXXFLAGS = -std=c++17 -Wall -Wextra -Wpedantic -Iinclude
LDFLAGS = -framework AppKit

CPP_SOURCES = src/main.cpp src/ExpresionLogica.cpp src/LectorReglas.cpp src/MotorArbol.cpp
OBJECTS = $(patsubst src/%.cpp,bin/obj/%.o,$(CPP_SOURCES)) bin/obj/VentanaMac.o
EXECUTABLE = bin/ArbolSemantico
HEADERS = $(wildcard include/*.hpp)

.PHONY: all build start test clean rebuild

all: build start

build: $(EXECUTABLE)

$(EXECUTABLE): $(OBJECTS)
	$(CXX) $(OBJECTS) $(LDFLAGS) -o $@

bin/obj/%.o: src/%.cpp $(HEADERS)
	mkdir -p bin/obj
	$(CXX) $(CXXFLAGS) -c $< -o $@

bin/obj/VentanaMac.o: src/VentanaMac.mm $(HEADERS)
	mkdir -p bin/obj
	$(CXX) $(CXXFLAGS) -c $< -o $@

start: build
	./$(EXECUTABLE)

test: build
	./$(EXECUTABLE) --pruebas

clean:
	rm -f $(OBJECTS) $(EXECUTABLE)

rebuild: clean build
