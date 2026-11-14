#include "ServidorPersonal.h"

#include "AlertasPersonal.h"
#include "Sesion.h"

#include <QDebug>
#include <QHostAddress>
#include <QJsonArray>
#include <QJsonDocument>
#include <QNetworkInterface>
#include <QSqlError>
#include <QSqlQuery>
#include <QTcpSocket>

ServidorPersonal::ServidorPersonal(QObject *parent)
    : QObject(parent)
{
    // Las solicitudes que ya existen no generan aviso al arrancar.
    QSqlQuery query;
    if (query.exec(QStringLiteral("SELECT COALESCE(MAX(id_solicitud), 0) FROM Solicitud_Servicio"))
        && query.next()) {
        m_ultimoIdVisto = query.value(0).toInt();
    }

    connect(&m_servidor, &QTcpServer::newConnection, this, &ServidorPersonal::nuevaConexion);
    if (!m_servidor.listen(QHostAddress::AnyIPv4, kPuerto)) {
        qWarning() << "ServidorPersonal: no se pudo abrir el puerto" << kPuerto
                   << m_servidor.errorString();
    }

    // Misma frecuencia que AlertasPersonal: cada 2 segundos.
    connect(&m_timer, &QTimer::timeout, this, &ServidorPersonal::revisar);
    m_timer.start(2000);
}

bool ServidorPersonal::activo() const
{
    return m_servidor.isListening();
}

QString ServidorPersonal::direccion() const
{
    // IPv4 de la red local, prefiriendo el adaptador WiFi y luego el de
    // cable. Se saltan los adaptadores virtuales (VirtualBox, VMware,
    // Hyper-V, WSL, VPN), que tienen IPs a las que el celular no llega.
    QString cable;
    QString otra;
    const auto interfaces = QNetworkInterface::allInterfaces();
    for (const QNetworkInterface &red : interfaces) {
        const auto banderas = red.flags();
        if (!banderas.testFlag(QNetworkInterface::IsUp) || !banderas.testFlag(QNetworkInterface::IsRunning)
            || banderas.testFlag(QNetworkInterface::IsLoopBack)) {
            continue;
        }
        const QString nombre = red.humanReadableName().toLower();
        if (nombre.contains(QLatin1String("virtual")) || nombre.contains(QLatin1String("vmware"))
            || nombre.contains(QLatin1String("vethernet")) || nombre.contains(QLatin1String("wsl"))
            || nombre.contains(QLatin1String("hyper-v")) || nombre.contains(QLatin1String("vpn"))
            || nombre.contains(QLatin1String("bluetooth"))) {
            continue;
        }
        for (const QNetworkAddressEntry &entrada : red.addressEntries()) {
            const QHostAddress ip = entrada.ip();
            if (ip.protocol() != QAbstractSocket::IPv4Protocol
                || ip.toString().startsWith(QLatin1String("169.254."))) {
                continue;
            }
            if (red.type() == QNetworkInterface::Wifi
                || nombre.contains(QLatin1String("wi-fi")) || nombre.contains(QLatin1String("wifi"))
                || nombre.contains(QLatin1String("inal"))) {
                return ip.toString();
            }
            if (red.type() == QNetworkInterface::Ethernet && cable.isEmpty()) {
                cable = ip.toString();
            } else if (otra.isEmpty()) {
                otra = ip.toString();
            }
        }
    }
    if (!cable.isEmpty()) return cable;
    if (!otra.isEmpty()) return otra;
    return QStringLiteral("sin red");
}

int ServidorPersonal::celulares() const
{
    int total = 0;
    for (const Cliente &c : m_clientes) {
        if (c.idUsuario > 0) {
            ++total;
        }
    }
    return total;
}

void ServidorPersonal::nuevaConexion()
{
    while (m_servidor.hasPendingConnections()) {
        QTcpSocket *socket = m_servidor.nextPendingConnection();
        m_clientes.insert(socket, Cliente());

        connect(socket, &QTcpSocket::readyRead, this, [this, socket]() {
            Cliente &cliente = m_clientes[socket];
            cliente.pendiente += socket->readAll();
            // Un mensaje por linea.
            int fin;
            while ((fin = cliente.pendiente.indexOf('\n')) >= 0) {
                const QByteArray linea = cliente.pendiente.left(fin);
                cliente.pendiente.remove(0, fin + 1);
                const QJsonDocument doc = QJsonDocument::fromJson(linea);
                if (doc.isObject()) {
                    procesar(socket, doc.object());
                }
            }
            // Proteccion: no se aceptan lineas enormes.
            if (cliente.pendiente.size() > 64 * 1024) {
                socket->disconnectFromHost();
            }
        });
        connect(socket, &QTcpSocket::disconnected, this, [this, socket]() {
            m_clientes.remove(socket);
            socket->deleteLater();
            emit cambio();
        });
    }
}

void ServidorPersonal::enviar(QTcpSocket *socket, const QJsonObject &mensaje)
{
    socket->write(QJsonDocument(mensaje).toJson(QJsonDocument::Compact) + '\n');
}

void ServidorPersonal::enviarLista(QTcpSocket *socket, bool forzar)
{
    Cliente &cliente = m_clientes[socket];
    if (cliente.idUsuario < 0) {
        return;
    }
    QVariantList lista;
    if (!AlertasPersonal::pendientesPara(cliente.rol, &lista)) {
        return;
    }
    if (forzar || lista != cliente.ultimaLista) {
        cliente.ultimaLista = lista;
        enviar(socket, QJsonObject{
            {QStringLiteral("tipo"), QStringLiteral("lista")},
            {QStringLiteral("solicitudes"), QJsonArray::fromVariantList(lista)}});
    }
}

void ServidorPersonal::procesar(QTcpSocket *socket, const QJsonObject &mensaje)
{
    const QString cmd = mensaje.value(QStringLiteral("cmd")).toString();
    if (cmd == QLatin1String("login")) {
        iniciarSesion(socket, mensaje);
        return;
    }

    Cliente &cliente = m_clientes[socket];
    if (cliente.idUsuario < 0) {
        return; // Sin sesion no se atiende nada mas.
    }

    if (cmd == QLatin1String("tomar") || cmd == QLatin1String("atender")) {
        const int idSolicitud = mensaje.value(QStringLiteral("id")).toInt();
        // El permiso se revisa en cada accion (por si el admin lo cambio).
        const QString rol = AlertasPersonal::rolDeUsuario(cliente.idUsuario, QStringLiteral("editar"));
        QString motivo;
        if (rol.isEmpty()) {
            motivo = QStringLiteral("Tu rol no puede atender solicitudes.");
        } else if (cmd == QLatin1String("tomar")) {
            motivo = AlertasPersonal::tomarComo(idSolicitud, cliente.idUsuario, rol);
        } else {
            motivo = AlertasPersonal::atenderComo(idSolicitud, cliente.idUsuario, rol);
        }
        enviar(socket, QJsonObject{
            {QStringLiteral("tipo"), QStringLiteral("resultado")},
            {QStringLiteral("ok"), motivo.isEmpty()},
            {QStringLiteral("motivo"), motivo},
            {QStringLiteral("mensaje"), cmd == QLatin1String("tomar")
                                            ? QStringLiteral("Tomaste la solicitud.")
                                            : QStringLiteral("Solicitud terminada.")}});
        revisar(); // Todos los celulares se enteran de inmediato.
    }
}

void ServidorPersonal::iniciarSesion(QTcpSocket *socket, const QJsonObject &mensaje)
{
    auto rechazar = [this, socket](const QString &motivo) {
        enviar(socket, QJsonObject{
            {QStringLiteral("tipo"), QStringLiteral("login")},
            {QStringLiteral("ok"), false},
            {QStringLiteral("motivo"), motivo}});
    };

    const QString correo = mensaje.value(QStringLiteral("correo")).toString().trimmed().toLower();
    const QString contrasena = mensaje.value(QStringLiteral("contrasena")).toString();

    Intentos &intentos = m_intentos[correo];
    if (intentos.bloqueadoHasta.isValid() && intentos.bloqueadoHasta > QDateTime::currentDateTime()) {
        rechazar(QStringLiteral("Demasiados intentos fallidos. Intenta de nuevo en unos minutos."));
        return;
    }

    QSqlQuery query;
    query.prepare(QStringLiteral(
        "SELECT id_usuario, contrasena, nombre, apellido FROM Usuario "
        "WHERE correo = :correo COLLATE NOCASE AND estado = 'activo'"));
    query.bindValue(":correo", correo);
    if (!query.exec()) {
        qWarning() << "ServidorPersonal: login:" << query.lastError().text();
        rechazar(QStringLiteral("No se pudo validar. Intenta de nuevo."));
        return;
    }
    const bool encontrado = query.next();
    if (!encontrado || !Sesion::verificarContrasena(contrasena, query.value(1).toString())) {
        if (++intentos.fallos >= Sesion::kMaxIntentos) {
            intentos.fallos = 0;
            intentos.bloqueadoHasta = QDateTime::currentDateTime().addSecs(Sesion::kMinutosBloqueo * 60);
            rechazar(QStringLiteral("Demasiados intentos fallidos. Intenta de nuevo en %1 minutos.")
                         .arg(Sesion::kMinutosBloqueo));
        } else {
            rechazar(QStringLiteral("Correo o contraseña incorrectos."));
        }
        return;
    }
    m_intentos.remove(correo);

    const int idUsuario = query.value(0).toInt();
    const QString nombre = query.value(2).toString() + QLatin1Char(' ') + query.value(3).toString();
    const QString rol = AlertasPersonal::rolDeUsuario(idUsuario, QStringLiteral("ver"));
    if (rol.isEmpty()) {
        rechazar(QStringLiteral("Tu rol no puede ver solicitudes."));
        return;
    }

    Cliente &cliente = m_clientes[socket];
    cliente.idUsuario = idUsuario;
    cliente.rol = rol;
    enviar(socket, QJsonObject{
        {QStringLiteral("tipo"), QStringLiteral("login")},
        {QStringLiteral("ok"), true},
        {QStringLiteral("idUsuario"), idUsuario},
        {QStringLiteral("nombre"), nombre},
        {QStringLiteral("rol"), rol},
        {QStringLiteral("puedeAtender"),
         !AlertasPersonal::rolDeUsuario(idUsuario, QStringLiteral("editar")).isEmpty()}});
    enviarLista(socket, true);
    emit cambio();
}

void ServidorPersonal::revisar()
{
    // 1) Solicitudes nuevas: aviso a cada celular al que le corresponde.
    QSqlQuery nuevas;
    nuevas.prepare(QStringLiteral(
        "SELECT s.id_solicitud, s.tipo, s.prioridad, h.numero "
        "FROM Solicitud_Servicio s "
        "JOIN Habitacion h ON h.id_habitacion = s.id_habitacion "
        "WHERE s.id_solicitud > :ultimo ORDER BY s.id_solicitud"));
    nuevas.bindValue(":ultimo", m_ultimoIdVisto);
    if (nuevas.exec()) {
        while (nuevas.next()) {
            const int id = nuevas.value(0).toInt();
            const QString tipo = nuevas.value(1).toString();
            m_ultimoIdVisto = qMax(m_ultimoIdVisto, id);
            for (auto it = m_clientes.begin(); it != m_clientes.end(); ++it) {
                const QString &rol = it->rol;
                const bool leToca = it->idUsuario > 0
                    && ((rol != QLatin1String("limpieza") && rol != QLatin1String("mantenimiento"))
                        || rol == tipo);
                if (leToca) {
                    enviar(it.key(), QJsonObject{
                        {QStringLiteral("tipo"), QStringLiteral("nueva")},
                        {QStringLiteral("id"), id},
                        {QStringLiteral("tipoSolicitud"), tipo},
                        {QStringLiteral("habitacion"), nuevas.value(3).toString()},
                        {QStringLiteral("prioridad"), nuevas.value(2).toString()}});
                }
            }
        }
    }

    // 2) Lista actualizada solo a quien le cambio.
    const auto sockets = m_clientes.keys();
    for (QTcpSocket *socket : sockets) {
        enviarLista(socket, false);
    }
}
