#include "SolicitudesHuesped.h"

#include <QDebug>
#include <QSqlError>
#include <QSqlQuery>
#include <QStringList>

SolicitudesHuesped::SolicitudesHuesped(QObject *parent)
    : QObject(parent)
{
    cargarDesdeBaseDeDatos();
}

void SolicitudesHuesped::cargarDesdeBaseDeDatos()
{
    // Misma regla que Habitacion::cargarDesdeBaseDeDatos(): por ahora,
    // la primera habitacion de la BD.
    QSqlQuery query;
    if (!query.exec(QStringLiteral(
            "SELECT id_habitacion FROM Habitacion ORDER BY id_habitacion LIMIT 1"))
        || !query.next()) {
        qWarning() << "SolicitudesHuesped: no hay habitaciones en la BD.";
        return;
    }
    m_idHabitacion = query.value("id_habitacion").toInt();

    QSqlQuery presencia;
    presencia.prepare(QStringLiteral(
        "SELECT estado FROM Estado_Presencia WHERE id_habitacion = :id"));
    presencia.bindValue(":id", m_idHabitacion);
    if (presencia.exec() && presencia.next()) {
        m_presencia = presencia.value("estado").toString();
    }
}

QString SolicitudesHuesped::presencia() const
{
    return m_presencia;
}

bool SolicitudesHuesped::cambiarPresencia(const QString &nuevoEstado)
{
    if (nuevoEstado != QLatin1String("dentro") && nuevoEstado != QLatin1String("fuera")) {
        emit operacionRechazada(QStringLiteral("Estado de presencia no valido."));
        return false;
    }
    if (m_idHabitacion < 0) {
        emit operacionRechazada(QStringLiteral("No hay conexión con la base de datos."));
        return false;
    }

    // Estado_Presencia tiene UNA fila por habitacion (id_habitacion es
    // su llave primaria): se inserta la primera vez y se actualiza las
    // siguientes.
    QSqlQuery query;
    query.prepare(QStringLiteral(
        "INSERT INTO Estado_Presencia (id_habitacion, estado, fecha_hora_actualizacion) "
        "VALUES (:id, :estado, datetime('now','localtime')) "
        "ON CONFLICT(id_habitacion) DO UPDATE SET "
        "  estado = excluded.estado, "
        "  fecha_hora_actualizacion = excluded.fecha_hora_actualizacion"));
    query.bindValue(":id", m_idHabitacion);
    query.bindValue(":estado", nuevoEstado);

    if (!query.exec()) {
        qWarning() << "No se pudo guardar la presencia:" << query.lastError().text();
        emit operacionRechazada(QStringLiteral("No se pudo guardar tu estado. Intenta de nuevo."));
        return false;
    }

    m_presencia = nuevoEstado;
    emit presenciaCambiada(m_presencia);
    return true;
}

bool SolicitudesHuesped::crearSolicitud(const QString &tipo, const QString &prioridad)
{
    // Mismos valores que los CHECK de Solicitud_Servicio; se validan
    // aqui primero para poder dar un mensaje claro en vez del error
    // crudo de SQLite.
    if (tipo != QLatin1String("limpieza") && tipo != QLatin1String("mantenimiento")) {
        emit operacionRechazada(QStringLiteral("Tipo de solicitud no válido."));
        return false;
    }
    if (prioridad != QLatin1String("baja") && prioridad != QLatin1String("media")
        && prioridad != QLatin1String("alta")) {
        emit operacionRechazada(QStringLiteral("Prioridad no válida."));
        return false;
    }
    if (m_idHabitacion < 0) {
        emit operacionRechazada(QStringLiteral("No hay conexión con la base de datos."));
        return false;
    }

    // Una solicitud de origen 'huesped' EXIGE id_huesped (CHECK
    // "huesped_si_origen_huesped"). Se toma del huesped con estadia
    // abierta en esta habitacion (fecha_salida_real IS NULL).
    QSqlQuery estadia;
    estadia.prepare(QStringLiteral(
        "SELECT id_huesped FROM Historial_Estadia "
        "WHERE id_habitacion = :id AND fecha_salida_real IS NULL "
        "ORDER BY id_estadia DESC LIMIT 1"));
    estadia.bindValue(":id", m_idHabitacion);
    if (!estadia.exec() || !estadia.next()) {
        emit operacionRechazada(QStringLiteral(
            "No hay una estadía activa en esta habitación. Acude a recepción."));
        return false;
    }
    const int idHuesped = estadia.value("id_huesped").toInt();

    // Evita llenar al personal de solicitudes repetidas por toques
    // seguidos: si ya hay una del mismo tipo sin resolver, no se crea otra.
    QSqlQuery duplicada;
    duplicada.prepare(QStringLiteral(
        "SELECT 1 FROM Solicitud_Servicio "
        "WHERE id_habitacion = :id AND tipo = :tipo AND estado IN ('pendiente','en_proceso') "
        "LIMIT 1"));
    duplicada.bindValue(":id", m_idHabitacion);
    duplicada.bindValue(":tipo", tipo);
    if (duplicada.exec() && duplicada.next()) {
        emit operacionRechazada(tipo == QLatin1String("limpieza")
            ? QStringLiteral("Ya hay una solicitud de limpieza en curso.")
            : QStringLiteral("Ya hay una solicitud de mantenimiento en curso."));
        return false;
    }

    QSqlQuery insertar;
    insertar.prepare(QStringLiteral(
        "INSERT INTO Solicitud_Servicio (id_habitacion, id_huesped, origen, tipo, prioridad) "
        "VALUES (:habitacion, :huesped, 'huesped', :tipo, :prioridad)"));
    insertar.bindValue(":habitacion", m_idHabitacion);
    insertar.bindValue(":huesped", idHuesped);
    insertar.bindValue(":tipo", tipo);
    insertar.bindValue(":prioridad", prioridad);

    if (!insertar.exec()) {
        qWarning() << "No se pudo crear la solicitud:" << insertar.lastError().text();
        emit operacionRechazada(QStringLiteral("No se pudo enviar la solicitud. Intenta de nuevo."));
        return false;
    }

    emit solicitudCreada(tipo);
    return true;
}
