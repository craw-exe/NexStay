#include "ConexionHotel.h"

#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QSettings>


ConexionHotel::ConexionHotel(QObject *parent)
    : QObject(parent)
{
    m_servidor = QSettings(QStringLiteral("Nexora"), QStringLiteral("NexStay"))
                     .value(QStringLiteral("movil/servidor")).toString();

    connect(&m_socket, &QTcpSocket::connected, this, [this]() {
        m_tiempoLimite.stop();
        enviar(QJsonObject{
            {QStringLiteral("cmd"), QStringLiteral("login")},
            {QStringLiteral("correo"), m_correo},
            {QStringLiteral("contrasena"), m_contrasena}});
    });
    connect(&m_socket, &QTcpSocket::readyRead, this, &ConexionHotel::leer);
    connect(&m_socket, &QTcpSocket::disconnected, this, &ConexionHotel::perdida);
    connect(&m_socket, &QTcpSocket::errorOccurred, this, [this]() {
        if (m_socket.state() != QAbstractSocket::ConnectedState) {
            perdida();
        }
    });

    // Si en 6 segundos no responde la PC, se da por fallido el intento.
    m_tiempoLimite.setSingleShot(true);
    m_tiempoLimite.setInterval(6000);
    connect(&m_tiempoLimite, &QTimer::timeout, this, [this]() { m_socket.abort(); perdida(); });

    m_reintento.setSingleShot(true);
    m_reintento.setInterval(3000);
    connect(&m_reintento, &QTimer::timeout, this, &ConexionHotel::abrirSocket);
}

QString ConexionHotel::correoGuardado() const
{
    return QSettings(QStringLiteral("Nexora"), QStringLiteral("NexStay"))
        .value(QStringLiteral("movil/correo")).toString();
}

void ConexionHotel::ponerEstado(const QString &estado)
{
    if (m_estado != estado) {
        m_estado = estado;
        emit estadoCambio();
    }
}

void ConexionHotel::conectar(const QString &servidor, const QString &correo,
                             const QString &contrasena)
{
    QString host = servidor.trimmed();
    m_puerto = 5150;
    const int dosPuntos = host.lastIndexOf(QLatin1Char(':'));
    if (dosPuntos > 0) {
        m_puerto = host.mid(dosPuntos + 1).toUShort();
        host = host.left(dosPuntos);
    }
    if (host.isEmpty() || correo.trimmed().isEmpty() || contrasena.isEmpty()) {
        emit error(tr("Escribe la IP del hotel, tu correo y tu contraseña."));
        return;
    }

    m_servidor = host;
    m_correo = correo.trimmed();
    m_contrasena = contrasena;
    m_quiereConexion = true;
    m_sesionValida = false;

    QSettings guardar(QStringLiteral("Nexora"), QStringLiteral("NexStay"));
    guardar.setValue(QStringLiteral("movil/servidor"), servidor.trimmed());
    guardar.setValue(QStringLiteral("movil/correo"), m_correo);

    abrirSocket();
}

void ConexionHotel::abrirSocket()
{
    if (!m_quiereConexion) {
        return;
    }
    ponerEstado(QStringLiteral("conectando"));
    m_pendiente.clear();
    m_socket.abort();
    m_socket.connectToHost(m_servidor, m_puerto);
    m_tiempoLimite.start();
}

void ConexionHotel::desconectar()
{
    m_quiereConexion = false;
    m_sesionValida = false;
    m_contrasena.clear();
    m_reintento.stop();
    m_tiempoLimite.stop();
    m_socket.abort();
    m_idUsuario = -1;
    m_solicitudes.clear();
    emit solicitudesCambiaron();
    ponerEstado(QStringLiteral("desconectado"));
}

void ConexionHotel::perdida()
{
    m_tiempoLimite.stop();
    if (!m_quiereConexion) {
        return;
    }
    if (m_sesionValida) {
        // Ya habia entrado: se corto el WiFi o se cerro la PC. Reintenta.
        ponerEstado(QStringLiteral("conectando"));
        if (!m_reintento.isActive()) {
            m_reintento.start();
        }
        return;
    }
    // Primer intento fallido: probablemente la IP esta mal.
    m_quiereConexion = false;
    ponerEstado(QStringLiteral("desconectado"));
    emit error(tr("No se pudo conectar con el hotel. Revisa la IP y que estés en el mismo WiFi."));
}

void ConexionHotel::enviar(const QJsonObject &mensaje)
{
    m_socket.write(QJsonDocument(mensaje).toJson(QJsonDocument::Compact) + '\n');
}

void ConexionHotel::tomar(int idSolicitud)
{
    enviar(QJsonObject{{QStringLiteral("cmd"), QStringLiteral("tomar")},
                       {QStringLiteral("id"), idSolicitud}});
}

void ConexionHotel::atender(int idSolicitud)
{
    enviar(QJsonObject{{QStringLiteral("cmd"), QStringLiteral("atender")},
                       {QStringLiteral("id"), idSolicitud}});
}

void ConexionHotel::leer()
{
    m_pendiente += m_socket.readAll();
    int fin;
    while ((fin = m_pendiente.indexOf('\n')) >= 0) {
        const QJsonDocument doc = QJsonDocument::fromJson(m_pendiente.left(fin));
        m_pendiente.remove(0, fin + 1);
        if (doc.isObject()) {
            procesar(doc.object());
        }
    }
}

void ConexionHotel::procesar(const QJsonObject &mensaje)
{
    const QString tipo = mensaje.value(QStringLiteral("tipo")).toString();

    if (tipo == QLatin1String("login")) {
        if (!mensaje.value(QStringLiteral("ok")).toBool()) {
            m_quiereConexion = false;
            m_sesionValida = false;
            m_socket.abort();
            ponerEstado(QStringLiteral("desconectado"));
            emit error(mensaje.value(QStringLiteral("motivo")).toString());
            return;
        }
        m_sesionValida = true;
        m_idUsuario = mensaje.value(QStringLiteral("idUsuario")).toInt();
        m_nombre = mensaje.value(QStringLiteral("nombre")).toString();
        m_rol = mensaje.value(QStringLiteral("rol")).toString();
        m_puedeAtender = mensaje.value(QStringLiteral("puedeAtender")).toBool();
        m_estado.clear();   // fuerza el aviso aunque ya dijera "conectado"
        ponerEstado(QStringLiteral("conectado"));
    } else if (tipo == QLatin1String("lista")) {
        m_solicitudes = mensaje.value(QStringLiteral("solicitudes")).toArray().toVariantList();
        emit solicitudesCambiaron();
    } else if (tipo == QLatin1String("nueva")) {
        emit nuevaSolicitud(mensaje.value(QStringLiteral("id")).toInt(),
                            mensaje.value(QStringLiteral("tipoSolicitud")).toString(),
                            mensaje.value(QStringLiteral("habitacion")).toString(),
                            mensaje.value(QStringLiteral("prioridad")).toString());
    } else if (tipo == QLatin1String("resultado")) {
        if (mensaje.value(QStringLiteral("ok")).toBool()) {
            emit aviso(mensaje.value(QStringLiteral("mensaje")).toString());
        } else {
            emit error(mensaje.value(QStringLiteral("motivo")).toString());
        }
    }
}
