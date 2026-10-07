#include "Reserva.h"

#include <QDate>
#include <QDebug>
#include <QSqlError>
#include <QSqlQuery>

Reserva::Reserva(QObject *parent)
    : QObject(parent)
{
}

bool Reserva::fechasValidas(const QString &fechaEntrada,
                             const QString &fechaSalida,
                             QString *motivoError) const
{
    const QDate entrada = QDate::fromString(fechaEntrada, QStringLiteral("yyyy-MM-dd"));
    const QDate salida = QDate::fromString(fechaSalida, QStringLiteral("yyyy-MM-dd"));

    if (!entrada.isValid() || !salida.isValid()) {
        if (motivoError) {
            *motivoError = QStringLiteral("Las fechas deben tener formato AAAA-MM-DD.");
        }
        return false;
    }

    if (salida <= entrada) {
        if (motivoError) {
            *motivoError = QStringLiteral("La fecha de salida debe ser posterior a la de entrada.");
        }
        return false;
    }

    return true;
}

bool Reserva::habitacionDisponible(int idHabitacion,
                                    const QString &fechaEntrada,
                                    const QString &fechaSalida)
{
    // Misma condicion de traslape que usan los triggers de la BD
    // (trg_validar_traslape_insert / _update), pero consultada desde
    // C++ para poder avisar al usuario ANTES de intentar el INSERT.
    QSqlQuery query;
    query.prepare(QStringLiteral(
        "SELECT COUNT(*) FROM Reserva "
        "WHERE id_habitacion = :idHabitacion "
        "  AND estado_reserva = 'confirmada' "
        "  AND :entrada < fecha_salida "
        "  AND :salida > fecha_entrada"));
    query.bindValue(":idHabitacion", idHabitacion);
    query.bindValue(":entrada", fechaEntrada);
    query.bindValue(":salida", fechaSalida);

    if (!query.exec()) {
        qWarning() << "No se pudo consultar disponibilidad:" << query.lastError().text();
        // Ante la duda (no se pudo ni siquiera preguntar), se reporta
        // como NO disponible: es la opcion segura, para no dejar pasar
        // una reserva sin haber podido verificarla.
        return false;
    }

    query.next();
    const int reservasEnTraslape = query.value(0).toInt();
    return reservasEnTraslape == 0;
}

bool Reserva::crearReserva(int idHuesped,
                            int idHabitacion,
                            const QString &fechaEntrada,
                            const QString &fechaSalida)
{
    QString motivoError;

    if (!fechasValidas(fechaEntrada, fechaSalida, &motivoError)) {
        emit reservaRechazada(motivoError);
        return false;
    }

    if (!habitacionDisponible(idHabitacion, fechaEntrada, fechaSalida)) {
        emit reservaRechazada(QStringLiteral(
            "La habitacion ya tiene una reserva confirmada en esas fechas."));
        return false;
    }

    QSqlQuery query;
    query.prepare(QStringLiteral(
        "INSERT INTO Reserva (id_huesped, id_habitacion, fecha_entrada, fecha_salida) "
        "VALUES (:idHuesped, :idHabitacion, :entrada, :salida)"));
    query.bindValue(":idHuesped", idHuesped);
    query.bindValue(":idHabitacion", idHabitacion);
    query.bindValue(":entrada", fechaEntrada);
    query.bindValue(":salida", fechaSalida);

    if (!query.exec()) {
        // Red de seguridad: si por una condicion de carrera otra
        // reserva se inserto justo entre la validacion de arriba y
        // este INSERT, el trigger trg_validar_traslape_insert de la
        // base de datos aborta esta sentencia y cae aqui.
        qWarning() << "No se pudo crear la reserva:" << query.lastError().text();
        emit reservaRechazada(query.lastError().text());
        return false;
    }

    const int idReserva = query.lastInsertId().toInt();
    emit reservaCreada(idReserva);
    return true;
}
