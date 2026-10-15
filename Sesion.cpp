#include "Sesion.h"

#include <QCryptographicHash>
#include <QDebug>
#include <QSqlError>
#include <QSqlQuery>
#include <QVariant>

Sesion::Sesion(QObject *parent)
    : QObject(parent)
{
}

QString Sesion::hashContrasena(const QString &contrasenaPlano)
{
    const QByteArray hash = QCryptographicHash::hash(
        contrasenaPlano.toUtf8(), QCryptographicHash::Sha256);
    return QString::fromLatin1(hash.toHex());
}

bool Sesion::haySesion() const
{
    return m_idUsuario >= 0;
}

int Sesion::idUsuario() const
{
    return m_idUsuario;
}

QString Sesion::nombreCompleto() const
{
    return m_nombreCompleto;
}

QString Sesion::correo() const
{
    return m_correo;
}

QString Sesion::nombreRol() const
{
    return m_nombreRol;
}

void Sesion::limpiarSesion()
{
    m_idUsuario = -1;
    m_nombreCompleto.clear();
    m_correo.clear();
    m_nombreRol.clear();
}

bool Sesion::cargarUsuarioPorId(int idUsuario)
{
    QSqlQuery query;
    query.prepare(QStringLiteral(
        "SELECT u.id_usuario, u.nombre, u.apellido, u.correo, r.nombre AS rol "
        "FROM Usuario u "
        "JOIN Rol r ON r.id_rol = u.id_rol "
        "WHERE u.id_usuario = :id AND u.estado = 'activo'"));
    query.bindValue(":id", idUsuario);

    if (!query.exec() || !query.next()) {
        return false;
    }

    m_idUsuario = query.value("id_usuario").toInt();
    m_nombreCompleto = query.value("nombre").toString()
                        + QStringLiteral(" ")
                        + query.value("apellido").toString();
    m_correo = query.value("correo").toString();
    m_nombreRol = query.value("rol").toString();
    return true;
}

bool Sesion::iniciarSesion(const QString &correo, const QString &contrasena)
{
    QSqlQuery query;
    query.prepare(QStringLiteral(
        "SELECT id_usuario, contrasena FROM Usuario "
        "WHERE correo = :correo AND estado = 'activo'"));
    query.bindValue(":correo", correo.trimmed());

    if (!query.exec()) {
        qWarning() << "No se pudo consultar Usuario para login:" << query.lastError().text();
        emit sesionRechazada(QStringLiteral("No se pudo validar las credenciales. Intenta de nuevo."));
        return false;
    }

    if (!query.next()) {
        // No existe ese correo (o el usuario esta inactivo). Se usa a
        // proposito el MISMO mensaje que cuando la contrasena es
        // incorrecta (ver iniciarSesion mas abajo), para no revelar
        // cual de los dos datos fallo.
        emit sesionRechazada(QStringLiteral("Correo o contraseña incorrectos."));
        return false;
    }

    const QString hashGuardado = query.value("contrasena").toString();
    const QString hashIngresado = hashContrasena(contrasena);

    if (hashGuardado != hashIngresado) {
        emit sesionRechazada(QStringLiteral("Correo o contraseña incorrectos."));
        return false;
    }

    const int idUsuario = query.value("id_usuario").toInt();

    if (!cargarUsuarioPorId(idUsuario)) {
        emit sesionRechazada(QStringLiteral("No se pudo cargar la informacion del usuario."));
        return false;
    }

    QSqlQuery actualizarSesion;
    actualizarSesion.prepare(QStringLiteral(
        "UPDATE Sesion_Actual SET id_usuario = :id WHERE id = 1"));
    actualizarSesion.bindValue(":id", idUsuario);
    if (!actualizarSesion.exec()) {
        qWarning() << "No se pudo actualizar Sesion_Actual:" << actualizarSesion.lastError().text();
        // No se cancela el login por esto: el usuario ya quedo
        // validado y cargado en memoria. Sin esta fila actualizada,
        // el trigger trg_actualizar_historial simplemente registrara
        // id_usuario_que_cambio como NULL en vez del usuario real.
    }

    emit sesionCambio();
    return true;
}

void Sesion::cerrarSesion()
{
    limpiarSesion();

    QSqlQuery query;
    query.prepare(QStringLiteral("UPDATE Sesion_Actual SET id_usuario = NULL WHERE id = 1"));
    if (!query.exec()) {
        qWarning() << "No se pudo limpiar Sesion_Actual:" << query.lastError().text();
    }

    emit sesionCambio();
}

void Sesion::restaurarSesionGuardada()
{
    QSqlQuery query;
    query.exec(QStringLiteral("SELECT id_usuario FROM Sesion_Actual WHERE id = 1"));

    if (!query.next() || query.value("id_usuario").isNull()) {
        return; // No habia sesion previa guardada
    }

    const int idUsuario = query.value("id_usuario").toInt();
    if (cargarUsuarioPorId(idUsuario)) {
        emit sesionCambio();
    }
}
