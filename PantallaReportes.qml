import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import NexStay

// Theme 8: Reportes y vistas organizadas.
// Epic: dashboard de reportes en el perfil de administracion.
//
// Vista de solo lectura que junta en una sola pantalla lo que antes
// habia que revisar habitacion por habitacion: estado actual de las
// habitaciones, ocupacion del periodo, solicitudes y sus tiempos de
// atencion, habitaciones por limpiar e historial de mantenimiento.
// Todos los datos salen de la clase Reportes (C++); aqui solo se dibujan.
Item {
    id: vista

    property color colorFondo: "#0d0d0d"
    property color colorTarjeta: "#1a1a1a"
    property color colorBorde: "#2a2a2a"
    property color colorDorado: "#D4AF37"
    property color colorTextoSecundario: "#8a8a8a"
    property color colorTextoClaro: "#f2f2f2"
    property color colorExito: "#6fcf97"
    property color colorError: "#e05c5c"
    property color colorAviso: "#e0a85c"
    property color colorNeutro: "#6a9bd8"

    Reportes {
        id: reportes
    }

    property bool autorizado: false
    property int dias: 30
    property var habitaciones: ({ total: 0, porEstado: [] })
    property var ocupacion: ({ porcentaje: 0, nochesOcupadas: 0, nochesDisponibles: 0, reservasNuevas: 0, inicio: "", fin: "" })
    property var solicitudes: ({ total: 0, pendientes: 0, enProceso: 0, resueltas: 0, porTipo: [], activasPorPrioridad: [] })
    property var limpieza: []
    property var mantenimiento: []

    function actualizar() {
        autorizado = reportes.puedeVerReportes()
        if (!autorizado) {
            return
        }
        habitaciones = reportes.estadoHabitaciones()
        ocupacion = reportes.ocupacion(dias)
        solicitudes = reportes.resumenSolicitudes(dias)
        limpieza = reportes.pendientesLimpieza()
        mantenimiento = reportes.historialMantenimiento(20)
    }

    Component.onCompleted: actualizar()

    function colorEstado(estado) {
        switch (estado) {
        case "libre": return colorExito
        case "ocupada": return colorDorado
        case "reservada": return colorNeutro
        case "en limpieza": return colorAviso
        default: return colorError // fuera de servicio
        }
    }
    function colorPrioridad(prioridad) {
        if (prioridad === "alta") return colorError
        if (prioridad === "media") return colorAviso
        return colorNeutro
    }
    // Minutos a texto corto: "-" sin datos, "45 min" o "2 h 10 min".
    function tiempo(minutos) {
        if (minutos < 0) return qsTr("sin datos")
        if (minutos < 60) return qsTr("%1 min").arg(minutos)
        const h = Math.floor(minutos / 60)
        const m = minutos % 60
        return m > 0 ? qsTr("%1 h %2 min").arg(h).arg(m) : qsTr("%1 h").arg(h)
    }

    // Tarjeta con titulo para cada seccion del dashboard.
    component Seccion: Rectangle {
        id: seccion
        property alias titulo: etiquetaTitulo.text
        default property alias contenido: columna.data
        Layout.fillWidth: true
        implicitHeight: columna.implicitHeight + 28
        radius: 10
        color: vista.colorTarjeta
        border.width: 1
        border.color: vista.colorBorde

        ColumnLayout {
            id: columna
            x: 14
            y: 14
            width: parent.width - 28
            spacing: 8

            Label {
                id: etiquetaTitulo
                color: vista.colorDorado
                font.pixelSize: 14
                font.weight: Font.Medium
            }
        }
    }

    // Numero grande con su descripcion abajo.
    component Indicador: ColumnLayout {
        property alias valor: etiquetaValor.text
        property alias descripcion: etiquetaDescripcion.text
        property color colorValor: vista.colorTextoClaro
        spacing: 0
        Layout.fillWidth: true
        Label {
            id: etiquetaValor
            color: parent.colorValor
            font.pixelSize: 22
            font.weight: Font.Medium
        }
        Label {
            id: etiquetaDescripcion
            color: vista.colorTextoSecundario
            font.pixelSize: 10
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
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
                text: qsTr("Tu rol no tiene permiso para ver los reportes.")
                color: vista.colorTextoSecundario
                font.pixelSize: 12
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignHCenter
                Layout.fillWidth: true
            }
        }

        // --- Dashboard ---
        Flickable {
            visible: vista.autorizado
            anchors.fill: parent
            contentHeight: contenido.implicitHeight + 36
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            ColumnLayout {
                id: contenido
                x: Math.max(18, (parent.width - 560) / 2)
                y: 18
                width: Math.min(parent.width - 36, 560)
                spacing: 12

                // Periodo y actualizar
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6
                    Label {
                        text: qsTr("Periodo:")
                        color: vista.colorTextoSecundario
                        font.pixelSize: 12
                    }
                    Repeater {
                        model: [7, 30, 90]
                        delegate: Rectangle {
                            required property int modelData
                            implicitWidth: 64
                            implicitHeight: 30
                            radius: 15
                            color: vista.dias === modelData ? vista.colorDorado : "transparent"
                            border.width: vista.dias === modelData ? 0 : 1
                            border.color: "#444444"
                            Label {
                                anchors.centerIn: parent
                                text: qsTr("%1 días").arg(parent.modelData)
                                color: vista.dias === parent.modelData ? "#1a1400" : vista.colorTextoClaro
                                font.pixelSize: 11
                            }
                            MouseArea {
                                anchors.fill: parent
                                onClicked: {
                                    vista.dias = parent.modelData
                                    vista.actualizar()
                                }
                            }
                        }
                    }
                    Item { Layout.fillWidth: true }
                    Label {
                        text: qsTr("Actualizar")
                        color: vista.colorDorado
                        font.pixelSize: 12
                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -8
                            onClicked: vista.actualizar()
                        }
                    }
                }

                // 1. Habitaciones ahorita
                Seccion {
                    titulo: qsTr("Habitaciones ahora (%1)").arg(vista.habitaciones.total)

                    Flow {
                        Layout.fillWidth: true
                        spacing: 8
                        Repeater {
                            model: vista.habitaciones.porEstado
                            delegate: Rectangle {
                                required property var modelData
                                implicitWidth: textoEstado.implicitWidth + 24
                                implicitHeight: 28
                                radius: 14
                                color: "transparent"
                                border.width: 1
                                border.color: vista.colorEstado(modelData.estado)
                                Label {
                                    id: textoEstado
                                    anchors.centerIn: parent
                                    text: modelData.estado + ": " + modelData.cantidad
                                    color: vista.colorEstado(parent.modelData.estado)
                                    font.pixelSize: 12
                                }
                            }
                        }
                    }
                }

                // 2. Ocupacion
                Seccion {
                    titulo: qsTr("Ocupación del %1 al %2").arg(vista.ocupacion.inicio).arg(vista.ocupacion.fin)

                    RowLayout {
                        Layout.fillWidth: true
                        Indicador {
                            valor: vista.ocupacion.porcentaje + "%"
                            colorValor: vista.colorDorado
                            descripcion: qsTr("de ocupación")
                        }
                        Indicador {
                            valor: vista.ocupacion.nochesOcupadas + " / " + vista.ocupacion.nochesDisponibles
                            descripcion: qsTr("noches ocupadas / disponibles")
                        }
                        Indicador {
                            valor: vista.ocupacion.reservasNuevas
                            descripcion: qsTr("reservas registradas")
                        }
                    }
                    // Barra de ocupacion
                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 8
                        radius: 4
                        color: vista.colorBorde
                        Rectangle {
                            width: parent.width * Math.min(vista.ocupacion.porcentaje, 100) / 100
                            height: parent.height
                            radius: 4
                            color: vista.colorDorado
                        }
                    }
                }

                // 3. Solicitudes
                Seccion {
                    titulo: qsTr("Solicitudes del periodo (%1)").arg(vista.solicitudes.total)

                    RowLayout {
                        Layout.fillWidth: true
                        Indicador { valor: vista.solicitudes.pendientes; colorValor: vista.colorError; descripcion: qsTr("pendientes") }
                        Indicador { valor: vista.solicitudes.enProceso; colorValor: vista.colorAviso; descripcion: qsTr("en proceso") }
                        Indicador { valor: vista.solicitudes.resueltas; colorValor: vista.colorExito; descripcion: qsTr("resueltas") }
                    }

                    Repeater {
                        model: vista.solicitudes.porTipo
                        delegate: RowLayout {
                            required property var modelData
                            Layout.fillWidth: true
                            Label {
                                text: modelData.tipo.charAt(0).toUpperCase() + modelData.tipo.slice(1)
                                      + " (" + modelData.resueltas + "/" + modelData.total + ")"
                                color: vista.colorTextoClaro
                                font.pixelSize: 12
                                Layout.fillWidth: true
                            }
                            Label {
                                text: qsTr("respuesta %1 · resolución %2")
                                        .arg(vista.tiempo(modelData.promedioRespuesta))
                                        .arg(vista.tiempo(modelData.promedioResolucion))
                                color: vista.colorTextoSecundario
                                font.pixelSize: 11
                            }
                        }
                    }

                    Label {
                        visible: vista.solicitudes.activasPorPrioridad.length > 0
                        text: qsTr("Activas por prioridad:")
                        color: vista.colorTextoSecundario
                        font.pixelSize: 11
                    }
                    Flow {
                        Layout.fillWidth: true
                        spacing: 8
                        Repeater {
                            model: vista.solicitudes.activasPorPrioridad
                            delegate: Label {
                                required property var modelData
                                text: "● " + modelData.prioridad + ": " + modelData.cantidad
                                color: vista.colorPrioridad(modelData.prioridad)
                                font.pixelSize: 12
                            }
                        }
                    }
                }

                // 4. Habitaciones por limpiar
                Seccion {
                    titulo: qsTr("Habitaciones pendientes de limpieza (%1)").arg(vista.limpieza.length)

                    Label {
                        visible: vista.limpieza.length === 0
                        text: qsTr("No hay habitaciones pendientes de limpieza.")
                        color: vista.colorTextoSecundario
                        font.pixelSize: 12
                    }
                    Repeater {
                        model: vista.limpieza
                        delegate: RowLayout {
                            required property var modelData
                            Layout.fillWidth: true
                            Label {
                                text: qsTr("Hab. %1 · piso %2").arg(modelData.numero).arg(modelData.piso)
                                color: vista.colorTextoClaro
                                font.pixelSize: 12
                                Layout.fillWidth: true
                            }
                            Label {
                                text: modelData.solicitudesAbiertas > 0
                                      ? qsTr("%1 solicitud(es) abierta(s)").arg(modelData.solicitudesAbiertas)
                                      : modelData.estadoActual
                                color: vista.colorAviso
                                font.pixelSize: 11
                            }
                        }
                    }
                }

                // 5. Historial de mantenimiento
                Seccion {
                    titulo: qsTr("Historial de mantenimiento")

                    Label {
                        visible: vista.mantenimiento.length === 0
                        text: qsTr("Todavía no hay mantenimientos resueltos.")
                        color: vista.colorTextoSecundario
                        font.pixelSize: 12
                    }
                    Repeater {
                        model: vista.mantenimiento
                        delegate: ColumnLayout {
                            required property var modelData
                            Layout.fillWidth: true
                            spacing: 1
                            RowLayout {
                                Layout.fillWidth: true
                                Label {
                                    text: qsTr("Hab. %1").arg(modelData.numero)
                                          + (modelData.descripcion.length > 0 ? " · " + modelData.descripcion : "")
                                    color: vista.colorTextoClaro
                                    font.pixelSize: 12
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                                Label {
                                    text: "● " + modelData.prioridad
                                    color: vista.colorPrioridad(modelData.prioridad)
                                    font.pixelSize: 11
                                }
                            }
                            Label {
                                text: qsTr("%1 · respuesta %2 · resolución %3%4")
                                        .arg(modelData.fechaResolucion)
                                        .arg(vista.tiempo(modelData.minutosRespuesta))
                                        .arg(vista.tiempo(modelData.minutosResolucion))
                                        .arg(modelData.responsable.length > 0 ? " · " + modelData.responsable : "")
                                color: vista.colorTextoSecundario
                                font.pixelSize: 10
                                wrapMode: Text.WordWrap
                                Layout.fillWidth: true
                            }
                        }
                    }
                }
            }
        }
    }
}
