import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import NexStay

// Theme 4 (Tasks 1 y 2): formulario de inicio de sesion.
// Rediseño de interfaz (revisión 11/nov): panel de bienvenida a la
// izquierda en pantallas anchas; en celular solo se ve el formulario.
//
// Es una vista (Item) que PantallaPrincipal muestra mientras no haya
// sesion; en cuanto Sesion.haySesion pasa a true, PantallaPrincipal la
// oculta y lleva a cada rol a su inicio segun sus permisos.
//
// "Sesion" (Sesion.h/.cpp) es un singleton QML.
Item {
    id: window

    readonly property bool pantallaAncha: width >= 860

    property bool formularioValido: campoCorreo.text.trim().length > 0
                                     && campoContrasena.text.trim().length > 0

    function limpiarFormulario() {
        campoCorreo.text = ""
        campoContrasena.text = ""
        mensajeValidacion.visible = false
    }

    // Reacciona a los rechazos de login que emite Sesion (correo
    // inexistente, contrasena incorrecta, usuario bloqueado, etc.).
    Connections {
        target: Sesion
        function onSesionRechazada(motivo) {
            mensajeValidacion.text = motivo
            mensajeValidacion.visible = true
        }
    }

    function entrar() {
        if (!window.formularioValido) {
            mensajeValidacion.text = qsTr("Escribe tu correo y tu contraseña.")
            mensajeValidacion.visible = true
            return
        }
        mensajeValidacion.visible = false
        // Si el login es correcto, Sesion.haySesion pasa a true y
        // PantallaPrincipal cambia de vista sola.
        if (Sesion.iniciarSesion(campoCorreo.text, campoContrasena.text)) {
            window.limpiarFormulario()
        }
    }

    // Campo de texto con el estilo de la app.
    component Campo: TextField {
        color: Tema.texto
        placeholderTextColor: Tema.placeholder
        font.pixelSize: 15
        leftPadding: 14
        rightPadding: 14
        topPadding: 13
        bottomPadding: 13
        background: Rectangle {
            color: Tema.campo
            radius: Tema.radio
            border.width: parent.activeFocus ? 2 : 1
            border.color: parent.activeFocus ? Tema.primario : Tema.bordeFuerte
        }
    }

    Rectangle {
        anchors.fill: parent
        color: Tema.fondo
    }

    RowLayout {
        anchors.fill: parent
        spacing: 0

        // --- Panel de bienvenida (solo PC) ---
        Rectangle {
            visible: window.pantallaAncha
            Layout.fillHeight: true
            Layout.preferredWidth: window.width * 0.45
            gradient: Gradient {
                GradientStop { position: 0.0; color: Tema.barraLateral }
                GradientStop { position: 1.0; color: Tema.primarioOscuro }
            }

            ColumnLayout {
                anchors.centerIn: parent
                width: Math.min(parent.width - 80, 400)
                spacing: 18

                Rectangle {
                    width: 64; height: 64; radius: 18
                    color: Tema.dorado
                    Label {
                        anchors.centerIn: parent
                        text: "N"
                        color: Tema.barraLateral
                        font.pixelSize: 34
                        font.weight: Font.Black
                    }
                }
                Label {
                    text: "NexStay"
                    color: "#FFFFFF"
                    font.pixelSize: 40
                    font.weight: Font.Bold
                }
                Label {
                    text: qsTr("Todo tu hotel en un solo lugar: habitaciones, reservas, huéspedes y solicitudes.")
                    color: "#D5DEEE"
                    font.pixelSize: 16
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                }

                Repeater {
                    model: [
                        { icono: "🛏️", texto: qsTr("Ve el estado de cada habitación al momento") },
                        { icono: "📅", texto: qsTr("Organiza las reservas en un calendario") },
                        { icono: "🛎️", texto: qsTr("Atiende rápido lo que piden los huéspedes") }
                    ]
                    delegate: RowLayout {
                        required property var modelData
                        spacing: 12
                        Layout.topMargin: 4
                        Rectangle {
                            width: 40; height: 40; radius: 12
                            color: "#22FFFFFF"
                            Label {
                                anchors.centerIn: parent
                                text: modelData.icono
                                font.family: Tema.fuenteIconos
                                font.pixelSize: 18
                            }
                        }
                        Label {
                            text: modelData.texto
                            color: "#FFFFFF"
                            font.pixelSize: 14
                            wrapMode: Text.WordWrap
                            Layout.fillWidth: true
                        }
                    }
                }
            }
        }

        // --- Formulario ---
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            Rectangle {
                anchors.centerIn: parent
                width: Math.min(parent.width - 32, 420)
                height: formulario.implicitHeight + 64
                radius: Tema.radioGrande
                color: Tema.tarjeta
                border.width: 1
                border.color: Tema.borde

                ColumnLayout {
                    id: formulario
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 32
                    spacing: 6

                    // Logo en celular
                    Rectangle {
                        visible: !window.pantallaAncha
                        Layout.alignment: Qt.AlignHCenter
                        Layout.bottomMargin: 8
                        width: 56; height: 56; radius: 16
                        color: Tema.dorado
                        Label {
                            anchors.centerIn: parent
                            text: "N"
                            color: Tema.barraLateral
                            font.pixelSize: 28
                            font.weight: Font.Black
                        }
                    }

                    Label {
                        text: qsTr("¡Bienvenido!")
                        color: Tema.texto
                        font.pixelSize: 26
                        font.weight: Font.Bold
                        Layout.alignment: window.pantallaAncha ? Qt.AlignLeft : Qt.AlignHCenter
                    }
                    Label {
                        text: qsTr("Entra con tu cuenta del hotel")
                        color: Tema.textoSecundario
                        font.pixelSize: 14
                        Layout.bottomMargin: 18
                        Layout.alignment: window.pantallaAncha ? Qt.AlignLeft : Qt.AlignHCenter
                    }

                    Label {
                        text: qsTr("Correo")
                        color: Tema.texto
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                    }
                    Campo {
                        id: campoCorreo
                        Layout.fillWidth: true
                        Layout.bottomMargin: 12
                        placeholderText: qsTr("correo@hotel.com")
                        inputMethodHints: Qt.ImhEmailCharactersOnly
                        focus: true
                        onAccepted: campoContrasena.forceActiveFocus()
                    }

                    Label {
                        text: qsTr("Contraseña")
                        color: Tema.texto
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                    }
                    Campo {
                        id: campoContrasena
                        Layout.fillWidth: true
                        placeholderText: qsTr("Tu contraseña")
                        echoMode: verContrasena.checked ? TextInput.Normal : TextInput.Password
                        rightPadding: 80
                        onAccepted: window.entrar()

                        // Mostrar / ocultar contraseña
                        Label {
                            id: verContrasena
                            property bool checked: false
                            anchors.right: parent.right
                            anchors.rightMargin: 14
                            anchors.verticalCenter: parent.verticalCenter
                            text: checked ? qsTr("Ocultar") : qsTr("Mostrar")
                            color: Tema.primario
                            font.pixelSize: 13
                            font.weight: Font.DemiBold
                            MouseArea {
                                anchors.fill: parent
                                anchors.margins: -8
                                cursorShape: Qt.PointingHandCursor
                                onClicked: verContrasena.checked = !verContrasena.checked
                            }
                        }
                    }

                    // Mensaje de validación (campos vacíos o login rechazado)
                    Rectangle {
                        visible: mensajeValidacion.visible
                        Layout.fillWidth: true
                        Layout.topMargin: 12
                        implicitHeight: mensajeValidacion.implicitHeight + 20
                        radius: 10
                        color: Tema.errorSuave
                        Label {
                            id: mensajeValidacion
                            anchors.verticalCenter: parent.verticalCenter
                            x: 12
                            width: parent.width - 24
                            text: qsTr("Escribe tu correo y tu contraseña.")
                            color: Tema.error
                            font.pixelSize: 13
                            wrapMode: Text.WordWrap
                            visible: false
                        }
                    }

                    // Botón Entrar
                    Button {
                        id: botonEntrar
                        Layout.fillWidth: true
                        Layout.topMargin: 20
                        text: qsTr("Entrar")
                        hoverEnabled: true

                        contentItem: Text {
                            text: botonEntrar.text
                            color: Tema.textoSobrePrimario
                            font.pixelSize: 16
                            font.weight: Font.DemiBold
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                        background: Rectangle {
                            color: botonEntrar.hovered ? Tema.primarioOscuro : Tema.primario
                            radius: Tema.radio
                            implicitHeight: 50
                            opacity: window.formularioValido ? 1.0 : 0.55
                        }
                        onClicked: window.entrar()
                    }

                    Label {
                        text: qsTr("¿Olvidaste tu contraseña? Pide al administrador del hotel que te ayude.")
                        color: Tema.textoSecundario
                        font.pixelSize: 12
                        wrapMode: Text.WordWrap
                        horizontalAlignment: Text.AlignHCenter
                        Layout.fillWidth: true
                        Layout.topMargin: 16
                    }
                }
            }
        }
    }
}
