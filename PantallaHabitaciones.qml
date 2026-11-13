import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import NexStay

// Lista de todas las habitaciones con su estado y, si estan ocupadas,
// el huesped de la reserva de hoy. Solo consulta: los datos salen de
// ListaHabitaciones (C++) y aqui se filtran por estado.
Item {
    id: vista

    property color colorFondo: Tema.fondo
    property color colorTarjeta: Tema.tarjeta
    property color colorBorde: Tema.borde
    property color colorDorado: Tema.primario
    property color colorTextoSecundario: Tema.textoSecundario
    property color colorTextoClaro: Tema.texto
    property color colorExito: Tema.exito
    property color colorError: Tema.error
    property color colorAviso: Tema.aviso
    property color colorNeutro: Tema.neutro

    ListaHabitaciones {
        id: lista
    }

    property bool autorizado: false
    property var todas: []
    property string filtro: "" // "" = todas
    readonly property var estados: ["libre", "ocupada", "reservada", "en limpieza", "fuera de servicio"]
    readonly property var filtradas: filtro === "" ? todas : todas.filter(h => h.estado === filtro)

    function actualizar() {
        autorizado = lista.puedeVer()
        todas = autorizado ? lista.habitaciones() : []
    }

    Component.onCompleted: actualizar()

    function cuantas(estado) {
        return estado === "" ? todas.length : todas.filter(h => h.estado === estado).length
    }
    function colorEstado(estado) {
        switch (estado) {
        case "libre": return colorExito
        case "ocupada": return colorDorado
        case "reservada": return colorNeutro
        case "en limpieza": return colorAviso
        default: return colorError // fuera de servicio
        }
    }

    Rectangle {
        anchors.fill: parent
        color: vista.colorFondo

        // --- Sin permiso ---
        ColumnLayout {
            visible: !vista.autorizado
            anchors.centerIn: parent
            width: Math.min(parent.width - 48, 360)
            spacing: 10
            Label {
                text: qsTr("Acceso restringido")
                color: vista.colorDorado
                font.pixelSize: 18
                font.weight: Font.Medium
                Layout.alignment: Qt.AlignHCenter
            }
            Label {
                text: qsTr("Tu rol no tiene permiso para ver las habitaciones.")
                color: vista.colorTextoSecundario
                font.pixelSize: 13
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignHCenter
                Layout.fillWidth: true
            }
        }

        // --- Lista ---
        ColumnLayout {
            visible: vista.autorizado
            x: Math.max(18, (parent.width - 560) / 2)
            y: 18
            width: Math.min(parent.width - 36, 560)
            height: parent.height - 18
            spacing: 10

            // Filtro por estado con su contador
            Flow {
                Layout.fillWidth: true
                spacing: 6
                Repeater {
                    model: [""].concat(vista.estados)
                    delegate: Rectangle {
                        required property string modelData
                        readonly property bool activo: vista.filtro === modelData
                        implicitWidth: textoFiltro.implicitWidth + 22
                        implicitHeight: 30
                        radius: 15
                        color: activo ? vista.colorDorado : "transparent"
                        border.width: activo ? 0 : 1
                        border.color: modelData === "" ? Tema.bordeFuerte : vista.colorEstado(modelData)
                        Label {
                            id: textoFiltro
                            anchors.centerIn: parent
                            text: (parent.modelData === "" ? qsTr("Todas") : parent.modelData)
                                  + ": " + vista.cuantas(parent.modelData)
                            color: parent.activo ? Tema.textoSobrePrimario
                                 : parent.modelData === "" ? vista.colorTextoClaro
                                 : vista.colorEstado(parent.modelData)
                            font.pixelSize: 12
                        }
                        MouseArea {
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            ResaltadoHover {}
                            anchors.fill: parent
                            onClicked: vista.filtro = parent.modelData
                        }
                    }
                }
                Label {
                    text: qsTr("Actualizar")
                    color: vista.colorDorado
                    font.pixelSize: 13
                    height: 30
                    verticalAlignment: Text.AlignVCenter
                    leftPadding: 8
                    MouseArea {
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        ResaltadoHover {}
                        anchors.fill: parent
                        anchors.margins: -6
                        onClicked: vista.actualizar()
                    }
                }
            }

            Label {
                visible: vista.filtradas.length === 0
                text: qsTr("No hay habitaciones con ese estado.")
                color: vista.colorTextoSecundario
                font.pixelSize: 13
            }

            ListView {
                id: listaVista
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: 6
                boundsBehavior: Flickable.StopAtBounds
                model: vista.filtradas

                section.property: "piso"
                section.delegate: Label {
                    required property string section
                    text: qsTr("Piso %1").arg(section)
                    color: vista.colorTextoSecundario
                    font.pixelSize: 13
                    topPadding: 8
                    bottomPadding: 2
                }

                delegate: Rectangle {
                    required property var modelData
                    width: ListView.view.width
                    implicitHeight: filas.implicitHeight + 20
                    radius: 10
                    color: vista.colorTarjeta
                    border.width: 1
                    border.color: vista.colorBorde

                    ColumnLayout {
                        id: filas
                        x: 14
                        y: 10
                        width: parent.width - 28
                        spacing: 2
                        RowLayout {
                            Layout.fillWidth: true
                            Label {
                                text: qsTr("Hab. %1").arg(modelData.numero)
                                color: vista.colorTextoClaro
                                font.pixelSize: 14
                                font.weight: Font.Medium
                            }
                            Label {
                                text: qsTr("%1 · %2 persona(s)").arg(modelData.tipo).arg(modelData.capacidad)
                                color: vista.colorTextoSecundario
                                font.pixelSize: 12
                                Layout.fillWidth: true
                            }
                            Label {
                                text: "● " + modelData.estado
                                color: vista.colorEstado(modelData.estado)
                                font.pixelSize: 12
                            }
                        }
                        Label {
                            visible: modelData.huesped.length > 0
                            text: qsTr("Huésped: %1 · sale el %2").arg(modelData.huesped).arg(modelData.salida)
                            color: vista.colorTextoSecundario
                            font.pixelSize: 12
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                    }
                }
            }
        }
    }
}
