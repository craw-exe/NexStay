pragma Singleton
import QtQuick

// Paleta y medidas de toda la app (rediseño de interfaz, revisión 11/nov).
// Antes cada pantalla tenía sus propios colores escritos a mano; ahora
// todas leen de aquí, así que para cambiar un color basta con cambiarlo
// en este archivo.
QtObject {
    // Fondos
    readonly property color fondo: "#F3F6FB"
    readonly property color tarjeta: "#FFFFFF"
    readonly property color campo: "#FFFFFF"
    readonly property color suave: "#EEF2F8"
    readonly property color barraLateral: "#14284B"

    // Bordes
    readonly property color borde: "#E2E8F0"
    readonly property color bordeFuerte: "#CBD5E1"

    // Texto
    readonly property color texto: "#1E293B"
    readonly property color textoSecundario: "#64748B"
    readonly property color placeholder: "#94A3B8"
    readonly property color textoSobrePrimario: "#FFFFFF"

    // Color principal (botones, títulos, selección) y acento de marca
    readonly property color primario: "#2563EB"
    readonly property color primarioOscuro: "#1D4ED8"
    readonly property color primarioSuave: "#E0EAFF"
    readonly property color dorado: "#E3B341"

    // Estados
    readonly property color exito: "#16A34A"
    readonly property color exitoSuave: "#DCFCE7"
    readonly property color error: "#DC2626"
    readonly property color errorSuave: "#FEE2E2"
    readonly property color aviso: "#D97706"
    readonly property color avisoSuave: "#FEF3C7"
    readonly property color neutro: "#0EA5E9"
    readonly property color neutroSuave: "#E0F2FE"
    readonly property color morado: "#7C3AED"
    readonly property color moradoSuave: "#EDE9FE"
    readonly property color rosa: "#DB2777"
    readonly property color rosaSuave: "#FCE7F3"

    // Fuente para los íconos (emoji a color en Windows)
    readonly property string fuenteIconos: "Segoe UI Emoji"

    // Medidas
    readonly property int radio: 12
    readonly property int radioGrande: 18
    readonly property int alturaBoton: 46
    readonly property int anchoCelular: 600
}
