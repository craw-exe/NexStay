import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import NexStay

// Theme 11 Task 6: app del CELULAR para el personal (limpieza,
// mantenimiento, recepcion, administrador). Se conecta por WiFi al
// servidor que abre la app de la PC de recepcion y muestra en vivo las
// solicitudes de los cuartos: avisa cuando llega una nueva y permite
// tomarla y terminarla. Todo se guarda en la base de la PC, asi que la
// laptop ve lo mismo y al reves.
ApplicationWindow {
    id: app
    width: 400
    height: 760
    visible: true
    title: qsTr("NexStay Personal")
    font.family: "Segoe UI"

    readonly property bool dentro: hotel.idUsuario > 0
    property string textoBanner: ""
    property string textoMensaje: ""
    property bool mensajeEsError: false

    ConexionHotel {
        id: hotel
        onError: function(motivo) { app.mostrarMensaje(motivo, true) }
        onAviso: function(mensaje) { app.mostrarMensaje(mensaje, false) }
        onNuevaSolicitud: function(id, tipo, habitacion, prioridad) {
            app.textoBanner = qsTr("Nueva solicitud de %1 en la habitación %2").arg(tipo).arg(habitacion)
            banner.visible = true
            temporizadorBanner.restart()
        }
    }

    function mostrarMensaje(texto, esError) {
        textoMensaje = texto
        mensajeEsError = esError
        temporizadorMensaje.restart()
    }

    Timer { id: temporizadorBanner; interval: 8000; onTriggered: banner.visible = false }
    Timer { id: temporizadorMensaje; interval: 3500; onTriggered: app.textoMensaje = "" }

    function iconoTipo(tipo) { return tipo === "limpieza" ? "🧹" : "🔧" }
    function colorPrioridad(p) {
        return p === "alta" ? Tema.error : (p === "media" ? Tema.aviso : Tema.textoSecundario)
    }
    function textoEspera(min) {
        if (min < 1) return qsTr("Hace un momento")
        if (min < 60) return qsTr("Hace %1 min").arg(min)
        return qsTr("Hace %1 h %2 min").arg(Math.floor(min / 60)).arg(min % 60)
    }

    Rectangle {
        anchors.fill: parent
        color: Tema.fondo
    }

    // ================= Conectar al hotel =================
    Flickable {
        visible: !app.dentro
        anchors.fill: parent
        contentHeight: formulario.implicitHeight + 64
        boundsBehavior: Flickable.StopAtBounds

        ColumnLayout {
            id: formulario
            width: Math.min(parent.width - 40, 420)
            x: (parent.width - width) / 2
            y: 40
            spacing: 8

            Rectangle {
                Layout.alignment: Qt.AlignHCenter
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
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 6
                text: qsTr("NexStay Personal")
                color: Tema.texto
                font.pixelSize: 26
                font.weight: Font.Bold
            }
            Label {
                Layout.alignment: Qt.AlignHCenter
                Layout.fillWidth: true
                Layout.bottomMargin: 18
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                text: qsTr("Recibe al momento lo que piden los cuartos.")
                color: Tema.textoSecundario
                font.pixelSize: 14
            }

            Label { text: qsTr("IP del hotel"); color: Tema.texto; font.pixelSize: 13; font.weight: Font.DemiBold }
            TextField {
                id: campoServidor
                Layout.fillWidth: true
                text: hotel.servidor
                placeholderText: qsTr("Ej. 192.168.1.20")
                inputMethodHints: Qt.ImhPreferNumbers
                font.pixelSize: 16
                color: Tema.texto
                placeholderTextColor: Tema.placeholder
                padding: 14
                background: Rectangle {
                    radius: Tema.radio
                    color: Tema.campo
                    border.width: campoServidor.activeFocus ? 2 : 1
                    border.color: campoServidor.activeFocus ? Tema.primario : Tema.bordeFuerte
                }
            }
            Label {
                Layout.fillWidth: true
                Layout.bottomMargin: 8
                wrapMode: Text.WordWrap
                text: qsTr("Aparece en la app de recepción, abajo a la izquierda.")
                color: Tema.textoSecundario
                font.pixelSize: 12
            }

            Label { text: qsTr("Correo"); color: Tema.texto; font.pixelSize: 13; font.weight: Font.DemiBold }
            TextField {
                id: campoCorreo
                Layout.fillWidth: true
                Layout.bottomMargin: 8
                text: hotel.correoGuardado
                placeholderText: qsTr("correo@hotel.com")
                inputMethodHints: Qt.ImhEmailCharactersOnly | Qt.ImhNoAutoUppercase
                font.pixelSize: 16
                color: Tema.texto
                placeholderTextColor: Tema.placeholder
                padding: 14
                background: Rectangle {
                    radius: Tema.radio
                    color: Tema.campo
                    border.width: campoCorreo.activeFocus ? 2 : 1
                    border.color: campoCorreo.activeFocus ? Tema.primario : Tema.bordeFuerte
                }
            }

            Label { text: qsTr("Contraseña"); color: Tema.texto; font.pixelSize: 13; font.weight: Font.DemiBold }
            TextField {
                id: campoContrasena
                Layout.fillWidth: true
                placeholderText: qsTr("Tu contraseña")
                echoMode: TextInput.Password
                font.pixelSize: 16
                color: Tema.texto
                placeholderTextColor: Tema.placeholder
                padding: 14
                background: Rectangle {
                    radius: Tema.radio
                    color: Tema.campo
                    border.width: campoContrasena.activeFocus ? 2 : 1
                    border.color: campoContrasena.activeFocus ? Tema.primario : Tema.bordeFuerte
                }
                onAccepted: botonConectar.clicked()
            }

            Rectangle {
                visible: app.textoMensaje.length > 0 && app.mensajeEsError
                Layout.fillWidth: true
                Layout.topMargin: 10
                implicitHeight: textoError.implicitHeight + 20
                radius: 10
                color: Tema.errorSuave
                Label {
                    id: textoError
                    x: 12
                    width: parent.width - 24
                    anchors.verticalCenter: parent.verticalCenter
                    text: app.textoMensaje
                    color: Tema.error
                    font.pixelSize: 13
                    wrapMode: Text.WordWrap
                }
            }

            BotonApp {
                id: botonConectar
                Layout.fillWidth: true
                Layout.topMargin: 16
                Layout.preferredHeight: 52
                principal: true
                enabled: hotel.estado !== "conectando"
                text: hotel.estado === "conectando" ? qsTr("Conectando…") : qsTr("Conectar")
                font.pixelSize: 16
                onClicked: {
                    app.textoMensaje = ""
                    hotel.conectar(campoServidor.text, campoCorreo.text, campoContrasena.text)
                    campoContrasena.text = ""
                }
            }
            Label {
                Layout.fillWidth: true
                Layout.topMargin: 12
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                text: qsTr("El celular tiene que estar en el mismo WiFi que la computadora de recepción.")
                color: Tema.textoSecundario
                font.pixelSize: 12
            }
        }
    }

    // ================= Solicitudes en vivo =================
    ColumnLayout {
        visible: app.dentro
        anchors.fill: parent
        spacing: 0

        // Encabezado
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 96
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: Tema.barraLateral }
                GradientStop { position: 1.0; color: Tema.primario }
            }
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 18
                anchors.rightMargin: 18
                spacing: 12
                ColumnLayout {
                    spacing: 2
                    Layout.fillWidth: true
                    Label {
                        text: qsTr("Hola, %1").arg(hotel.nombre)
                        color: "#FFFFFF"
                        font.pixelSize: 20
                        font.weight: Font.Bold
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                    Row {
                        spacing: 6
                        Rectangle {
                            width: 9; height: 9; radius: 5
                            anchors.verticalCenter: parent.verticalCenter
                            color: hotel.estado === "conectado" ? "#4ADE80" : "#FBBF24"
                        }
                        Label {
                            text: hotel.estado === "conectado"
                                  ? qsTr("Conectado · %1").arg(hotel.rol)
                                  : qsTr("Reconectando…")
                            color: "#E0E7FF"
                            font.pixelSize: 13
                        }
                    }
                }
                BotonApp {
                    text: qsTr("Salir")
                    onClicked: hotel.desconectar()
                }
            }
        }

        // Aviso de solicitud nueva
        Rectangle {
            id: banner
            visible: false
            Layout.fillWidth: true
            Layout.margins: 12
            implicitHeight: 56
            radius: Tema.radio
            color: Tema.avisoSuave
            border.width: 2
            border.color: Tema.aviso
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 14
                anchors.rightMargin: 14
                spacing: 10
                Label { text: "🔔"; font.family: Tema.fuenteIconos; font.pixelSize: 22 }
                Label {
                    text: app.textoBanner
                    color: "#92400E"
                    font.pixelSize: 14
                    font.weight: Font.DemiBold
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                }
            }
            MouseArea { anchors.fill: parent; onClicked: banner.visible = false }
        }

        Label {
            Layout.leftMargin: 18
            Layout.topMargin: banner.visible ? 0 : 14
            text: qsTr("Pendientes (%1)").arg(hotel.solicitudes.length)
            color: Tema.texto
            font.pixelSize: 17
            font.weight: Font.Bold
        }

        // Sin pendientes
        ColumnLayout {
            visible: hotel.solicitudes.length === 0
            Layout.fillWidth: true
            Layout.fillHeight: true
            Item { Layout.fillHeight: true }
            Label {
                Layout.alignment: Qt.AlignHCenter
                text: "✨"
                font.family: Tema.fuenteIconos
                font.pixelSize: 48
            }
            Label {
                Layout.alignment: Qt.AlignHCenter
                text: qsTr("Todo en orden")
                color: Tema.texto
                font.pixelSize: 18
                font.weight: Font.DemiBold
            }
            Label {
                Layout.alignment: Qt.AlignHCenter
                text: qsTr("Aquí aparecen las solicitudes de los cuartos.")
                color: Tema.textoSecundario
                font.pixelSize: 13
            }
            Item { Layout.fillHeight: true }
        }

        ListView {
            id: lista
            visible: hotel.solicitudes.length > 0
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 10
            topMargin: 10
            bottomMargin: 20
            model: hotel.solicitudes

            delegate: Rectangle {
                id: tarjeta
                required property var modelData
                readonly property bool enProceso: modelData.estado === "en_proceso"
                readonly property bool esMia: modelData.idResponsable === hotel.idUsuario
                readonly property bool puedeTerminar: enProceso && (esMia || hotel.rol === "administrador")
                x: 12
                width: lista.width - 24
                implicitHeight: contenidoTarjeta.implicitHeight + 28
                radius: Tema.radioGrande
                color: Tema.tarjeta
                border.width: esMia ? 2 : 1
                border.color: esMia ? Tema.primario : Tema.borde

                ColumnLayout {
                    id: contenidoTarjeta
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 14
                    spacing: 10

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12
                        Rectangle {
                            width: 48; height: 48; radius: 14
                            color: tarjeta.modelData.tipo === "limpieza" ? Tema.avisoSuave : Tema.neutroSuave
                            Label {
                                anchors.centerIn: parent
                                text: app.iconoTipo(tarjeta.modelData.tipo)
                                font.family: Tema.fuenteIconos
                                font.pixelSize: 24
                            }
                        }
                        ColumnLayout {
                            spacing: 0
                            Layout.fillWidth: true
                            Label {
                                text: qsTr("Habitación %1").arg(tarjeta.modelData.numeroHabitacion)
                                color: Tema.texto
                                font.pixelSize: 18
                                font.weight: Font.Bold
                            }
                            Label {
                                text: (tarjeta.modelData.tipo === "limpieza" ? qsTr("Limpieza") : qsTr("Mantenimiento"))
                                      + " · " + app.textoEspera(tarjeta.modelData.minutosEspera)
                                color: Tema.textoSecundario
                                font.pixelSize: 13
                            }
                        }
                        Rectangle {
                            implicitWidth: textoPrioridad.implicitWidth + 16
                            implicitHeight: 26
                            radius: 13
                            color: "transparent"
                            border.width: 1
                            border.color: app.colorPrioridad(tarjeta.modelData.prioridad)
                            Label {
                                id: textoPrioridad
                                anchors.centerIn: parent
                                text: tarjeta.modelData.prioridad
                                color: app.colorPrioridad(tarjeta.modelData.prioridad)
                                font.pixelSize: 12
                                font.weight: Font.DemiBold
                            }
                        }
                    }

                    Label {
                        visible: tarjeta.enProceso
                        text: tarjeta.esMia ? qsTr("La estás atendiendo tú")
                                            : qsTr("La atiende %1").arg(tarjeta.modelData.responsable)
                        color: tarjeta.esMia ? Tema.primario : Tema.textoSecundario
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                    }

                    BotonApp {
                        visible: hotel.puedeAtender && !tarjeta.enProceso
                        Layout.fillWidth: true
                        Layout.preferredHeight: 46
                        principal: true
                        text: qsTr("Tomar esta solicitud")
                        onClicked: hotel.tomar(tarjeta.modelData.idSolicitud)
                    }
                    BotonApp {
                        visible: hotel.puedeAtender && tarjeta.puedeTerminar
                        Layout.fillWidth: true
                        Layout.preferredHeight: 46
                        principal: true
                        text: qsTr("✓ Ya quedó, terminar")
                        onClicked: hotel.atender(tarjeta.modelData.idSolicitud)
                    }
                }
            }
        }
    }

    // Mensaje corto abajo (aviso o error ya conectado)
    Rectangle {
        visible: app.dentro && app.textoMensaje.length > 0
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 30
        width: Math.min(parent.width - 40, 340)
        height: textoToast.implicitHeight + 24
        radius: height / 2
        color: app.mensajeEsError ? Tema.error : Tema.texto
        Label {
            id: textoToast
            anchors.centerIn: parent
            width: parent.width - 32
            text: app.textoMensaje
            color: "#FFFFFF"
            font.pixelSize: 14
            wrapMode: Text.WordWrap
            horizontalAlignment: Text.AlignHCenter
        }
    }
}
