#include "Reportes.h"

#include "ControlAcceso.h"

#include <QDate>
#include <QDebug>
#include <QSqlError>
#include <QSqlQuery>

Reportes::Reportes(QObject *parent)
    : QObject(parent)
{
}

bool Reportes::puedeVerReportes()
{
    QSqlQuery query;
    query.exec(QStringLiteral(
        "SELECT 1 "
        "FROM Sesion_Actual s "
        "JOIN Usuario u ON u.id_usuario = s.id_usuario AND u.estado = 'activo' "
        "JOIN Permisos p ON p.id_rol = u.id_rol "
        "WHERE s.id = 1 AND p.modulo = 'reportes' AND p.accion_permitida = 'ver'"));

    return query.next(); // false tambien si no hay sesion activa.
}

QVariantMap Reportes::estadoHabitaciones()
{
    if (!ControlAcceso::sesionTienePermiso(QStringLiteral("reportes"), QStringLiteral("ver"))) {
        return {};
    }

    QVariantMap resultado;
    QVariantList porEstado;
    int total = 0;

    QSqlQuery query;
    if (!query.exec(QStringLiteral(
            "SELECT estado_actual, COUNT(*) AS cantidad FROM Habitacion "
            "GROUP BY estado_actual ORDER BY cantidad DESC"))) {
        qWarning() << "Reportes: no se pudo leer Habitacion:" << query.lastError().text();
    }
    while (query.next()) {
        QVariantMap fila;
        fila[QStringLiteral("estado")] = query.value("estado_actual").toString();
        fila[QStringLiteral("cantidad")] = query.value("cantidad").toInt();
        total += query.value("cantidad").toInt();
        porEstado.append(fila);
    }

    resultado[QStringLiteral("total")] = total;
    resultado[QStringLiteral("porEstado")] = porEstado;
    return resultado;
}

QVariantMap Reportes::ocupacion(int dias)
{
    if (!ControlAcceso::sesionTienePermiso(QStringLiteral("reportes"), QStringLiteral("ver"))) {
        return {};
    }

    if (dias < 1) {
        dias = 1;
    }
    // El periodo se arma en C++ con QDate para no depender de la zona
    // horaria de SQLite: [inicio, fin] incluye hoy.
    const QDate hoy = QDate::currentDate();
    const QString inicio = hoy.addDays(-(dias - 1)).toString(Qt::ISODate);
    const QString finExclusivo = hoy.addDays(1).toString(Qt::ISODate);

    QVariantMap resultado;
    resultado[QStringLiteral("inicio")] = inicio;
    resultado[QStringLiteral("fin")] = hoy.toString(Qt::ISODate);
    resultado[QStringLiteral("dias")] = dias;

    QSqlQuery habitaciones;
    habitaciones.exec(QStringLiteral(
        "SELECT COUNT(*) FROM Habitacion WHERE estado_actual <> 'fuera de servicio'"));
    const int totalHabitaciones = habitaciones.next() ? habitaciones.value(0).toInt() : 0;

    // Por cada reserva se cuentan solo las noches que caen dentro del
    // periodo: desde la fecha mayor entre (entrada, inicio) hasta la
    // menor entre (salida, fin). Las canceladas no cuentan.
    QSqlQuery noches;
    noches.prepare(QStringLiteral(
        "SELECT COALESCE(SUM(MAX(0, "
        "    julianday(MIN(date(fecha_salida), :fin)) - "
        "    julianday(MAX(date(fecha_entrada), :inicio)))), 0) AS noches, "
        "  SUM(CASE WHEN date(fecha_registro) >= :inicio THEN 1 ELSE 0 END) AS nuevas "
        "FROM Reserva WHERE estado_reserva IN ('confirmada','finalizada')"));
    noches.bindValue(QStringLiteral(":inicio"), inicio);
    noches.bindValue(QStringLiteral(":fin"), finExclusivo);

    int nochesOcupadas = 0;
    int reservasNuevas = 0;
    if (!noches.exec()) {
        qWarning() << "Reportes: no se pudo calcular la ocupacion:" << noches.lastError().text();
    } else if (noches.next()) {
        nochesOcupadas = qRound(noches.value("noches").toDouble());
        reservasNuevas = noches.value("nuevas").toInt();
    }

    const int nochesDisponibles = totalHabitaciones * dias;
    resultado[QStringLiteral("totalHabitaciones")] = totalHabitaciones;
    resultado[QStringLiteral("nochesOcupadas")] = nochesOcupadas;
    resultado[QStringLiteral("nochesDisponibles")] = nochesDisponibles;
    resultado[QStringLiteral("porcentaje")] = nochesDisponibles > 0
        ? qRound(100.0 * nochesOcupadas / nochesDisponibles)
        : 0;
    resultado[QStringLiteral("reservasNuevas")] = reservasNuevas;
    return resultado;
}

QVariantMap Reportes::resumenSolicitudes(int dias)
{
    if (!ControlAcceso::sesionTienePermiso(QStringLiteral("reportes"), QStringLiteral("ver"))) {
        return {};
    }

    if (dias < 1) {
        dias = 1;
    }
    const QString inicio = QDate::currentDate().addDays(-(dias - 1)).toString(Qt::ISODate);

    QVariantMap resultado;
    resultado[QStringLiteral("total")] = 0;
    resultado[QStringLiteral("pendientes")] = 0;
    resultado[QStringLiteral("enProceso")] = 0;
    resultado[QStringLiteral("resueltas")] = 0;

    // Conteo por estado.
    QSqlQuery estados;
    estados.prepare(QStringLiteral(
        "SELECT estado, COUNT(*) AS cantidad FROM Solicitud_Servicio "
        "WHERE date(fecha_creacion) >= :inicio GROUP BY estado"));
    estados.bindValue(QStringLiteral(":inicio"), inicio);
    if (!estados.exec()) {
        qWarning() << "Reportes: no se pudieron contar las solicitudes:" << estados.lastError().text();
    }
    int total = 0;
    while (estados.next()) {
        const QString estado = estados.value("estado").toString();
        const int cantidad = estados.value("cantidad").toInt();
        total += cantidad;
        if (estado == QStringLiteral("pendiente")) {
            resultado[QStringLiteral("pendientes")] = cantidad;
        } else if (estado == QStringLiteral("en_proceso")) {
            resultado[QStringLiteral("enProceso")] = cantidad;
        } else {
            resultado[QStringLiteral("resueltas")] = cantidad;
        }
    }
    resultado[QStringLiteral("total")] = total;

    // Por tipo, con los mismos tiempos que registra el Theme 6:
    // respuesta = atencion - creacion, resolucion = resolucion - atencion.
    QSqlQuery tipos;
    tipos.prepare(QStringLiteral(
        "SELECT tipo, COUNT(*) AS total, "
        "  SUM(CASE WHEN estado = 'resuelta' THEN 1 ELSE 0 END) AS resueltas, "
        "  AVG(CASE WHEN fecha_atencion IS NOT NULL THEN "
        "      (julianday(fecha_atencion) - julianday(fecha_creacion)) * 1440 END) AS respuesta, "
        "  AVG(CASE WHEN fecha_resolucion IS NOT NULL AND fecha_atencion IS NOT NULL THEN "
        "      (julianday(fecha_resolucion) - julianday(fecha_atencion)) * 1440 END) AS resolucion "
        "FROM Solicitud_Servicio WHERE date(fecha_creacion) >= :inicio "
        "GROUP BY tipo ORDER BY tipo"));
    tipos.bindValue(QStringLiteral(":inicio"), inicio);
    if (!tipos.exec()) {
        qWarning() << "Reportes: no se pudieron agrupar las solicitudes:" << tipos.lastError().text();
    }
    QVariantList porTipo;
    while (tipos.next()) {
        QVariantMap fila;
        fila[QStringLiteral("tipo")] = tipos.value("tipo").toString();
        fila[QStringLiteral("total")] = tipos.value("total").toInt();
        fila[QStringLiteral("resueltas")] = tipos.value("resueltas").toInt();
        // AVG regresa NULL si no hay datos: se manda -1 para que QML
        // muestre "sin datos" en lugar de 0 minutos.
        fila[QStringLiteral("promedioRespuesta")] = tipos.value("respuesta").isNull()
            ? -1 : qRound(tipos.value("respuesta").toDouble());
        fila[QStringLiteral("promedioResolucion")] = tipos.value("resolucion").isNull()
            ? -1 : qRound(tipos.value("resolucion").toDouble());
        porTipo.append(fila);
    }
    resultado[QStringLiteral("porTipo")] = porTipo;

    // Solicitudes activas (sin importar la fecha) por prioridad.
    QSqlQuery prioridades;
    prioridades.exec(QStringLiteral(
        "SELECT prioridad, COUNT(*) AS cantidad FROM Solicitud_Servicio "
        "WHERE estado <> 'resuelta' GROUP BY prioridad "
        "ORDER BY CASE prioridad WHEN 'alta' THEN 1 WHEN 'media' THEN 2 ELSE 3 END"));
    QVariantList activas;
    while (prioridades.next()) {
        QVariantMap fila;
        fila[QStringLiteral("prioridad")] = prioridades.value("prioridad").toString();
        fila[QStringLiteral("cantidad")] = prioridades.value("cantidad").toInt();
        activas.append(fila);
    }
    resultado[QStringLiteral("activasPorPrioridad")] = activas;

    return resultado;
}

QVariantList Reportes::pendientesLimpieza()
{
    if (!ControlAcceso::sesionTienePermiso(QStringLiteral("reportes"), QStringLiteral("ver"))) {
        return {};
    }

    QVariantList resultado;

    QSqlQuery query;
    if (!query.exec(QStringLiteral(
            "SELECT h.numero, h.piso, h.estado_actual, "
            "  (SELECT COUNT(*) FROM Solicitud_Servicio s "
            "   WHERE s.id_habitacion = h.id_habitacion AND s.tipo = 'limpieza' "
            "     AND s.estado <> 'resuelta') AS abiertas "
            "FROM Habitacion h "
            "WHERE h.estado_actual = 'en limpieza' OR EXISTS ("
            "  SELECT 1 FROM Solicitud_Servicio s "
            "  WHERE s.id_habitacion = h.id_habitacion AND s.tipo = 'limpieza' "
            "    AND s.estado <> 'resuelta') "
            "ORDER BY h.piso, h.numero"))) {
        qWarning() << "Reportes: no se pudieron leer las habitaciones por limpiar:" << query.lastError().text();
        return resultado;
    }

    while (query.next()) {
        QVariantMap fila;
        fila[QStringLiteral("numero")] = query.value("numero").toString();
        fila[QStringLiteral("piso")] = query.value("piso").toInt();
        fila[QStringLiteral("estadoActual")] = query.value("estado_actual").toString();
        fila[QStringLiteral("solicitudesAbiertas")] = query.value("abiertas").toInt();
        resultado.append(fila);
    }
    return resultado;
}

QVariantList Reportes::historialMantenimiento(int limite)
{
    if (!ControlAcceso::sesionTienePermiso(QStringLiteral("reportes"), QStringLiteral("ver"))) {
        return {};
    }

    QVariantList resultado;

    QSqlQuery query;
    query.prepare(QStringLiteral(
        "SELECT h.numero, s.descripcion, s.prioridad, s.fecha_resolucion, "
        "  COALESCE(u.nombre || ' ' || u.apellido, '') AS responsable, "
        "  CAST(ROUND((julianday(s.fecha_atencion) - julianday(s.fecha_creacion)) * 1440) AS INTEGER) AS respuesta, "
        "  CAST(ROUND((julianday(s.fecha_resolucion) - julianday(s.fecha_atencion)) * 1440) AS INTEGER) AS resolucion "
        "FROM Solicitud_Servicio s "
        "JOIN Habitacion h ON h.id_habitacion = s.id_habitacion "
        "LEFT JOIN Usuario u ON u.id_usuario = s.id_responsable_asignado "
        "WHERE s.tipo = 'mantenimiento' AND s.estado = 'resuelta' "
        "ORDER BY s.fecha_resolucion DESC LIMIT :limite"));
    query.bindValue(QStringLiteral(":limite"), limite);

    if (!query.exec()) {
        qWarning() << "Reportes: no se pudo leer el historial de mantenimiento:" << query.lastError().text();
        return resultado;
    }

    while (query.next()) {
        QVariantMap fila;
        fila[QStringLiteral("numero")] = query.value("numero").toString();
        fila[QStringLiteral("descripcion")] = query.value("descripcion").toString();
        fila[QStringLiteral("prioridad")] = query.value("prioridad").toString();
        fila[QStringLiteral("fechaResolucion")] = query.value("fecha_resolucion").toString();
        fila[QStringLiteral("responsable")] = query.value("responsable").toString();
        fila[QStringLiteral("minutosRespuesta")] = query.value("respuesta").toInt();
        fila[QStringLiteral("minutosResolucion")] = query.value("resolucion").toInt();
        resultado.append(fila);
    }
    return resultado;
}
