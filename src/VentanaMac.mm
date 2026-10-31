#import <AppKit/AppKit.h>

#include "LectorReglas.hpp"
#include "MotorArbol.hpp"

#include <algorithm>
#include <sstream>
#include <string>
#include <utility>
#include <vector>

namespace {
const std::string ejemploVentana =
    "Si es de día, entonces voy a trabajar\n"
    "Si llueve, entonces no voy a trabajar\n"
    "Es de día";

void escribirNodo(std::ostringstream& salida, const NodoRama& nodo,
                  const std::string& prefijo = "", bool ultimo = true) {
    salida << prefijo << (nodo.id == 1 ? "" : (ultimo ? "└── " : "├── "))
           << "Nodo " << nodo.id << '\n';
    const std::string contenido = prefijo + (nodo.id == 1 ? "" : (ultimo ? "    " : "│   "));
    for (const FormulaEnRama& entrada : nodo.formulas) {
        salida << contenido << (entrada.aplicada ? "  ✓ " : "  · ")
               << mostrarFormula(entrada.formula) << '\n';
    }
    if (nodo.hijos.empty()) {
        if (nodo.cerrada) {
            salida << contenido << "  ✕ RAMA CERRADA: " << nodo.contradiccion << '\n';
        } else {
            salida << contenido << "  ✓ RAMA ABIERTA\n";
        }
        return;
    }
    for (std::size_t indice = 0; indice < nodo.hijos.size(); ++indice) {
        escribirNodo(salida, nodo.hijos[indice], contenido, indice + 1 == nodo.hijos.size());
    }
}

using Apartado = std::pair<std::string, std::string>;

void agregarApartadosRamas(std::vector<Apartado>& apartados, const NodoRama& nodo) {
    if (nodo.hijos.empty()) {
        std::ostringstream contenido;
        contenido << "RAMA " << nodo.id << '\n';
        for (const FormulaEnRama& formula : nodo.formulas) {
            contenido << (formula.aplicada ? "  ✓ " : "  · ")
                      << mostrarFormula(formula.formula) << '\n';
        }
        if (nodo.cerrada) {
            contenido << "\n✕ RAMA CERRADA\nContradicción: " << nodo.contradiccion << '\n';
        } else {
            contenido << "\n✓ RAMA ABIERTA\n";
        }
        const std::string estado = nodo.cerrada ? "cerrada" : "abierta";
        apartados.emplace_back("Rama " + std::to_string(nodo.id) + " (" + estado + ")", contenido.str());
        return;
    }
    for (const NodoRama& hijo : nodo.hijos) agregarApartadosRamas(apartados, hijo);
}

std::vector<Apartado> crearApartados(const std::string& entrada) {
    LectorReglas lector;
    const ResultadoLectura lectura = lector.analizar(entrada);
    if (!lectura.correcto) return {{"Error de entrada", lectura.error}};

    MotorArbol motor;
    const ResultadoArbol arbol = motor.construir(lectura);
    std::ostringstream atomos;
    for (const AtomoRegistrado& atomo : lectura.atomos) {
        atomos << "  " << atomo.letra << " = " << atomo.significado << '\n';
    }
    std::ostringstream formulas;
    for (std::size_t indice = 0; indice < lectura.reglas.size(); ++indice) {
        formulas << "  R" << indice + 1 << ": " << lectura.reglas[indice].textoOriginal
                 << " → " << mostrarFormula(lectura.reglas[indice].formula) << '\n';
    }
    std::ostringstream arbolTexto;
    escribirNodo(arbolTexto, arbol.raiz);
    std::ostringstream resultados;
    resultados << "Ramas cerradas: " << arbol.ramasCerradas
               << "\nRamas abiertas: " << arbol.ramasAbiertas << '\n';
    if (arbol.ramasAbiertas == 0) {
        resultados << "\nLa base de conocimiento es inconsistente.\n";
    } else {
        resultados << "\nLa base de conocimiento es consistente.\n\nModelos:\n";
        for (const ModeloRama& modelo : arbol.modelos) {
            resultados << "  Rama " << modelo.idRama << ": ";
            for (std::size_t indice = 0; indice < modelo.valores.size(); ++indice) {
                if (indice != 0) resultados << ", ";
                resultados << modelo.valores[indice].letra << " = " << modelo.valores[indice].valor;
            }
            resultados << '\n';
        }
    }
    std::vector<Apartado> apartados = {
        {"Átomos identificados", atomos.str()},
        {"Fórmulas", formulas.str()},
        {"Árbol semántico", arbolTexto.str()},
        {"Resultados", resultados.str()}
    };
    agregarApartadosRamas(apartados, arbol.raiz);
    return apartados;
}

NSString* convertirNSString(const std::string& texto) {
    NSString* resultado = [[NSString alloc] initWithBytes:texto.data()
        length:texto.size() encoding:NSUTF8StringEncoding];
    return [resultado autorelease];
}
}

@interface ControladorVentana : NSObject <NSApplicationDelegate> {
    NSWindow* ventana_;
    NSTextView* textoEntrada_;
    NSTextView* textoSalida_;
    NSStackView* listaApartados_;
    NSScrollView* desplazamientoApartados_;
    std::vector<Apartado> apartados_;
}
- (void)analizar:(id)remitente;
- (void)cambiarApartado:(id)remitente;
- (void)mostrarApartado:(NSInteger)indice;
- (void)cargarEjemplo:(id)remitente;
- (void)limpiarEntrada:(id)remitente;
@end

@implementation ControladorVentana

- (void)applicationDidFinishLaunching:(NSNotification*)notificacion {
    (void)notificacion;
    [self crearMenu];
    [self crearVentana];
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication*)aplicacion {
    (void)aplicacion;
    return YES;
}

- (void)crearVentana {
    const NSRect marco = NSMakeRect(0, 0, 920, 760);
    ventana_ = [[NSWindow alloc] initWithContentRect:marco
        styleMask:(NSWindowStyleMaskTitled | NSWindowStyleMaskClosable | NSWindowStyleMaskMiniaturizable | NSWindowStyleMaskResizable)
        backing:NSBackingStoreBuffered defer:NO];
    [ventana_ setTitle:@"Árbol semántico"];
    [ventana_ center];
    [ventana_ setMinSize:NSMakeSize(680, 560)];

    NSView* contenido = [ventana_ contentView];
    [contenido setWantsLayer:YES];
    contenido.layer.backgroundColor = [NSColor colorWithRed:0.84 green:0.90 blue:0.98 alpha:1.0].CGColor;

    NSTextField* titulo = [NSTextField labelWithString:@"Motor de inferencia proposicional"];
    [titulo setFont:[NSFont systemFontOfSize:22 weight:NSFontWeightSemibold]];
    [titulo setTextColor:[NSColor colorWithRed:0.08 green:0.20 blue:0.39 alpha:1.0]];

    NSTextField* subtitulo = [NSTextField labelWithString:@"Una regla o un hecho por línea"];
    [subtitulo setFont:[NSFont systemFontOfSize:13]];
    [subtitulo setTextColor:[NSColor secondaryLabelColor]];

    NSTextField* etiquetaEntrada = [NSTextField labelWithString:@"Base de conocimiento"];
    [etiquetaEntrada setFont:[NSFont systemFontOfSize:13 weight:NSFontWeightMedium]];

    textoEntrada_ = [[NSTextView alloc] initWithFrame:NSMakeRect(0, 0, 860, 150)];
    [textoEntrada_ setFont:[NSFont monospacedSystemFontOfSize:13 weight:NSFontWeightRegular]];
    [textoEntrada_ setString:convertirNSString(ejemploVentana)];
    [textoEntrada_ setAutomaticQuoteSubstitutionEnabled:NO];
    [textoEntrada_ setRichText:NO];
    [textoEntrada_ setEditable:YES];
    [textoEntrada_ setSelectable:YES];
    [textoEntrada_ setTextColor:[NSColor colorWithRed:0.10 green:0.19 blue:0.31 alpha:1.0]];
    [textoEntrada_ setBackgroundColor:[NSColor colorWithRed:0.96 green:0.98 blue:1.00 alpha:1.0]];
    [textoEntrada_ setVerticallyResizable:YES];
    [textoEntrada_ setHorizontallyResizable:NO];
    [textoEntrada_ setAutoresizingMask:NSViewWidthSizable];
    [[textoEntrada_ textContainer] setContainerSize:NSMakeSize(0, CGFLOAT_MAX)];
    [[textoEntrada_ textContainer] setWidthTracksTextView:YES];
    [textoEntrada_ setTextContainerInset:NSMakeSize(10, 10)];

    NSScrollView* desplazamientoEntrada = [[NSScrollView alloc] initWithFrame:NSMakeRect(0, 0, 860, 150)];
    [desplazamientoEntrada setBorderType:NSBezelBorder];
    [desplazamientoEntrada setHasVerticalScroller:YES];
    [desplazamientoEntrada setAutohidesScrollers:YES];
    [desplazamientoEntrada setDrawsBackground:YES];
    [desplazamientoEntrada setBackgroundColor:[NSColor colorWithRed:0.96 green:0.98 blue:1.00 alpha:1.0]];
    [desplazamientoEntrada setDocumentView:textoEntrada_];

    NSButton* boton = [NSButton buttonWithTitle:@"Analizar" target:self action:@selector(analizar:)];
    [boton setBezelStyle:NSBezelStyleRounded];
    [boton setContentTintColor:[NSColor colorWithRed:0.10 green:0.34 blue:0.68 alpha:1.0]];
    [boton setKeyEquivalent:@"\r"];
    [boton setKeyEquivalentModifierMask:NSEventModifierFlagCommand];
    NSButton* botonEjemplo = [NSButton buttonWithTitle:@"Cargar ejemplo" target:self action:@selector(cargarEjemplo:)];
    [botonEjemplo setBezelStyle:NSBezelStyleRounded];
    [botonEjemplo setContentTintColor:[NSColor colorWithRed:0.16 green:0.38 blue:0.65 alpha:1.0]];
    NSButton* botonLimpiar = [NSButton buttonWithTitle:@"Limpiar" target:self action:@selector(limpiarEntrada:)];
    [botonLimpiar setBezelStyle:NSBezelStyleRounded];
    [botonLimpiar setContentTintColor:[NSColor colorWithRed:0.28 green:0.43 blue:0.62 alpha:1.0]];

    NSTextField* etiquetaSalida = [NSTextField labelWithString:@"SECCIONES DEL ANÁLISIS"];
    [etiquetaSalida setFont:[NSFont systemFontOfSize:12 weight:NSFontWeightSemibold]];
    [etiquetaSalida setTextColor:[NSColor colorWithRed:0.12 green:0.27 blue:0.45 alpha:1.0]];
    listaApartados_ = [[NSStackView alloc] initWithFrame:NSMakeRect(0, 0, 202, 330)];
    [listaApartados_ setOrientation:NSUserInterfaceLayoutOrientationVertical];
    [listaApartados_ setAlignment:NSLayoutAttributeLeading];
    [listaApartados_ setSpacing:8];
    [listaApartados_ setDistribution:NSStackViewDistributionFill];

    textoSalida_ = [[NSTextView alloc] initWithFrame:NSMakeRect(0, 0, 860, 330)];
    [textoSalida_ setFont:[NSFont monospacedSystemFontOfSize:12 weight:NSFontWeightRegular]];
    [textoSalida_ setEditable:NO];
    [textoSalida_ setSelectable:YES];
    [textoSalida_ setTextColor:[NSColor colorWithRed:0.10 green:0.19 blue:0.31 alpha:1.0]];
    [textoSalida_ setBackgroundColor:[NSColor colorWithRed:0.96 green:0.98 blue:1.00 alpha:1.0]];
    [textoSalida_ setRichText:NO];
    [textoSalida_ setVerticallyResizable:YES];
    [textoSalida_ setHorizontallyResizable:NO];
    [textoSalida_ setAutoresizingMask:NSViewWidthSizable];
    [[textoSalida_ textContainer] setContainerSize:NSMakeSize(0, CGFLOAT_MAX)];
    [[textoSalida_ textContainer] setWidthTracksTextView:YES];
    [textoSalida_ setTextContainerInset:NSMakeSize(10, 10)];

    NSScrollView* desplazamientoSalida = [[NSScrollView alloc] initWithFrame:NSMakeRect(0, 0, 860, 330)];
    [desplazamientoSalida setBorderType:NSBezelBorder];
    [desplazamientoSalida setHasVerticalScroller:YES];
    [desplazamientoSalida setAutohidesScrollers:YES];
    [desplazamientoSalida setDrawsBackground:YES];
    [desplazamientoSalida setBackgroundColor:[NSColor colorWithRed:0.96 green:0.98 blue:1.00 alpha:1.0]];
    [desplazamientoSalida setDocumentView:textoSalida_];

    desplazamientoApartados_ = [[NSScrollView alloc] initWithFrame:NSMakeRect(0, 0, 190, 330)];
    [desplazamientoApartados_ setBorderType:NSBezelBorder];
    [desplazamientoApartados_ setHasVerticalScroller:YES];
    [desplazamientoApartados_ setAutohidesScrollers:YES];
    [desplazamientoApartados_ setDrawsBackground:YES];
    [desplazamientoApartados_ setBackgroundColor:[NSColor colorWithRed:0.91 green:0.95 blue:0.99 alpha:1.0]];
    [desplazamientoApartados_ setDocumentView:listaApartados_];

    NSArray* vistas = @[titulo, subtitulo, etiquetaEntrada, desplazamientoEntrada,
                        boton, botonEjemplo, botonLimpiar, etiquetaSalida,
                        desplazamientoApartados_, desplazamientoSalida];
    for (NSView* vista in vistas) {
        [vista setTranslatesAutoresizingMaskIntoConstraints:NO];
        [contenido addSubview:vista];
    }

    [NSLayoutConstraint activateConstraints:@[
        [titulo.leadingAnchor constraintEqualToAnchor:contenido.leadingAnchor constant:24],
        [titulo.trailingAnchor constraintLessThanOrEqualToAnchor:contenido.trailingAnchor constant:-24],
        [titulo.topAnchor constraintEqualToAnchor:contenido.topAnchor constant:20],
        [subtitulo.leadingAnchor constraintEqualToAnchor:titulo.leadingAnchor],
        [subtitulo.trailingAnchor constraintEqualToAnchor:titulo.trailingAnchor],
        [subtitulo.topAnchor constraintEqualToAnchor:titulo.bottomAnchor constant:4],
        [etiquetaEntrada.leadingAnchor constraintEqualToAnchor:titulo.leadingAnchor],
        [etiquetaEntrada.topAnchor constraintEqualToAnchor:subtitulo.bottomAnchor constant:18],
        [desplazamientoEntrada.leadingAnchor constraintEqualToAnchor:titulo.leadingAnchor],
        [desplazamientoEntrada.trailingAnchor constraintEqualToAnchor:contenido.trailingAnchor constant:-24],
        [desplazamientoEntrada.topAnchor constraintEqualToAnchor:etiquetaEntrada.bottomAnchor constant:7],
        [desplazamientoEntrada.heightAnchor constraintEqualToConstant:150],
        [boton.trailingAnchor constraintEqualToAnchor:desplazamientoEntrada.trailingAnchor],
        [boton.topAnchor constraintEqualToAnchor:desplazamientoEntrada.bottomAnchor constant:10],
        [botonEjemplo.trailingAnchor constraintEqualToAnchor:boton.leadingAnchor constant:-8],
        [botonEjemplo.centerYAnchor constraintEqualToAnchor:boton.centerYAnchor],
        [botonLimpiar.trailingAnchor constraintEqualToAnchor:botonEjemplo.leadingAnchor constant:-8],
        [botonLimpiar.centerYAnchor constraintEqualToAnchor:boton.centerYAnchor],
        [etiquetaSalida.leadingAnchor constraintEqualToAnchor:titulo.leadingAnchor],
        [etiquetaSalida.topAnchor constraintEqualToAnchor:boton.bottomAnchor constant:14],
        [desplazamientoApartados_.leadingAnchor constraintEqualToAnchor:titulo.leadingAnchor],
        [desplazamientoApartados_.topAnchor constraintEqualToAnchor:etiquetaSalida.bottomAnchor constant:7],
        [desplazamientoApartados_.widthAnchor constraintEqualToConstant:220],
        [desplazamientoApartados_.bottomAnchor constraintEqualToAnchor:contenido.bottomAnchor constant:-22],
        [desplazamientoSalida.leadingAnchor constraintEqualToAnchor:desplazamientoApartados_.trailingAnchor constant:12],
        [desplazamientoSalida.trailingAnchor constraintEqualToAnchor:desplazamientoEntrada.trailingAnchor],
        [desplazamientoSalida.topAnchor constraintEqualToAnchor:etiquetaSalida.bottomAnchor constant:7],
        [desplazamientoSalida.bottomAnchor constraintEqualToAnchor:contenido.bottomAnchor constant:-22]
    ]];

    [self analizar:nil];
    [ventana_ makeKeyAndOrderFront:nil];
    [NSApp activateIgnoringOtherApps:YES];
}

- (void)crearMenu {
    NSMenu* menuPrincipal = [[NSMenu alloc] initWithTitle:@"Árbol semántico"];
    NSMenuItem* itemAplicacion = [[NSMenuItem alloc] initWithTitle:@"" action:nil keyEquivalent:@""];
    [menuPrincipal addItem:itemAplicacion];
    NSMenu* menuAplicacion = [[NSMenu alloc] initWithTitle:@"Árbol semántico"];
    NSMenuItem* itemAcerca = [menuAplicacion addItemWithTitle:@"Acerca de Árbol semántico"
        action:@selector(orderFrontStandardAboutPanel:) keyEquivalent:@""];
    [itemAcerca setTarget:NSApp];
    [menuAplicacion addItem:[NSMenuItem separatorItem]];
    NSMenuItem* itemSalirAplicacion = [menuAplicacion addItemWithTitle:@"Salir de Árbol semántico"
        action:@selector(terminate:) keyEquivalent:@"q"];
    [itemSalirAplicacion setTarget:NSApp];
    [itemAplicacion setSubmenu:menuAplicacion];

    NSMenuItem* itemArchivo = [[NSMenuItem alloc] initWithTitle:@"Archivo" action:nil keyEquivalent:@""];
    [menuPrincipal addItem:itemArchivo];
    NSMenu* menuArchivo = [[NSMenu alloc] initWithTitle:@"Archivo"];
    NSMenuItem* itemAnalizar = [menuArchivo addItemWithTitle:@"Analizar"
        action:@selector(analizar:) keyEquivalent:@"r"];
    [itemAnalizar setTarget:self];
    [itemAnalizar setKeyEquivalentModifierMask:NSEventModifierFlagCommand];
    NSMenuItem* itemCargar = [menuArchivo addItemWithTitle:@"Cargar ejemplo"
        action:@selector(cargarEjemplo:) keyEquivalent:@""];
    [itemCargar setTarget:self];
    NSMenuItem* itemLimpiar = [menuArchivo addItemWithTitle:@"Limpiar entrada"
        action:@selector(limpiarEntrada:) keyEquivalent:@""];
    [itemLimpiar setTarget:self];
    [menuArchivo addItem:[NSMenuItem separatorItem]];
    NSMenuItem* itemSalir = [menuArchivo addItemWithTitle:@"Salir" action:@selector(terminate:) keyEquivalent:@"q"];
    [itemSalir setTarget:NSApp];
    [itemArchivo setSubmenu:menuArchivo];
    [NSApp setMainMenu:menuPrincipal];
}

- (void)cargarEjemplo:(id)remitente {
    (void)remitente;
    [textoEntrada_ setString:convertirNSString(ejemploVentana)];
    [textoEntrada_ setSelectedRange:NSMakeRange(0, 0)];
    [self analizar:nil];
    [ventana_ makeKeyAndOrderFront:nil];
}

- (void)limpiarEntrada:(id)remitente {
    (void)remitente;
    [textoEntrada_ setString:@""];
    [textoSalida_ setString:@"Escribe una regla o un hecho por línea y pulsa Analizar."];
    apartados_.clear();
    NSArray* botones = [[listaApartados_ arrangedSubviews] copy];
    for (NSView* vista in botones) [listaApartados_ removeArrangedSubview:vista];
    for (NSView* vista in botones) [vista removeFromSuperview];
    [botones release];
    NSButton* aviso = [NSButton buttonWithTitle:@"Analiza para ver apartados" target:nil action:nil];
    [aviso setBezelStyle:NSBezelStyleRounded];
    [aviso setFont:[NSFont systemFontOfSize:12 weight:NSFontWeightMedium]];
    [aviso.widthAnchor constraintEqualToConstant:202].active = YES;
    [aviso.heightAnchor constraintEqualToConstant:36].active = YES;
    [aviso setEnabled:NO];
    [listaApartados_ addArrangedSubview:aviso];
    [ventana_ makeFirstResponder:textoEntrada_];
}

- (void)analizar:(id)remitente {
    (void)remitente;
    const char* entradaUTF8 = [[textoEntrada_ string] UTF8String];
    const std::string reglas = entradaUTF8 ? entradaUTF8 : "";
    apartados_ = crearApartados(reglas);
    NSArray* botones = [[listaApartados_ arrangedSubviews] copy];
    for (NSView* vista in botones) [listaApartados_ removeArrangedSubview:vista];
    for (NSView* vista in botones) [vista removeFromSuperview];
    [botones release];
    NSInteger indice = 0;
    for (const Apartado& apartado : apartados_) {
        NSButton* botonApartado = [NSButton buttonWithTitle:convertirNSString(apartado.first)
            target:self action:@selector(cambiarApartado:)];
        [botonApartado setTag:indice++];
        [botonApartado setButtonType:NSButtonTypePushOnPushOff];
        [botonApartado setBezelStyle:NSBezelStyleRounded];
        [botonApartado setControlSize:NSControlSizeRegular];
        [botonApartado setFont:[NSFont systemFontOfSize:12 weight:NSFontWeightMedium]];
        [botonApartado setContentTintColor:[NSColor colorWithRed:0.12 green:0.32 blue:0.58 alpha:1.0]];
        [botonApartado setAlignment:NSTextAlignmentLeft];
        [botonApartado.widthAnchor constraintEqualToConstant:202].active = YES;
        [botonApartado.heightAnchor constraintEqualToConstant:36].active = YES;
        [listaApartados_ addArrangedSubview:botonApartado];
    }
    const CGFloat altoLista = std::max<CGFloat>(330, static_cast<CGFloat>(apartados_.size()) * 44 + 16);
    [listaApartados_ setFrameSize:NSMakeSize(202, altoLista)];
    NSButton* primerBoton = (NSButton*)[[listaApartados_ arrangedSubviews] firstObject];
    [primerBoton setState:NSControlStateValueOn];
    [self mostrarApartado:0];
}

- (void)cambiarApartado:(id)remitente {
    const NSInteger indice = [remitente tag];
    for (NSView* vista in [listaApartados_ arrangedSubviews]) {
        if ([vista isKindOfClass:[NSButton class]]) {
            [(NSButton*)vista setState:vista == remitente ? NSControlStateValueOn : NSControlStateValueOff];
        }
    }
    [self mostrarApartado:indice];
}

- (void)mostrarApartado:(NSInteger)indice {
    if (indice < 0 || static_cast<std::size_t>(indice) >= apartados_.size()) return;
    [textoSalida_ setString:convertirNSString(apartados_[static_cast<std::size_t>(indice)].second)];
    [textoSalida_ scrollRangeToVisible:NSMakeRange(0, 0)];
}
@end

int ejecutarVentanaMac() {
    [NSApplication sharedApplication];
    [NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];
    ControladorVentana* controlador = [[ControladorVentana alloc] init];
    [NSApp setDelegate:controlador];
    [NSApp run];
    [controlador release];
    return 0;
}
