#include "ListaHabitaciones.h"

#include <QDebug>
#include <QSqlError>
#include <QSqlQuery>

ListaHabitaciones::ListaHabitaciones(QObject *parent)
    : QObject(parent)
{
}

bool ListaHabitaciones::puedeVer()
{
    QSqlQuery query;
    query.exec(QStringLiteral(
        "SELECT 1 "
        "FROM Sesion_Actual s "
        "JOIN Usuario u ON u.id_usuario = s.id_usuario AND u.estado = 'activo' "
        "JOIN Permisos p ON p.id_rol = u.id_rol "
        "WHERE s.id = 1 AND p.modulo = 'habitaciones' AND p.accion_permitida = 'ver'"));

    return query.next(); // false tambien si no hay sesion activa.
}

QVariantList ListaHabitaciones::habitaciones()
{
    QVariantList resultado;

    // La reserva "de hoy" es la confirmada cuya estancia incluye la fecha
    // actual (el dia de salida ya no cuenta, igual que en el calendario).
    QSqlQuery query;
    if (!query.exec(QStringLiteral(
            "SELECT h.numero, h.piso, h.tipo, h.capacidad, h.estado_actual, "
            "  COALESCE(g.nombre || ' ' || g.apellido, '') AS huesped, "
            "  COALESCE(date(r.fecha_salida), '') AS salida "
            "FROM Habitacion h "
            "LEFT JOIN Reserva r ON r.id_reserva = ("
            "  SELECT r2.id_reserva FROM Reserva r2 "
            "  WHERE r2.id_habitacion = h.id_habitacion "
            "    AND r2.estado_reserva = 'confirmada' "
            "    AND date(r2.fecha_entrada) <= date('now','localtime') "
            "    AND date(r2.fecha_salida) > date('now','localtime') "
            "  ORDER BY r2.fecha_entrada LIMIT 1) "
            "LEFT JOIN Huesped g ON g.id_huesped = r.id_huesped "
            "ORDER BY h.piso, CAST(h.numero AS INTEGER), h.numero"))) {
        qWarning() << "ListaHabitaciones: no se pudieron leer las habitaciones:" << query.lastError().text();
        return resultado;
    }

    while (query.next()) {
        QVariantMap fila;
        fila[QStringLiteral("numero")] = query.value("numero").toString();
        fila[QStringLiteral("piso")] = query.value("piso").toInt();
        fila[QStringLiteral("tipo")] = query.value("tipo").toString();
        fila[QStringLiteral("capacidad")] = query.value("capacidad").toInt();
        fila[QStringLiteral("estado")] = query.value("estado_actual").toString();
        fila[QStringLiteral("huesped")] = query.value("huesped").toString();
        fila[QStringLiteral("salida")] = query.value("salida").toString();
        resultado.append(fila);
    }
    return resultado;
}
