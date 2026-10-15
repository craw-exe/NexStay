#include "BitacoraAcceso.h"

#include <QDebug>
#include <QSqlError>
#include <QSqlQuery>
#include <QVariantMap>

BitacoraAcceso::BitacoraAcceso(QObject *parent)
    : QObject(parent)
{
}

bool BitacoraAcceso::puedeVerBitacora()
{
    QSqlQuery query;
    query.exec(QStringLiteral(
        "SELECT r.nombre AS rol "
        "FROM Sesion_Actual s "
        "JOIN Usuario u ON u.id_usuario = s.id_usuario "
        "JOIN Rol r ON r.id_rol = u.id_rol "
        "WHERE s.id = 1"));

    if (!query.next()) {
        return false; // No hay sesion activa.
    }

    return query.value("rol").toString() == QStringLiteral("administrador");
}

QVariantList BitacoraAcceso::registros(int idHabitacion, int limite)
{
    QVariantList resultado;

    // El actor puede ser un Usuario (personal) o un Huesped, nunca
    // ambos (CHECK "un_solo_actor" de la tabla): se resuelve el nombre
    // de quien corresponda con dos LEFT JOIN y un CASE, para no tener
    // que hacer esa logica en QML.
    QString sql = QStringLiteral(
        "SELECT b.id_registro, b.fecha_hora, b.tipo_evento, b.rol_usado, "
        "       h.numero AS numero_habitacion, "
        "       CASE WHEN b.id_usuario IS NOT NULL THEN 'personal' ELSE 'huesped' END AS tipo_actor, "
        "       CASE "
        "           WHEN b.id_usuario IS NOT NULL THEN u.nombre || ' ' || u.apellido "
        "           ELSE hu.nombre || ' ' || hu.apellido "
        "       END AS actor "
        "FROM Bitacora_acceso b "
        "JOIN Habitacion h ON h.id_habitacion = b.id_habitacion "
        "LEFT JOIN Usuario u ON u.id_usuario = b.id_usuario "
        "LEFT JOIN Huesped hu ON hu.id_huesped = b.id_huesped ");

    if (idHabitacion >= 0) {
        sql += QStringLiteral("WHERE b.id_habitacion = :idHabitacion ");
    }
    sql += QStringLiteral("ORDER BY b.fecha_hora DESC, b.id_registro DESC LIMIT :limite");

    QSqlQuery query;
    query.prepare(sql);
    if (idHabitacion >= 0) {
        query.bindValue(":idHabitacion", idHabitacion);
    }
    query.bindValue(":limite", limite);

    if (!query.exec()) {
        qWarning() << "No se pudo leer Bitacora_acceso:" << query.lastError().text();
        return resultado;
    }

    while (query.next()) {
        QVariantMap fila;
        fila[QStringLiteral("idRegistro")] = query.value("id_registro").toInt();
        fila[QStringLiteral("fechaHora")] = query.value("fecha_hora").toString();
        fila[QStringLiteral("numeroHabitacion")] = query.value("numero_habitacion").toString();
        fila[QStringLiteral("actor")] = query.value("actor").toString();
        fila[QStringLiteral("tipoActor")] = query.value("tipo_actor").toString();
        fila[QStringLiteral("rolUsado")] = query.value("rol_usado").toString();
        fila[QStringLiteral("tipoEvento")] = query.value("tipo_evento").toString();
        resultado.append(fila);
    }

    return resultado;
}
