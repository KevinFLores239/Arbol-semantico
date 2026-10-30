#import <AppKit/AppKit.h>

#include "LectorReglas.hpp"
#include "MotorArbol.hpp"

#include <sstream>
#include <string>

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

std::string crearReporte(const std::string& entrada) {
    LectorReglas lector;
    const ResultadoLectura lectura = lector.analizar(entrada);
    if (!lectura.correcto) return lectura.error;

    MotorArbol motor;
    const ResultadoArbol arbol = motor.construir(lectura);
    std::ostringstream reporte;
    reporte << "ÁTOMOS\n";
    for (const AtomoRegistrado& atomo : lectura.atomos) {
        reporte << "  " << atomo.letra << " = " << atomo.significado << '\n';
    }
    reporte << "\nFÓRMULAS\n";
    for (std::size_t indice = 0; indice < lectura.reglas.size(); ++indice) {
        reporte << "  R" << indice + 1 << ": " << lectura.reglas[indice].textoOriginal
                << " → " << mostrarFormula(lectura.reglas[indice].formula) << '\n';
    }
    reporte << "\nÁRBOL SEMÁNTICO\n";
    escribirNodo(reporte, arbol.raiz);
    reporte << "\nRESULTADOS\n  Ramas cerradas: " << arbol.ramasCerradas
            << "\n  Ramas abiertas: " << arbol.ramasAbiertas << '\n';
    if (arbol.ramasAbiertas == 0) {
        reporte << "  La base de conocimiento es inconsistente.\n";
    } else {
        reporte << "  La base de conocimiento es consistente.\n  Modelos:\n";
        for (const ModeloRama& modelo : arbol.modelos) {
            reporte << "    Rama " << modelo.idRama << ": ";
            for (std::size_t indice = 0; indice < modelo.valores.size(); ++indice) {
                if (indice != 0) reporte << ", ";
                reporte << modelo.valores[indice].letra << " = " << modelo.valores[indice].valor;
            }
            reporte << '\n';
        }
    }
    return reporte.str();
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
}
- (void)analizar:(id)remitente;
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
    contenido.layer.backgroundColor = [NSColor colorWithRed:0.96 green:0.97 blue:0.96 alpha:1.0].CGColor;

    NSTextField* titulo = [NSTextField labelWithString:@"Motor de inferencia proposicional"];
    [titulo setFont:[NSFont systemFontOfSize:22 weight:NSFontWeightSemibold]];
    [titulo setTextColor:[NSColor colorWithRed:0.10 green:0.28 blue:0.31 alpha:1.0]];

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
    [desplazamientoEntrada setDocumentView:textoEntrada_];

    NSButton* boton = [NSButton buttonWithTitle:@"Analizar" target:self action:@selector(analizar:)];
    [boton setBezelStyle:NSBezelStyleRounded];
    [boton setKeyEquivalent:@"\r"];
    [boton setKeyEquivalentModifierMask:NSEventModifierFlagCommand];
    NSButton* botonEjemplo = [NSButton buttonWithTitle:@"Cargar ejemplo" target:self action:@selector(cargarEjemplo:)];
    [botonEjemplo setBezelStyle:NSBezelStyleRounded];
    NSButton* botonLimpiar = [NSButton buttonWithTitle:@"Limpiar" target:self action:@selector(limpiarEntrada:)];
    [botonLimpiar setBezelStyle:NSBezelStyleRounded];

    NSTextField* etiquetaSalida = [NSTextField labelWithString:@"Análisis y árbol semántico"];
    [etiquetaSalida setFont:[NSFont systemFontOfSize:13 weight:NSFontWeightMedium]];

    textoSalida_ = [[NSTextView alloc] initWithFrame:NSMakeRect(0, 0, 860, 330)];
    [textoSalida_ setFont:[NSFont monospacedSystemFontOfSize:12 weight:NSFontWeightRegular]];
    [textoSalida_ setEditable:NO];
    [textoSalida_ setSelectable:YES];
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
    [desplazamientoSalida setDocumentView:textoSalida_];

    NSArray* vistas = @[titulo, subtitulo, etiquetaEntrada, desplazamientoEntrada,
                        boton, botonEjemplo, botonLimpiar, etiquetaSalida, desplazamientoSalida];
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
        [desplazamientoSalida.leadingAnchor constraintEqualToAnchor:titulo.leadingAnchor],
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
    [ventana_ makeFirstResponder:textoEntrada_];
}

- (void)analizar:(id)remitente {
    (void)remitente;
    const char* entradaUTF8 = [[textoEntrada_ string] UTF8String];
    const std::string reglas = entradaUTF8 ? entradaUTF8 : "";
    const std::string reporte = crearReporte(reglas);
    [textoSalida_ setString:convertirNSString(reporte)];
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
