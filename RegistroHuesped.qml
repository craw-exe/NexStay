import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts

// Theme 3, Task 1: formulario de registro de huésped.
// Por ahora es solo la interfaz (Opción B: dos columnas) con
// validación básica de campos obligatorios. Todavía NO guarda en la
// base de datos: eso se conectará en el task de "lógica de
// validación de disponibilidad" / registro, junto con la tabla
// Huesped (nombre, apellido, documento_identidad, telefono, correo).
ApplicationWindow {
    id: window
    width: 480
    height: 620
    minimumWidth: 420
    minimumHeight: 560
    visible: true
    title: qsTr("NexStay - Registrar huésped")

    // Paleta NexStay (misma que el resto de la app)
    property color colorFondo: "#0d0d0d"
    property color colorCampo: "#1a1a1a"
    property color colorBorde: "#333333"
    property color colorDorado: "#D4AF37"
    property color colorTextoSecundario: "#8a8a8a"
    property color colorTextoClaro: "#f2f2f2"
    property color colorError: "#e05c5c"

    // Campos obligatorios según la tabla Huesped (todos NOT NULL).
    // Se habilita "Registrar" solo cuando los 5 tienen contenido.
    property bool formularioValido: campoNombre.text.trim().length > 0
                                     && campoApellido.text.trim().length > 0
                                     && campoDocumento.text.trim().length > 0
                                     && campoTelefono.text.trim().length > 0
                                     && campoCorreo.text.trim().length > 0

    function limpiarFormulario() {
        campoNombre.text = ""
        campoApellido.text = ""
        campoDocumento.text = ""
        campoTelefono.text = ""
        campoCorreo.text = ""
    }

    Rectangle {
        anchors.fill: parent
        color: window.colorFondo

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 24
            spacing: 4

            Label {
                text: qsTr("Registrar huésped")
                color: window.colorDorado
                font.pixelSize: 18
                font.weight: Font.Medium
            }
            Label {
                text: qsTr("Datos del titular de la reserva")
                color: window.colorTextoSecundario
                font.pixelSize: 12
                Layout.bottomMargin: 18
            }

            // Fila 1: Nombre / Apellido
            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 5
                    Label { text: qsTr("Nombre"); color: window.colorTextoSecundario; font.pixelSize: 11 }
                    TextField {
                        id: campoNombre
                        Layout.fillWidth: true
                        placeholderText: qsTr("María")
                        color: window.colorTextoClaro
                        placeholderTextColor: "#555555"
                        background: Rectangle {
                            color: window.colorCampo
                            radius: 8
                            border.width: 1
                            border.color: window.colorBorde
                        }
                        leftPadding: 12
                        rightPadding: 12
                        topPadding: 11
                        bottomPadding: 11
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 5
                    Label { text: qsTr("Apellido"); color: window.colorTextoSecundario; font.pixelSize: 11 }
                    TextField {
                        id: campoApellido
                        Layout.fillWidth: true
                        placeholderText: qsTr("Torres")
                        color: window.colorTextoClaro
                        placeholderTextColor: "#555555"
                        background: Rectangle {
                            color: window.colorCampo
                            radius: 8
                            border.width: 1
                            border.color: window.colorBorde
                        }
                        leftPadding: 12
                        rightPadding: 12
                        topPadding: 11
                        bottomPadding: 11
                    }
                }
            }

            Item { Layout.preferredHeight: 12 }

            // Fila 2: Documento de identidad (ancho completo)
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 5
                Label { text: qsTr("Documento de identidad"); color: window.colorTextoSecundario; font.pixelSize: 11 }
                TextField {
                    id: campoDocumento
                    Layout.fillWidth: true
                    placeholderText: qsTr("INE, pasaporte...")
                    color: window.colorTextoClaro
                    placeholderTextColor: "#555555"
                    background: Rectangle {
                        color: window.colorCampo
                        radius: 8
                        border.width: 1
                        border.color: window.colorBorde
                    }
                    leftPadding: 12
                    rightPadding: 12
                    topPadding: 11
                    bottomPadding: 11
                }
            }

            Item { Layout.preferredHeight: 12 }

            // Fila 3: Teléfono / Correo
            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 5
                    Label { text: qsTr("Teléfono"); color: window.colorTextoSecundario; font.pixelSize: 11 }
                    TextField {
                        id: campoTelefono
                        Layout.fillWidth: true
                        placeholderText: qsTr("10 dígitos")
                        inputMethodHints: Qt.ImhDigitsOnly
                        color: window.colorTextoClaro
                        placeholderTextColor: "#555555"
                        background: Rectangle {
                            color: window.colorCampo
                            radius: 8
                            border.width: 1
                            border.color: window.colorBorde
                        }
                        leftPadding: 12
                        rightPadding: 12
                        topPadding: 11
                        bottomPadding: 11
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 5
                    Label { text: qsTr("Correo"); color: window.colorTextoSecundario; font.pixelSize: 11 }
                    TextField {
                        id: campoCorreo
                        Layout.fillWidth: true
                        placeholderText: qsTr("correo@ejemplo.com")
                        inputMethodHints: Qt.ImhEmailCharactersOnly
                        color: window.colorTextoClaro
                        placeholderTextColor: "#555555"
                        background: Rectangle {
                            color: window.colorCampo
                            radius: 8
                            border.width: 1
                            border.color: window.colorBorde
                        }
                        leftPadding: 12
                        rightPadding: 12
                        topPadding: 11
                        bottomPadding: 11
                    }
                }
            }

            // Mensaje de validación (aparece si intentan registrar con campos vacíos)
            Label {
                id: mensajeValidacion
                Layout.topMargin: 10
                text: qsTr("Completa todos los campos antes de registrar.")
                color: window.colorError
                font.pixelSize: 11
                visible: false
            }

            Item { Layout.fillHeight: true }

            // Botones: Cancelar / Registrar huésped
            RowLayout {
                Layout.fillWidth: true
                Layout.bottomMargin: 8
                spacing: 10

                Button {
                    id: botonCancelar
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    text: qsTr("Cancelar")

                    contentItem: Text {
                        text: botonCancelar.text
                        color: window.colorTextoClaro
                        font.pixelSize: 14
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    background: Rectangle {
                        color: "transparent"
                        radius: 8
                        border.width: 1
                        border.color: "#444444"
                        implicitHeight: 44
                    }
                    onClicked: {
                        window.limpiarFormulario()
                        mensajeValidacion.visible = false
                    }
                }

                Button {
                    id: botonRegistrar
                    Layout.fillWidth: true
                    Layout.preferredWidth: 2
                    text: qsTr("Registrar huésped")

                    contentItem: Text {
                        text: botonRegistrar.text
                        color: "#1a1400"
                        font.pixelSize: 14
                        font.weight: Font.Medium
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    background: Rectangle {
                        color: window.colorDorado
                        radius: 8
                        implicitHeight: 44
                        opacity: window.formularioValido ? 1.0 : 0.5
                    }
                    onClicked: {
                        if (!window.formularioValido) {
                            mensajeValidacion.visible = true
                            return
                        }
                        mensajeValidacion.visible = false
                        // TODO (siguiente task de Theme 3): guardar en la
                        // tabla Huesped de la base de datos (INSERT INTO
                        // Huesped ...), en vez de solo limpiar el formulario.
                        console.log("Registro listo para guardar:",
                                    campoNombre.text, campoApellido.text,
                                    campoDocumento.text, campoTelefono.text,
                                    campoCorreo.text)
                        window.limpiarFormulario()
                    }
                }
            }
        }
    }
}
