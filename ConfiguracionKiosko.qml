import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import NexStay

// Theme 11: "Configurar esta pantalla" del modo kiosko. Sirve para decir
// que habitacion es cada mini PC sin escribir --habitacion= en el .bat.
//   Paso 1: un administrador entra con su correo y contrasena.
//   Paso 2: elige la habitacion (se guarda en esta computadora).
// La sesion del administrador se cierra en cuanto termina o cancela.
Item {
    id: config

    property bool puedeCancelar: false
    signal terminada(string numero)
    signal cancelada()

    property bool autorizado: false
    property string error: ""
    property var habitaciones: []

    ControlAcceso { id: control }
    Habitacion { id: consulta }

    Connections {
        target: Sesion
        function onSesionRechazada(motivo) { config.error = motivo }
    }

    function entrar() {
        error = ""
        if (campoCorreo.text.trim() === "" || campoContrasena.text === "") {
            error = qsTr("Escribe el correo y la contraseña del administrador.")
            return
        }
        if (!Sesion.iniciarSesion(campoCorreo.text, campoContrasena.text)) {
            return      // el motivo llega por onSesionRechazada
        }
        // Solo el administrador ve y administra usuarios.
        if (!control.tienePermiso("usuarios", "ver")) {
            Sesion.cerrarSesion()
            error = qsTr("Solo un administrador puede configurar esta pantalla.")
            return
        }
        habitaciones = consulta.habitacionesParaConfigurar()
        autorizado = true
    }

    function salir() {
        if (Sesion.haySesion) Sesion.cerrarSesion()
    }

    Component.onDestruction: salir()

    Rectangle {
        anchors.fill: parent
        color: Tema.fondo
    }

    Flickable {
        anchors.fill: parent
        contentHeight: columna.implicitHeight + 48
        boundsBehavior: Flickable.StopAtBounds
        clip: true

        ColumnLayout {
            id: columna
            width: Math.min(parent.width - 32, 560)
            x: (parent.width - width) / 2
            y: 24
            spacing: 16

            // Encabezado
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 96
                radius: Tema.radioGrande
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: Tema.barraLateral }
                    GradientStop { position: 1.0; color: Tema.primario }
                }
                ColumnLayout {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: 22
                    anchors.rightMargin: 22
                    spacing: 2
                    Label {
                        text: qsTr("⚙️  Configurar esta pantalla")
                        color: "#FFFFFF"
                        font.pixelSize: 22
                        font.weight: Font.Bold
                    }
                    Label {
                        text: config.autorizado
                              ? qsTr("Elige en qué habitación está esta pantalla.")
                              : qsTr("Solo para el personal del hotel.")
                        color: "#E0E7FF"
                        font.pixelSize: 14
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                    }
                }
            }

            // Paso 1: administrador
            Rectangle {
                visible: !config.autorizado
                Layout.fillWidth: true
                implicitHeight: login.implicitHeight + 44
                radius: Tema.radioGrande
                color: Tema.tarjeta
                border.width: 1
                border.color: Tema.borde

                ColumnLayout {
                    id: login
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 22
                    spacing: 8

                    Label {
                        text: qsTr("Cuenta de administrador")
                        color: Tema.texto
                        font.pixelSize: 17
                        font.weight: Font.Bold
                    }
                    TextField {
                        id: campoCorreo
                        Layout.fillWidth: true
                        placeholderText: qsTr("correo@hotel.com")
                        inputMethodHints: Qt.ImhEmailCharactersOnly
                        font.pixelSize: 15
                        color: Tema.texto
                        placeholderTextColor: Tema.placeholder
                        padding: 12
                        background: Rectangle {
                            radius: Tema.radio
                            color: Tema.campo
                            border.width: campoCorreo.activeFocus ? 2 : 1
                            border.color: campoCorreo.activeFocus ? Tema.primario : Tema.bordeFuerte
                        }
                        onAccepted: campoContrasena.forceActiveFocus()
                    }
                    TextField {
                        id: campoContrasena
                        Layout.fillWidth: true
                        placeholderText: qsTr("Contraseña")
                        echoMode: TextInput.Password
                        font.pixelSize: 15
                        color: Tema.texto
                        placeholderTextColor: Tema.placeholder
                        padding: 12
                        background: Rectangle {
                            radius: Tema.radio
                            color: Tema.campo
                            border.width: campoContrasena.activeFocus ? 2 : 1
                            border.color: campoContrasena.activeFocus ? Tema.primario : Tema.bordeFuerte
                        }
                        onAccepted: config.entrar()
                    }
                    Label {
                        visible: config.error.length > 0
                        text: config.error
                        color: Tema.error
                        font.pixelSize: 13
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.topMargin: 6
                        spacing: 10
                        BotonApp {
                            visible: config.puedeCancelar
                            Layout.fillWidth: true
                            text: qsTr("Cancelar")
                            onClicked: config.cancelada()
                        }
                        BotonApp {
                            Layout.fillWidth: true
                            principal: true
                            text: qsTr("Continuar")
                            onClicked: config.entrar()
                        }
                    }
                }
            }

            // Paso 2: elegir habitacion
            Label {
                visible: config.autorizado
                text: qsTr("Toca la habitación:")
                color: Tema.texto
                font.pixelSize: 16
                font.weight: Font.DemiBold
            }
            Flow {
                visible: config.autorizado
                Layout.fillWidth: true
                spacing: 10
                Repeater {
                    model: config.habitaciones
                    delegate: Rectangle {
                        id: cuarto
                        required property var modelData
                        width: 100
                        height: 76
                        radius: Tema.radio
                        color: areaCuarto.pressed ? Tema.primarioSuave : Tema.tarjeta
                        border.width: 1
                        border.color: Tema.bordeFuerte
                        Column {
                            anchors.centerIn: parent
                            Label {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: cuarto.modelData.numero
                                color: Tema.texto
                                font.pixelSize: 22
                                font.weight: Font.Bold
                            }
                            Label {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: qsTr("Piso %1 · %2").arg(cuarto.modelData.piso).arg(cuarto.modelData.tipo)
                                color: Tema.textoSecundario
                                font.pixelSize: 11
                            }
                        }
                        MouseArea {
                            id: areaCuarto
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            ResaltadoHover {}
                            onClicked: {
                                config.salir()
                                config.terminada(cuarto.modelData.numero)
                            }
                        }
                    }
                }
            }
            BotonApp {
                visible: config.autorizado && config.puedeCancelar
                Layout.alignment: Qt.AlignHCenter
                text: qsTr("Cancelar")
                onClicked: {
                    config.salir()
                    config.cancelada()
                }
            }
        }
    }
}
