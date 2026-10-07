#include "HistorialEstadia.h"

#include <QDebug>
#include <QSqlError>
#include <QSqlQuery>
#include <QVariantMap>

HistorialEstadia::HistorialEstadia(QObject *parent)
    : QObject(parent)
{
}

bool HistorialEstadia::tieneEstadiaAbierta(int idHuesped, int idHabitacion)
{
    QSqlQuery query;
    query.prepare(QStringLiteral(
        "SELECT COUNT(*) FROM Historial_Estadia "
        "WHERE id_huesped = :idHuesped "
        "  AND id_habitacion = :idHabitacion "
        "  AND fecha_salida_real IS NULL"));
    query.bindValue(":idHuesped", idHuesped);
    query.bindValue(":idHabitacion", idHabitacion);

    if (!query.exec() || !query.next()) {
        qWarning() << "No se pudo verificar estadia abierta:" << query.lastError().text();
        // Ante la duda, se asume que SI hay una abierta (opcion segura):
        // evita crear un duplicado si la consulta fallo por cualquier motivo.
        return true;
    }

    return query.value(0).toInt() > 0;
}

int HistorialEstadia::registrarCheckIn(int idHuesped, int idHabitacion, int idReserva)
{
    if (tieneEstadiaAbierta(idHuesped, idHabitacion)) {
        emit operacionRechazada(QStringLiteral(
            "Este huesped ya tiene una estadia abierta en esa habitacion."));
        return -1;
    }

    QSqlQuery query;
    query.prepare(QStringLiteral(
        "INSERT INTO Historial_Estadia (id_reserva, id_huesped, id_habitacion, fecha_entrada_real) "
        "VALUES (:idReserva, :idHuesped, :idHabitacion, datetime('now','localtime'))"));

    if (idReserva >= 0) {
        query.bindValue(":idReserva", idReserva);
    } else {
        query.bindValue(":idReserva", QVariant(QMetaType(QMetaType::Int)));
    }
    query.bindValue(":idHuesped", idHuesped);
    query.bindValue(":idHabitacion", idHabitacion);

    if (!query.exec()) {
        qWarning() << "No se pudo registrar el check-in:" << query.lastError().text();
        emit operacionRechazada(query.lastError().text());
        return -1;
    }

    const int idEstadia = query.lastInsertId().toInt();
    emit checkInRegistrado(idEstadia);
    return idEstadia;
}

bool HistorialEstadia::registrarCheckOut(int idEstadia)
{
    QSqlQuery query;
    query.prepare(QStringLiteral(
        "UPDATE Historial_Estadia "
        "SET fecha_salida_real = datetime('now','localtime') "
        "WHERE id_estadia = :idEstadia AND fecha_salida_real IS NULL"));
    query.bindValue(":idEstadia", idEstadia);

    if (!query.exec()) {
        qWarning() << "No se pudo registrar el check-out:" << query.lastError().text();
        emit operacionRechazada(query.lastError().text());
        return false;
    }

    if (query.numRowsAffected() == 0) {
        emit operacionRechazada(QStringLiteral(
            "Esa estadia no existe o ya tiene check-out registrado."));
        return false;
    }

    emit checkOutRegistrado(idEstadia);
    return true;
}

QVariantList HistorialEstadia::historialPorHuesped(int idHuesped)
{
    QVariantList resultado;

    QSqlQuery query;
    query.prepare(QStringLiteral(
        "SELECT he.id_estadia, he.id_habitacion, h.numero, "
        "       he.fecha_entrada_real, he.fecha_salida_real "
        "FROM Historial_Estadia he "
        "JOIN Habitacion h ON h.id_habitacion = he.id_habitacion "
        "WHERE he.id_huesped = :idHuesped "
        "ORDER BY he.fecha_entrada_real DESC"));
    query.bindValue(":idHuesped", idHuesped);

    if (!query.exec()) {
        qWarning() << "No se pudo leer el historial de estadias:" << query.lastError().text();
        return resultado;
    }

    while (query.next()) {
        QVariantMap fila;
        fila[QStringLiteral("idEstadia")] = query.value("id_estadia").toInt();
        fila[QStringLiteral("idHabitacion")] = query.value("id_habitacion").toInt();
        fila[QStringLiteral("numeroHabitacion")] = query.value("numero").toString();
        fila[QStringLiteral("fechaEntradaReal")] = query.value("fecha_entrada_real").toString();
        fila[QStringLiteral("fechaSalidaReal")] =
            query.value("fecha_salida_real").isNull()
                ? QString()
                : query.value("fecha_salida_real").toString();
        resultado.append(fila);
    }

    return resultado;
}
