#include "CalendarioReservas.h"

#include <QDate>
#include <QDebug>
#include <QSqlError>
#include <QSqlQuery>
#include <QVariantMap>

CalendarioReservas::CalendarioReservas(QObject *parent)
    : QObject(parent)
{
}

QString CalendarioReservas::hoy() const
{
    return QDate::currentDate().toString(QStringLiteral("yyyy-MM-dd"));
}

QStringList CalendarioReservas::rangoFechas(const QString &fechaInicio, int dias) const
{
    QStringList resultado;

    const QDate inicio = QDate::fromString(fechaInicio, QStringLiteral("yyyy-MM-dd"));
    if (!inicio.isValid() || dias <= 0) {
        return resultado;
    }

    for (int i = 0; i < dias; ++i) {
        resultado << inicio.addDays(i).toString(QStringLiteral("yyyy-MM-dd"));
    }

    return resultado;
}

QString CalendarioReservas::sumarDias(const QString &fecha, int dias) const
{
    const QDate base = QDate::fromString(fecha, QStringLiteral("yyyy-MM-dd"));
    if (!base.isValid()) {
        return QString();
    }
    return base.addDays(dias).toString(QStringLiteral("yyyy-MM-dd"));
}

QVariantList CalendarioReservas::habitaciones()
{
    QVariantList resultado;

    QSqlQuery query;
    query.prepare(QStringLiteral(
        "SELECT id_habitacion, numero, tipo FROM Habitacion ORDER BY numero"));

    if (!query.exec()) {
        qWarning() << "No se pudo leer Habitacion para el calendario:" << query.lastError().text();
        return resultado;
    }

    while (query.next()) {
        QVariantMap fila;
        fila[QStringLiteral("idHabitacion")] = query.value("id_habitacion").toInt();
        fila[QStringLiteral("numero")] = query.value("numero").toString();
        fila[QStringLiteral("tipo")] = query.value("tipo").toString();
        resultado.append(fila);
    }

    return resultado;
}

QVariantList CalendarioReservas::reservasEntre(const QString &fechaInicio, const QString &fechaFin)
{
    QVariantList resultado;

    // Misma condicion de traslape que usan Reserva::habitacionDisponible()
    // y los triggers de la BD: una reserva "toca" el rango visible si su
    // entrada es antes de que termine el rango Y su salida es despues de
    // que el rango empieza.
    QSqlQuery query;
    query.prepare(QStringLiteral(
        "SELECT r.id_reserva, r.id_habitacion, r.fecha_entrada, r.fecha_salida, "
        "       hu.nombre, hu.apellido "
        "FROM Reserva r "
        "JOIN Huesped hu ON hu.id_huesped = r.id_huesped "
        "WHERE r.estado_reserva = 'confirmada' "
        "  AND r.fecha_entrada < :fin "
        "  AND r.fecha_salida > :inicio "
        "ORDER BY r.id_habitacion, r.fecha_entrada"));
    query.bindValue(":inicio", fechaInicio);
    query.bindValue(":fin", fechaFin);

    if (!query.exec()) {
        qWarning() << "No se pudo leer Reserva para el calendario:" << query.lastError().text();
        return resultado;
    }

    while (query.next()) {
        QVariantMap fila;
        fila[QStringLiteral("idReserva")] = query.value("id_reserva").toInt();
        fila[QStringLiteral("idHabitacion")] = query.value("id_habitacion").toInt();
        fila[QStringLiteral("fechaEntrada")] = query.value("fecha_entrada").toString();
        fila[QStringLiteral("fechaSalida")] = query.value("fecha_salida").toString();
        fila[QStringLiteral("nombreHuesped")] =
            query.value("nombre").toString() + QStringLiteral(" ") + query.value("apellido").toString();
        resultado.append(fila);
    }

    return resultado;
}
