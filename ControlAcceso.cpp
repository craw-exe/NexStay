#include "ControlAcceso.h"

#include <QDebug>
#include <QSqlError>
#include <QSqlQuery>
#include <QVariant>

ControlAcceso::ControlAcceso(QObject *parent)
    : QObject(parent)
{
}

bool ControlAcceso::tienePermiso(const QString &modulo, const QString &accion)
{
    // Se consulta Sesion_Actual directamente (en vez de pedirle el
    // dato al singleton Sesion desde C++) porque esa fila es la misma
    // fuente de verdad que ya usa el trigger trg_actualizar_historial
    // del Sprint 2: cualquier clase que necesite "quien esta
    // logueado ahora" lee de ahi, sin acoplarse a otra clase C++.
    QSqlQuery query;
    query.prepare(QStringLiteral(
        "SELECT COUNT(*) FROM Permisos p "
        "JOIN Usuario u ON u.id_rol = p.id_rol "
        "JOIN Sesion_Actual s ON s.id_usuario = u.id_usuario "
        "WHERE s.id = 1 AND u.estado = 'activo' "
        "  AND p.modulo = :modulo AND p.accion_permitida = :accion"));
    query.bindValue(":modulo", modulo);
    query.bindValue(":accion", accion);

    if (!query.exec() || !query.next()) {
        qWarning() << "No se pudo verificar el permiso:" << query.lastError().text();
        return false;
    }

    return query.value(0).toInt() > 0;
}

int ControlAcceso::registrarIntento(int idUsuario, int idHuesped, int idHabitacion,
                                     const QString &rolUsado)
{
    QSqlQuery query;
    query.prepare(QStringLiteral(
        "INSERT INTO Bitacora_acceso (id_usuario, id_huesped, id_habitacion, rol_usado, tipo_evento) "
        "VALUES (:idUsuario, :idHuesped, :idHabitacion, :rolUsado, 'entrada')"));

    if (idUsuario >= 0) {
        query.bindValue(":idUsuario", idUsuario);
    } else {
        query.bindValue(":idUsuario", QVariant(QMetaType(QMetaType::Int)));
    }
    if (idHuesped >= 0) {
        query.bindValue(":idHuesped", idHuesped);
    } else {
        query.bindValue(":idHuesped", QVariant(QMetaType(QMetaType::Int)));
    }
    query.bindValue(":idHabitacion", idHabitacion);
    query.bindValue(":rolUsado", rolUsado);

    if (!query.exec()) {
        qWarning() << "No se pudo registrar el intento de acceso:" << query.lastError().text();
        return -1;
    }

    return query.lastInsertId().toInt();
}

bool ControlAcceso::accesoFueConcedido(int idRegistro)
{
    QSqlQuery query;
    query.prepare(QStringLiteral(
        "SELECT tipo_evento FROM Bitacora_acceso WHERE id_registro = :id"));
    query.bindValue(":id", idRegistro);

    if (!query.exec() || !query.next()) {
        qWarning() << "No se pudo releer el registro de acceso:" << query.lastError().text();
        return false; // Ante la duda, se reporta como NO concedido.
    }

    // Los triggers trg_forzar_intento_fallido_usuario / _huesped ya
    // corrieron en cuanto se hizo el INSERT (son AFTER INSERT): si no
    // tenia permiso, ya cambiaron esta misma fila a 'intento_fallido'
    // antes de que esta consulta se ejecute.
    return query.value("tipo_evento").toString() == QStringLiteral("entrada");
}

bool ControlAcceso::intentarAccesoPersonal(int idHabitacion)
{
    QSqlQuery sesion;
    sesion.exec(QStringLiteral(
        "SELECT u.id_usuario, r.nombre AS rol "
        "FROM Sesion_Actual s "
        "JOIN Usuario u ON u.id_usuario = s.id_usuario "
        "JOIN Rol r ON r.id_rol = u.id_rol "
        "WHERE s.id = 1"));

    if (!sesion.next()) {
        emit accesoDenegado(QStringLiteral("personal"), idHabitacion,
                             QStringLiteral("No hay sesión activa."));
        return false;
    }

    const int idUsuario = sesion.value("id_usuario").toInt();
    const QString rol = sesion.value("rol").toString();

    const int idRegistro = registrarIntento(idUsuario, -1, idHabitacion, rol);
    if (idRegistro < 0) {
        emit accesoDenegado(QStringLiteral("personal"), idHabitacion,
                             QStringLiteral("No se pudo registrar el intento de acceso."));
        return false;
    }

    if (accesoFueConcedido(idRegistro)) {
        emit accesoConcedido(QStringLiteral("personal"), idHabitacion);
        return true;
    }

    emit accesoDenegado(QStringLiteral("personal"), idHabitacion,
                         QStringLiteral("Tu rol no tiene permiso para entrar a esta habitación."));
    return false;
}

bool ControlAcceso::intentarAccesoHuesped(int idHuesped, int idHabitacion)
{
    // Los huespedes no tienen fila en Usuario/Rol, asi que rol_usado
    // es un texto libre fijo ("huesped"), no una referencia a Rol.
    const int idRegistro = registrarIntento(-1, idHuesped, idHabitacion, QStringLiteral("huesped"));
    if (idRegistro < 0) {
        emit accesoDenegado(QStringLiteral("huesped"), idHabitacion,
                             QStringLiteral("No se pudo registrar el intento de acceso."));
        return false;
    }

    if (accesoFueConcedido(idRegistro)) {
        emit accesoConcedido(QStringLiteral("huesped"), idHabitacion);
        return true;
    }

    emit accesoDenegado(QStringLiteral("huesped"), idHabitacion,
                         QStringLiteral("No tienes una estadía activa registrada en esta habitación."));
    return false;
}
