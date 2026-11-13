import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import NexStay

// Theme 7, Task 3: administracion de usuarios y roles.
//
// Dos pestanas:
//   - Usuarios: lista de cuentas, alta de usuarios nuevos y, al tocar
//     una cuenta, cambiar su rol, activarla/desactivarla o restablecer
//     su contrasena.
//   - Permisos: se elige un rol y se enciende o apaga cada accion de
//     cada modulo (la tabla Permisos que gobierna menus y funciones).
//
// Todo lo que se muestra y se guarda pasa por AdministracionUsuarios
// (C++), que vuelve a validar el permiso de la sesion y las reglas
// anti-bloqueo; esta pantalla solo presenta los resultados.
Item {
    id: root

    readonly property color colorFondo: Tema.fondo
    readonly property color colorTarjeta: Tema.tarjeta
    readonly property color colorBorde: Tema.borde
    readonly property color colorDorado: Tema.primario
    readonly property color colorTextoSecundario: Tema.textoSecundario
    readonly property color colorTextoClaro: Tema.texto
    readonly property color colorError: Tema.error
    readonly property color colorExito: Tema.exito

    property var listaUsuarios: []
    property var listaRoles: []
    property var listaModulos: []
    property var listaPermisos: []
    property var usuarioSeleccionado: null
    property int rolEnEdicion: -1
    property string mensaje: ""
    property bool mensajeExito: false

    function recargarUsuarios() {
        listaUsuarios = admin.usuarios()
        if (usuarioSeleccionado) {
            const id = usuarioSeleccionado.idUsuario
            usuarioSeleccionado = listaUsuarios.find(u => u.idUsuario === id) || null
        }
    }
    function recargarPermisos() {
        listaPermisos = admin.permisos()
    }
    function avisar(texto, exito) {
        mensaje = texto
        mensajeExito = exito
        temporizadorMensaje.restart()
    }
    function tienePermiso(idRol, modulo, accion) {
        // Dependencia explicita para que el binding se recalcule.
        const permisos = listaPermisos
        return permisos.some(p => p.idRol === idRol && p.modulo === modulo && p.accion === accion)
    }
    function nombreAccion(accion) {
        switch (accion) {
        case "ver": return qsTr("Ver")
        case "crear": return qsTr("Crear")
        case "editar": return qsTr("Editar")
        case "eliminar": return qsTr("Eliminar")
        case "entrar": return qsTr("Entrar")
        }
        return accion
    }
    function nombreModulo(modulo) {
        switch (modulo) {
        case "habitaciones": return qsTr("Habitaciones")
        case "huespedes": return qsTr("Huéspedes")
        case "reservas": return qsTr("Reservas")
        case "solicitudes": return qsTr("Solicitudes")
        case "usuarios": return qsTr("Usuarios")
        case "bitacora": return qsTr("Bitácora")
        case "reportes": return qsTr("Reportes")
        }
        return modulo
    }

    AdministracionUsuarios {
        id: admin
        onOperacionRechazada: function(motivo) { root.avisar(motivo, false) }
        onUsuariosCambiaron: root.recargarUsuarios()
        onPermisosCambiaron: root.recargarPermisos()
    }

    Component.onCompleted: {
        listaRoles = admin.roles()
        listaModulos = admin.modulos()
        if (listaRoles.length > 0) {
            rolEnEdicion = listaRoles[0].idRol
        }
        recargarUsuarios()
        recargarPermisos()
    }

    Timer {
        id: temporizadorMensaje
        interval: 5000
        onTriggered: root.mensaje = ""
    }

    // Boton de texto reutilizable.
    component Boton: Rectangle {
        id: boton
        property alias texto: etiqueta.text
        property bool principal: false
        property bool peligro: false
        signal pulsado()
        implicitHeight: 40
        implicitWidth: etiqueta.implicitWidth + 28
        radius: 8
        color: principal ? root.colorDorado : "transparent"
        border.width: principal ? 0 : 1
        border.color: peligro ? root.colorError : Tema.bordeFuerte
        Label {
            id: etiqueta
            anchors.centerIn: parent
            color: boton.principal ? Tema.textoSobrePrimario : (boton.peligro ? root.colorError : root.colorTextoClaro)
            font.pixelSize: 13
        }
        MouseArea {
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            ResaltadoHover {}
            anchors.fill: parent
            onClicked: boton.pulsado()
        }
    }

    // Chip seleccionable (roles, acciones).
    component Chip: Rectangle {
        id: chip
        property alias texto: lbl.text
        property bool activo: false
        property bool bloqueado: false
        signal pulsado()
        implicitHeight: 32
        implicitWidth: lbl.implicitWidth + 24
        radius: 16
        color: activo ? root.colorDorado : Tema.suave
        border.width: 1
        border.color: activo ? root.colorDorado : Tema.borde
        opacity: bloqueado ? 0.55 : 1
        Label {
            id: lbl
            anchors.centerIn: parent
            color: chip.activo ? Tema.textoSobrePrimario : root.colorTextoSecundario
            font.pixelSize: 13
            font.weight: chip.activo ? Font.Medium : Font.Normal
        }
        MouseArea {
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            ResaltadoHover {}
            anchors.fill: parent
            onClicked: chip.pulsado()
        }
    }

    component Campo: TextField {
        color: root.colorTextoClaro
        placeholderTextColor: Tema.placeholder
        font.pixelSize: 13
        selectByMouse: true
        Layout.fillWidth: true
        background: Rectangle {
            radius: 8
            color: Tema.campo
            border.width: 1
            border.color: parent.activeFocus ? root.colorDorado : Tema.borde
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // Pestanas
        RowLayout {
            Layout.fillWidth: true
            Layout.margins: 14
            spacing: 8
            Chip {
                texto: qsTr("Usuarios")
                activo: pestanas.currentIndex === 0
                onPulsado: pestanas.currentIndex = 0
            }
            Chip {
                texto: qsTr("Permisos")
                activo: pestanas.currentIndex === 1
                onPulsado: pestanas.currentIndex = 1
            }
            Item { Layout.fillWidth: true }
            Boton {
                visible: pestanas.currentIndex === 0
                principal: true
                texto: qsTr("+ Nuevo usuario")
                implicitHeight: 34
                onPulsado: {
                    nombreNuevo.text = ""; apellidoNuevo.text = ""
                    correoNuevo.text = ""; contrasenaNueva.text = ""
                    rolNuevo = root.listaRoles.length > 0 ? root.listaRoles[root.listaRoles.length - 1].idRol : -1
                    popupNuevo.open()
                }
            }
        }

        Label {
            visible: root.mensaje.length > 0
            text: root.mensaje
            color: root.mensajeExito ? root.colorExito : root.colorError
            font.pixelSize: 13
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
            Layout.leftMargin: 14
            Layout.rightMargin: 14
            Layout.bottomMargin: 8
        }

        StackLayout {
            id: pestanas
            Layout.fillWidth: true
            Layout.fillHeight: true

            // --- Pestana Usuarios ---
            ListView {
                clip: true
                spacing: 8
                leftMargin: Math.max(14, (width - 560) / 2)
                rightMargin: leftMargin
                bottomMargin: 14
                boundsBehavior: Flickable.StopAtBounds
                model: root.listaUsuarios

                delegate: Rectangle {
                    required property var modelData
                    width: ListView.view.width - ListView.view.leftMargin - ListView.view.rightMargin
                    height: 64
                    radius: 10
                    color: root.colorTarjeta
                    border.width: 1
                    border.color: root.colorBorde
                    opacity: modelData.estado === "activo" ? 1 : 0.6

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 14
                        anchors.rightMargin: 14
                        spacing: 8
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2
                            Label {
                                text: modelData.nombre + " " + modelData.apellido
                                      + (modelData.esActual ? qsTr("  (tú)") : "")
                                color: root.colorTextoClaro
                                font.pixelSize: 14
                                font.weight: Font.Medium
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                            Label {
                                text: modelData.correo
                                color: root.colorTextoSecundario
                                font.pixelSize: 12
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                        }
                        ColumnLayout {
                            spacing: 3
                            Label {
                                text: modelData.rol
                                color: root.colorDorado
                                font.pixelSize: 12
                                Layout.alignment: Qt.AlignRight
                            }
                            Label {
                                text: modelData.estado === "activo" ? qsTr("activo") : qsTr("inactivo")
                                color: modelData.estado === "activo" ? root.colorExito : root.colorError
                                font.pixelSize: 12
                                Layout.alignment: Qt.AlignRight
                            }
                        }
                    }
                    MouseArea {
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        ResaltadoHover {}
                        anchors.fill: parent
                        onClicked: {
                            root.usuarioSeleccionado = modelData
                            nuevaContrasena.text = ""
                            popupDetalle.open()
                        }
                    }
                }
            }

            // --- Pestana Permisos ---
            Flickable {
                clip: true
                contentWidth: width
                contentHeight: colPermisos.implicitHeight + 28
                boundsBehavior: Flickable.StopAtBounds

                ColumnLayout {
                    id: colPermisos
                    x: Math.max(14, (parent.width - 560) / 2)
                    width: parent.width - 2 * x
                    spacing: 10

                    Label {
                        text: qsTr("Rol")
                        color: root.colorTextoSecundario
                        font.pixelSize: 12
                    }
                    Flow {
                        Layout.fillWidth: true
                        spacing: 8
                        Repeater {
                            model: root.listaRoles
                            Chip {
                                required property var modelData
                                texto: modelData.nombre
                                activo: root.rolEnEdicion === modelData.idRol
                                onPulsado: root.rolEnEdicion = modelData.idRol
                            }
                        }
                    }
                    Label {
                        text: qsTr("Toca una acción para concederla (dorado) o quitarla. Los cambios se aplican a ese rol de inmediato; quienes ya tienen sesión los verán al volver al menú.")
                        color: root.colorTextoSecundario
                        font.pixelSize: 12
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                    }

                    Repeater {
                        model: root.listaModulos
                        Rectangle {
                            id: tarjetaModulo
                            required property var modelData
                            Layout.fillWidth: true
                            implicitHeight: filaModulo.implicitHeight + 24
                            radius: 10
                            color: root.colorTarjeta
                            border.width: 1
                            border.color: root.colorBorde

                            ColumnLayout {
                                id: filaModulo
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.top: parent.top
                                anchors.margins: 12
                                spacing: 8
                                Label {
                                    text: root.nombreModulo(tarjetaModulo.modelData.modulo)
                                    color: root.colorTextoClaro
                                    font.pixelSize: 14
                                    font.weight: Font.Medium
                                }
                                Flow {
                                    Layout.fillWidth: true
                                    spacing: 8
                                    Repeater {
                                        model: tarjetaModulo.modelData.acciones
                                        Chip {
                                            required property var modelData
                                            readonly property bool concedido:
                                                root.tienePermiso(root.rolEnEdicion,
                                                                  tarjetaModulo.modelData.modulo, modelData)
                                            texto: root.nombreAccion(modelData)
                                            activo: concedido
                                            bloqueado: concedido && admin.permisoBloqueado(
                                                           root.rolEnEdicion,
                                                           tarjetaModulo.modelData.modulo, modelData)
                                            onPulsado: admin.establecerPermiso(
                                                           root.rolEnEdicion,
                                                           tarjetaModulo.modelData.modulo,
                                                           modelData, !concedido)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // --- Alta de usuario ---
    property int rolNuevo: -1

    Popup {
        id: popupNuevo
        parent: Overlay.overlay
        anchors.centerIn: parent
        modal: true
        width: Math.min(parent.width - 32, 400)
        padding: 16
        background: Rectangle { radius: 12; color: root.colorTarjeta; border.width: 1; border.color: root.colorBorde }

        ColumnLayout {
            width: parent.width
            spacing: 10
            Label {
                text: qsTr("Nuevo usuario")
                color: root.colorDorado
                font.pixelSize: 16
                font.weight: Font.Medium
            }
            Campo { id: nombreNuevo; placeholderText: qsTr("Nombre") }
            Campo { id: apellidoNuevo; placeholderText: qsTr("Apellido") }
            Campo { id: correoNuevo; placeholderText: qsTr("Correo"); inputMethodHints: Qt.ImhEmailCharactersOnly }
            Campo { id: contrasenaNueva; placeholderText: qsTr("Contraseña (mín. 8 caracteres)"); echoMode: TextInput.Password }
            Flow {
                Layout.fillWidth: true
                spacing: 8
                Repeater {
                    model: root.listaRoles
                    Chip {
                        required property var modelData
                        texto: modelData.nombre
                        activo: root.rolNuevo === modelData.idRol
                        onPulsado: root.rolNuevo = modelData.idRol
                    }
                }
            }
            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                Boton { Layout.fillWidth: true; texto: qsTr("Cancelar"); onPulsado: popupNuevo.close() }
                Boton {
                    Layout.fillWidth: true
                    principal: true
                    texto: qsTr("Crear")
                    onPulsado: {
                        if (admin.crearUsuario(nombreNuevo.text, apellidoNuevo.text,
                                               correoNuevo.text, contrasenaNueva.text, root.rolNuevo)) {
                            popupNuevo.close()
                            root.avisar(qsTr("Usuario creado."), true)
                        } else {
                            // El motivo ya se muestra arriba; se cierra
                            // el teclado/popup solo si se creo.
                        }
                    }
                }
            }
        }
    }

    // --- Detalle de usuario ---
    Popup {
        id: popupDetalle
        parent: Overlay.overlay
        anchors.centerIn: parent
        modal: true
        width: Math.min(parent.width - 32, 400)
        padding: 16
        background: Rectangle { radius: 12; color: root.colorTarjeta; border.width: 1; border.color: root.colorBorde }

        ColumnLayout {
            width: parent.width
            spacing: 10
            visible: root.usuarioSeleccionado !== null

            Label {
                text: root.usuarioSeleccionado
                      ? root.usuarioSeleccionado.nombre + " " + root.usuarioSeleccionado.apellido : ""
                color: root.colorDorado
                font.pixelSize: 16
                font.weight: Font.Medium
                Layout.fillWidth: true
                elide: Text.ElideRight
            }
            Label {
                text: root.usuarioSeleccionado ? root.usuarioSeleccionado.correo : ""
                color: root.colorTextoSecundario
                font.pixelSize: 13
            }
            Label {
                text: qsTr("Rol")
                color: root.colorTextoSecundario
                font.pixelSize: 12
            }
            Flow {
                Layout.fillWidth: true
                spacing: 8
                Repeater {
                    model: root.listaRoles
                    Chip {
                        required property var modelData
                        texto: modelData.nombre
                        activo: root.usuarioSeleccionado !== null
                                && root.usuarioSeleccionado.idRol === modelData.idRol
                        onPulsado: {
                            if (root.usuarioSeleccionado
                                    && admin.cambiarRol(root.usuarioSeleccionado.idUsuario, modelData.idRol)) {
                                root.avisar(qsTr("Rol actualizado."), true)
                            }
                        }
                    }
                }
            }
            Boton {
                Layout.fillWidth: true
                peligro: root.usuarioSeleccionado !== null && root.usuarioSeleccionado.estado === "activo"
                texto: root.usuarioSeleccionado && root.usuarioSeleccionado.estado === "activo"
                       ? qsTr("Desactivar cuenta") : qsTr("Reactivar cuenta")
                onPulsado: {
                    const u = root.usuarioSeleccionado
                    if (u && admin.cambiarEstado(u.idUsuario, u.estado === "activo" ? "inactivo" : "activo")) {
                        root.avisar(qsTr("Estado actualizado."), true)
                    }
                }
            }
            Campo { id: nuevaContrasena; placeholderText: qsTr("Nueva contraseña"); echoMode: TextInput.Password }
            Boton {
                Layout.fillWidth: true
                texto: qsTr("Restablecer contraseña")
                onPulsado: {
                    const u = root.usuarioSeleccionado
                    if (u && admin.restablecerContrasena(u.idUsuario, nuevaContrasena.text)) {
                        nuevaContrasena.text = ""
                        root.avisar(qsTr("Contraseña restablecida."), true)
                    }
                }
            }
            Boton { Layout.fillWidth: true; principal: true; texto: qsTr("Cerrar"); onPulsado: popupDetalle.close() }
        }
    }
}
