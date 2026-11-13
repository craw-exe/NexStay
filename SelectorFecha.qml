import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import NexStay

// Theme 11: calendario de un mes para elegir una fecha sin tener que
// avanzar dia por dia. Flechas ‹ › cambian de mes y « » de año.
// Uso: selector.abrir("2026-11-12"); la fecha elegida llega por
// elegida(fecha) en formato "yyyy-MM-dd". "minima" (opcional) bloquea
// los dias anteriores.
Popup {
    id: selector
    property string fecha: ""
    property string minima: ""
    property int anio: 2026
    property int mes: 0            // 0 = enero
    signal elegida(string fecha)

    modal: true
    focus: true
    anchors.centerIn: Overlay.overlay
    width: 344
    padding: 18

    background: Rectangle {
        color: Tema.tarjeta
        radius: Tema.radioGrande
        border.width: 1
        border.color: Tema.borde
    }

    function dosDigitos(n) { return n < 10 ? "0" + n : "" + n }
    function texto(d) {
        return d.getFullYear() + "-" + dosDigitos(d.getMonth() + 1) + "-" + dosDigitos(d.getDate())
    }
    function abrir(f) {
        fecha = f
        const p = f.split("-")
        anio = Number(p[0])
        mes = Number(p[1]) - 1
        open()
    }
    function mover(meses) {
        const total = anio * 12 + mes + meses
        anio = Math.floor(total / 12)
        mes = total - anio * 12
    }
    function elegir(f) {
        selector.elegida(f)
        selector.close()
    }

    readonly property string hoy: texto(new Date())
    // Celdas del mes: vacias hasta el primer dia (semana inicia en lunes).
    readonly property var celdas: {
        const primero = new Date(anio, mes, 1)
        const hueco = (primero.getDay() + 6) % 7
        const dias = new Date(anio, mes + 1, 0).getDate()
        const lista = []
        for (let i = 0; i < hueco; i++) lista.push("")
        for (let d = 1; d <= dias; d++) lista.push(texto(new Date(anio, mes, d)))
        return lista
    }

    component Flecha: Rectangle {
        id: flecha
        property string simbolo
        signal pulsado()
        width: 36; height: 36; radius: 18
        color: areaFlecha.containsMouse ? Tema.primarioSuave : "transparent"
        Label {
            anchors.centerIn: parent
            text: flecha.simbolo
            color: Tema.primario
            font.pixelSize: 18
            font.weight: Font.Bold
        }
        MouseArea {
            id: areaFlecha
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: flecha.pulsado()
        }
    }

    contentItem: ColumnLayout {
        spacing: 10

        RowLayout {
            Layout.fillWidth: true
            spacing: 2
            Flecha { simbolo: "«"; onPulsado: selector.mover(-12) }
            Flecha { simbolo: "‹"; onPulsado: selector.mover(-1) }
            Label {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                text: {
                    const m = Qt.locale("es_MX").standaloneMonthName(selector.mes)
                    return m.charAt(0).toUpperCase() + m.slice(1) + " " + selector.anio
                }
                color: Tema.texto
                font.pixelSize: 16
                font.weight: Font.Bold
            }
            Flecha { simbolo: "›"; onPulsado: selector.mover(1) }
            Flecha { simbolo: "»"; onPulsado: selector.mover(12) }
        }

        GridLayout {
            Layout.alignment: Qt.AlignHCenter
            columns: 7
            rowSpacing: 4
            columnSpacing: 4

            Repeater {
                model: ["L", "M", "M", "J", "V", "S", "D"]
                delegate: Label {
                    required property string modelData
                    Layout.preferredWidth: 40
                    horizontalAlignment: Text.AlignHCenter
                    text: modelData
                    color: Tema.textoSecundario
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                }
            }
            Repeater {
                model: selector.celdas
                delegate: Rectangle {
                    id: dia
                    required property string modelData
                    readonly property bool vacia: modelData === ""
                    readonly property bool bloqueada: vacia
                        || (selector.minima !== "" && modelData < selector.minima)
                    readonly property bool elegidaAhora: modelData === selector.fecha
                    Layout.preferredWidth: 40
                    Layout.preferredHeight: 40
                    radius: 20
                    color: elegidaAhora ? Tema.primario
                           : (areaDia.containsMouse && !bloqueada ? Tema.primarioSuave : "transparent")
                    border.width: !elegidaAhora && modelData === selector.hoy ? 1 : 0
                    border.color: Tema.primario
                    Label {
                        anchors.centerIn: parent
                        visible: !dia.vacia
                        text: dia.vacia ? "" : Number(dia.modelData.split("-")[2])
                        color: dia.elegidaAhora ? Tema.textoSobrePrimario
                               : (dia.bloqueada ? Tema.placeholder : Tema.texto)
                        font.pixelSize: 14
                        font.weight: dia.elegidaAhora ? Font.Bold : Font.Normal
                    }
                    MouseArea {
                        id: areaDia
                        anchors.fill: parent
                        enabled: !dia.bloqueada
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: selector.elegir(dia.modelData)
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            BotonApp {
                text: qsTr("Hoy")
                onClicked: selector.elegir(selector.hoy)
            }
            Item { Layout.fillWidth: true }
            BotonApp {
                text: qsTr("Cancelar")
                onClicked: selector.close()
            }
        }
    }
}
