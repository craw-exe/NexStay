#include "Sesion.h"

#include <QCryptographicHash>
#include <QMessageAuthenticationCode>
#include <QRandomGenerator>
#include <QDebug>
#include <QSqlError>
#include <QSqlQuery>
#include <QStringList>
#include <QVariant>

Sesion::Sesion(QObject *parent)
    : QObject(parent)
{
}

namespace {
    constexpr int kVueltasPbkdf2 = 100000;
    const QString kPrefijo = QStringLiteral("pbkdf2$");

    QString sha256Antiguo(const QString &contrasenaPlano)
    {
        return QString::fromLatin1(QCryptographicHash::hash(
            contrasenaPlano.toUtf8(), QCryptographicHash::Sha256).toHex());
    }

    // Compara sin salir antes de tiempo, para no dar pistas por cuanto tarda.
    bool igualesTiempoConstante(const QByteArray &a, const QByteArray &b)
    {
        if (a.size() != b.size()) {
            return false;
        }
        char diferencia = 0;
        for (qsizetype i = 0; i < a.size(); ++i) {
            diferencia |= char(a[i] ^ b[i]);
        }
        return diferencia == 0;
    }
}

QByteArray Sesion::pbkdf2Sha256(const QByteArray &contrasena, const QByteArray &sal, int vueltas)
{
    // Un solo bloque basta porque se piden 32 bytes (lo que mide SHA-256).
    QMessageAuthenticationCode mac(QCryptographicHash::Sha256, contrasena);
    mac.addData(sal);
    mac.addData(QByteArray("\0\0\0\1", 4)); // numero de bloque (1)
    QByteArray u = mac.result();
    QByteArray resultado = u;
    for (int i = 1; i < vueltas; ++i) {
        mac.reset();
        mac.addData(u);
        u = mac.result();
        for (qsizetype j = 0; j < resultado.size(); ++j) {
            resultado[j] = char(resultado[j] ^ u[j]);
        }
    }
    return resultado;
}

QString Sesion::hashContrasena(const QString &contrasenaPlano)
{
    QByteArray sal(16, Qt::Uninitialized);
    QRandomGenerator::system()->fillRange(reinterpret_cast<quint32 *>(sal.data()), sal.size() / 4);
    const QByteArray hash = pbkdf2Sha256(contrasenaPlano.toUtf8(), sal, kVueltasPbkdf2);
    return kPrefijo + QString::number(kVueltasPbkdf2) + QLatin1Char('$')
           + QString::fromLatin1(sal.toHex()) + QLatin1Char('$')
           + QString::fromLatin1(hash.toHex());
}

bool Sesion::esHashAntiguo(const QString &guardado)
{
    return !guardado.startsWith(kPrefijo);
}

bool Sesion::verificarContrasena(const QString &contrasenaPlano, const QString &guardado)
{
    if (esHashAntiguo(guardado)) {
        return igualesTiempoConstante(sha256Antiguo(contrasenaPlano).toLatin1(), guardado.toLatin1());
    }
    const QStringList partes = guardado.split(QLatin1Char('$'));
    if (partes.size() != 4) {
        return false;
    }
    bool ok = false;
    const int vueltas = partes[1].toInt(&ok);
    if (!ok || vueltas < 1) {
        return false;
    }
    const QByteArray sal = QByteArray::fromHex(partes[2].toLatin1());
    const QByteArray esperado = QByteArray::fromHex(partes[3].toLatin1());
    return igualesTiempoConstante(pbkdf2Sha256(contrasenaPlano.toUtf8(), sal, vueltas), esperado);
}

bool Sesion::registrarFallo(const QString &correo)
{
    Intentos &i = m_intentos[correo];
    i.fallos++;
    if (i.fallos >= kMaxIntentos) {
        i.bloqueadoHasta = QDateTime::currentDateTime().addSecs(kMinutosBloqueo * 60);
        i.fallos = 0;
        return true;
    }
    return false;
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
    const QString correoNormal = correo.trimmed().toLower();
    const auto bloqueo = m_intentos.value(correoNormal).bloqueadoHasta;
    if (bloqueo.isValid() && bloqueo > QDateTime::currentDateTime()) {
        const qint64 minutos = (QDateTime::currentDateTime().secsTo(bloqueo) + 59) / 60;
        emit sesionRechazada(QStringLiteral(
            "Demasiados intentos fallidos. Intenta de nuevo en %1 minuto(s).").arg(minutos));
        return false;
    }

    QSqlQuery query;
    query.prepare(QStringLiteral(
        "SELECT id_usuario, contrasena FROM Usuario "
        "WHERE correo = :correo COLLATE NOCASE AND estado = 'activo'"));
    query.bindValue(":correo", correoNormal);

    if (!query.exec()) {
        qWarning() << "No se pudo consultar Usuario para login:" << query.lastError().text();
        emit sesionRechazada(QStringLiteral("No se pudo validar las credenciales. Intenta de nuevo."));
        return false;
    }

    // Correo inexistente, usuario inactivo o contrasena incorrecta dan el
    // MISMO mensaje, para no revelar cual de los datos fallo.
    const bool encontrado = query.next();
    const QString hashGuardado = encontrado ? query.value("contrasena").toString() : QString();
    if (!encontrado || !verificarContrasena(contrasena, hashGuardado)) {
        if (registrarFallo(correoNormal)) {
            emit sesionRechazada(QStringLiteral(
                "Demasiados intentos fallidos. Intenta de nuevo en %1 minutos.").arg(kMinutosBloqueo));
        } else {
            emit sesionRechazada(QStringLiteral("Correo o contraseña incorrectos."));
        }
        return false;
    }
    m_intentos.remove(correoNormal);

    const int idUsuario = query.value("id_usuario").toInt();
    query.finish(); // libera la lectura de Usuario antes de actualizarlo

    // Migracion: el hash viejo (SHA-256 sin sal) se cambia por el nuevo.
    if (esHashAntiguo(hashGuardado)) {
        QSqlQuery migrar;
        migrar.prepare(QStringLiteral("UPDATE Usuario SET contrasena = :h WHERE id_usuario = :id"));
        migrar.bindValue(":h", hashContrasena(contrasena));
        migrar.bindValue(":id", idUsuario);
        if (!migrar.exec()) {
            qWarning() << "No se pudo actualizar el hash de la contrasena:" << migrar.lastError().text();
        }
    }

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
    // Theme 10: ya no se entra solo con la sesion anterior; se limpia
    // para que el historial no le atribuya cambios a quien ya no esta.
    cerrarSesion();
}
