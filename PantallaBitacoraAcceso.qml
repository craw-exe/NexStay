import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import NexStay

// Theme 4, Task 4: "Registrar bitacora de accesos".
//
// El registro ya pasa solo (Task 3, ControlAcceso): esta pantalla es el
// lado de LECTURA, para que el administrador/recepcion pueda auditar
// quien entro (o intento entrar sin permiso) a cada habitacion.
//
// Pantalla de prueba independiente, igual que PantallaCalendarioReservas:
// se abre cambiando temporalmente el segundo argumento de
// engine.loadFromModule() en main.cpp a "PantallaBitacoraAcceso". La
// navegacion real (a que pantalla llega cada rol al iniciar sesion) es
// trabajo de Theme 7, no de esta pantalla.
ApplicationWindow {
    id: window
    width: 480
    height: 720
    minimumWidth: 340
    minimumHeight: 480
    visible: true
    title: qsTr("NexStay - Bitácora de accesos")

    property color colorFondo: "#0d0d0d"
    property color colorTarjeta: "#1a1a1a"
    property color colorBorde: "#2a2a2a"
    property color colorDorado: "#D4AF37"
    property color colorTextoSecundario: "#8a8a8a"
    property color colorTextoClaro: "#f2f2f2"
    property color colorExito: "#6fcf97"
    property color colorError: "#e05c5c"
    property color colorNeutro: "#6a9bd8"

    BitacoraAcceso {
        id: bitacora
    }

    // Se revisa el permiso apenas se abre la pantalla. Como esta
    // pantalla todavia se prueba de forma independiente (sin pasar por
    // el login de Theme 4 primero), conviene iniciar sesion en
    // PantallaLogin.qml antes de abrir esta, para que haya una fila en
    // Sesion_Actual que revisar.
    property bool autorizado: false
    property var listaRegistros: []

    function actualizar() {
        autorizado = bitacora.puedeVerBitacora()
        listaRegistros = autorizado ? bitacora.registros() : []
    }

    Component.onCompleted: actualizar()

    // Traduce tipo_evento a una etiqueta y color legibles.
    function etiquetaEvento(tipoEvento) {
        if (tipoEvento === "entrada") return qsTr("Entrada concedida")
        if (tipoEvento === "salida") return qsTr("Salida")
        return qsTr("Intento fallido")
    }
    function colorEvento(tipoEvento) {
        if (tipoEvento === "entrada") return window.colorExito
        if (tipoEvento === "salida") return window.colorNeutro
        return window.colorError
    }

    Rectangle {
        anchors.fill: parent
        color: window.colorFondo

        // --- Caso: no autorizado (o sin sesion) ---
        ColumnLayout {
            visible: !window.autorizado
            anchors.centerIn: parent
            width: Math.min(parent.width - 48, 360)
            spacing: 10

            Label {
                text: qsTr("Acceso restringido")
                color: window.colorDorado
                font.pixelSize: 18
                font.weight: Font.Medium
                Layout.alignment: Qt.AlignHCenter
            }
            Label {
                text: qsTr("Solo el rol de administración puede ver la bitácora de accesos. Inicia sesión con una cuenta de administrador en la pantalla de login y vuelve a abrir esta vista.")
                color: window.colorTextoSecundario
                font.pixelSize: 12
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignHCenter
                Layout.fillWidth: true
            }
            Button {
                Layout.topMargin: 10
                Layout.alignment: Qt.AlignHCenter
                text: qsTr("Reintentar")
                contentItem: Text {
                    text: parent.text
                    color: window.colorTextoClaro
                    font.pixelSize: 13
                    horizontalAlignment: Text.AlignHCenter
                }
                background: Rectangle {
                    color: "transparent"
                    radius: 8
                    border.width: 1
                    border.color: "#444444"
                    implicitWidth: 140
                    implicitHeight: 38
                }
                onClicked: window.actualizar()
            }
        }

        // --- Caso: autorizado ---
        ColumnLayout {
            visible: window.autorizado
            anchors.fill: parent
            anchors.margins: 20
            spacing: 12

            RowLayout {
                Layout.fillWidth: true

                ColumnLayout {
                    spacing: 2
                    Label {
                        text: qsTr("Bitácora de accesos")
                        color: window.colorDorado
                        font.pixelSize: 18
                        font.weight: Font.Medium
                    }
                    Label {
                        text: qsTr("Últimos %1 registros, de todas las habitaciones").arg(window.listaRegistros.length)
                        color: window.colorTextoSecundario
                        font.pixelSize: 11
                    }
                }

                Item { Layout.fillWidth: true }

                Button {
                    text: qsTr("Actualizar")
                    contentItem: Text {
                        text: parent.text
                        color: window.colorTextoClaro
                        font.pixelSize: 12
                        horizontalAlignment: Text.AlignHCenter
                    }
                    background: Rectangle {
                        color: "transparent"
                        radius: 8
                        border.width: 1
                        border.color: "#444444"
                        implicitWidth: 90
                        implicitHeight: 34
                    }
                    onClicked: window.actualizar()
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: window.colorBorde
            }

            Label {
                visible: window.listaRegistros.length === 0
                text: qsTr("Todavía no hay registros en la bitácora.")
                color: window.colorTextoSecundario
                font.pixelSize: 12
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 24
            }

            ListView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: window.listaRegistros.length > 0
                clip: true
                spacing: 8
                model: window.listaRegistros

                delegate: Rectangle {
                    width: ListView.view ? ListView.view.width : 0
                    height: filaContenido.implicitHeight + 24
                    radius: 10
                    color: window.colorTarjeta
                    border.width: 1
                    border.color: window.colorBorde

                    RowLayout {
                        id: filaContenido
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 12

                        Rectangle {
                            width: 8
                            height: 8
                            radius: 4
                            color: window.colorEvento(modelData.tipoEvento)
                            Layout.alignment: Qt.AlignTop
                            Layout.topMargin: 4
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 3

                            RowLayout {
                                Layout.fillWidth: true
                                Label {
                                    text: window.etiquetaEvento(modelData.tipoEvento)
                                    color: window.colorEvento(modelData.tipoEvento)
                                    font.pixelSize: 13
                                    font.weight: Font.Medium
                                }
                                Item { Layout.fillWidth: true }
                                Label {
                                    text: qsTr("Hab. %1").arg(modelData.numeroHabitacion)
                                    color: window.colorDorado
                                    font.pixelSize: 12
                                }
                            }

                            Label {
                                text: modelData.actor + " · " + modelData.rolUsado
                                color: window.colorTextoClaro
                                font.pixelSize: 12
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                            }

                            Label {
                                text: modelData.fechaHora
                                color: window.colorTextoSecundario
                                font.pixelSize: 10
                            }
                        }
                    }
                }
            }
        }
    }
}
