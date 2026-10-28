#include "AlertasPersonal.h"

#include <QDebug>
#include <QSqlError>
#include <QSqlQuery>
#include <QVariantMap>

namespace
{
    // Tipo de solicitud que le corresponde a cada rol; vacio = todos.
    QString tipoVisiblePara(const QString &rol)
    {
        if (rol == QLatin1String("limpieza")) {
            return QStringLiteral("limpieza");
        }
        if (rol == QLatin1String("mantenimiento")) {
            return QStringLiteral("mantenimiento");
        }
        return QString();
    }
}

AlertasPersonal::AlertasPersonal(QObject *parent)
    : QObject(parent)
{
    // Se parte de la ultima solicitud que ya existe: las anteriores no
    // deben disparar alerta al abrir la app (solo aparecen en la lista).
    QSqlQuery query;
    if (query.exec(QStringLiteral("SELECT COALESCE(MAX(id_solicitud), 0) FROM Solicitud_Servicio"))
        && query.next()) {
        m_ultimoIdVisto = query.value(0).toInt();
    }

    refrescar();

    connect(&m_timer, &QTimer::timeout, this, &AlertasPersonal::refrescar);
    m_timer.start(2000);
}

QVariantList AlertasPersonal::solicitudes() const
{
    return m_solicitudes;
}

QString AlertasPersonal::rolConPermiso(const QString &accion, int *idUsuario) const
{
    QSqlQuery query;
    query.prepare(QStringLiteral(
        "SELECT u.id_usuario, r.nombre AS rol "
        "FROM Sesion_Actual s "
        "JOIN Usuario u ON u.id_usuario = s.id_usuario AND u.estado = 'activo' "
        "JOIN Rol r ON r.id_rol = u.id_rol "
        "WHERE s.id = 1 "
        "  AND EXISTS (SELECT 1 FROM Permisos p WHERE p.id_rol = u.id_rol "
        "              AND p.modulo = 'solicitudes' AND p.accion_permitida = :accion)"));
    query.bindValue(":accion", accion);

    if (!query.exec() || !query.next()) {
        return QString();
    }
    if (idUsuario) {
        *idUsuario = query.value("id_usuario").toInt();
    }
    return query.value("rol").toString();
}

bool AlertasPersonal::puedeAtender() const
{
    return !rolConPermiso(QStringLiteral("editar")).isEmpty();
}

bool AlertasPersonal::tomarSolicitud(int idSolicitud)
{
    int idUsuario = -1;
    const QString rol = rolConPermiso(QStringLiteral("editar"), &idUsuario);
    if (rol.isEmpty()) {
        emit operacionRechazada(QStringLiteral("Tu rol no puede atender solicitudes."));
        return false;
    }

    QSqlQuery consulta;
    consulta.prepare(QStringLiteral(
        "SELECT tipo, estado FROM Solicitud_Servicio WHERE id_solicitud = :id"));
    consulta.bindValue(":id", idSolicitud);
    if (!consulta.exec() || !consulta.next()) {
        emit operacionRechazada(QStringLiteral("La solicitud ya no existe."));
        return false;
    }

    const QString tipoVisible = tipoVisiblePara(rol);
    if (!tipoVisible.isEmpty() && tipoVisible != consulta.value("tipo").toString()) {
        emit operacionRechazada(QStringLiteral("Esta solicitud no corresponde a tu rol."));
        return false;
    }

    const QString estado = consulta.value("estado").toString();
    if (estado == QLatin1String("resuelta")) {
        emit operacionRechazada(QStringLiteral("Esta solicitud ya fue atendida."));
        return false;
    }
    if (estado == QLatin1String("en_proceso")) {
        emit operacionRechazada(QStringLiteral("Otra persona ya la está atendiendo."));
        return false;
    }

    // "estado = 'pendiente'" en el WHERE: si dos personas la toman a la
    // vez, solo el primer UPDATE modifica la fila; el segundo no
    // cambia nada y se le avisa.
    QSqlQuery actualizar;
    actualizar.prepare(QStringLiteral(
        "UPDATE Solicitud_Servicio "
        "SET estado = 'en_proceso', "
        "    id_responsable_asignado = :usuario, "
        "    fecha_atencion = datetime('now','localtime') "
        "WHERE id_solicitud = :id AND estado = 'pendiente'"));
    actualizar.bindValue(":usuario", idUsuario);
    actualizar.bindValue(":id", idSolicitud);

    if (!actualizar.exec()) {
        qWarning() << "No se pudo tomar la solicitud:" << actualizar.lastError().text();
        emit operacionRechazada(QStringLiteral("No se pudo guardar el cambio. Intenta de nuevo."));
        return false;
    }
    if (actualizar.numRowsAffected() < 1) {
        emit operacionRechazada(QStringLiteral("Otra persona la tomó primero."));
        return false;
    }

    emit solicitudTomada(idSolicitud);
    refrescar();
    return true;
}

bool AlertasPersonal::marcarAtendida(int idSolicitud)
{
    int idUsuario = -1;
    const QString rol = rolConPermiso(QStringLiteral("editar"), &idUsuario);
    if (rol.isEmpty()) {
        emit operacionRechazada(QStringLiteral("Tu rol no puede atender solicitudes."));
        return false;
    }

    QSqlQuery consulta;
    consulta.prepare(QStringLiteral(
        "SELECT tipo, estado, id_responsable_asignado FROM Solicitud_Servicio WHERE id_solicitud = :id"));
    consulta.bindValue(":id", idSolicitud);
    if (!consulta.exec() || !consulta.next()) {
        emit operacionRechazada(QStringLiteral("La solicitud ya no existe."));
        return false;
    }

    const QString tipoVisible = tipoVisiblePara(rol);
    if (!tipoVisible.isEmpty() && tipoVisible != consulta.value("tipo").toString()) {
        emit operacionRechazada(QStringLiteral("Esta solicitud no corresponde a tu rol."));
        return false;
    }
    if (consulta.value("estado").toString() == QLatin1String("resuelta")) {
        emit operacionRechazada(QStringLiteral("Esta solicitud ya fue atendida."));
        return false;
    }
    // Task 3: si otra persona la tomo, solo ella (o un administrador)
    // puede darla por terminada.
    if (consulta.value("estado").toString() == QLatin1String("en_proceso")
        && consulta.value("id_responsable_asignado").toInt() != idUsuario
        && rol != QLatin1String("administrador")) {
        emit operacionRechazada(QStringLiteral("La está atendiendo otra persona."));
        return false;
    }

    // "estado <> 'resuelta'" en el WHERE evita que dos personas la
    // atiendan a la vez: la segunda no modifica ninguna fila.
    QSqlQuery actualizar;
    actualizar.prepare(QStringLiteral(
        "UPDATE Solicitud_Servicio "
        "SET estado = 'resuelta', "
        "    id_responsable_asignado = COALESCE(id_responsable_asignado, :usuario), "
        "    fecha_atencion = COALESCE(fecha_atencion, datetime('now','localtime')), "
        "    fecha_resolucion = datetime('now','localtime') "
        "WHERE id_solicitud = :id AND estado <> 'resuelta'"));
    actualizar.bindValue(":usuario", idUsuario);
    actualizar.bindValue(":id", idSolicitud);

    if (!actualizar.exec()) {
        qWarning() << "No se pudo marcar la solicitud como atendida:" << actualizar.lastError().text();
        emit operacionRechazada(QStringLiteral("No se pudo guardar el cambio. Intenta de nuevo."));
        return false;
    }
    if (actualizar.numRowsAffected() < 1) {
        emit operacionRechazada(QStringLiteral("Esta solicitud ya fue atendida."));
        return false;
    }

    emit solicitudAtendida(idSolicitud);
    refrescar(); // La lista se actualiza al instante, sin esperar al timer.
    return true;
}

void AlertasPersonal::refrescar()
{
    const QString rol = rolConPermiso(QStringLiteral("ver"));
    const QString tipoVisible = tipoVisiblePara(rol);

    // 1) Solicitudes nuevas desde la ultima revision. Se avanza el id
    //    visto con TODAS (incluidas las que no le tocan a este rol)
    //    para no revisarlas otra vez; solo se alerta por las propias.
    QSqlQuery nuevas;
    nuevas.prepare(QStringLiteral(
        "SELECT s.id_solicitud, s.tipo, s.prioridad, h.numero "
        "FROM Solicitud_Servicio s "
        "JOIN Habitacion h ON h.id_habitacion = s.id_habitacion "
        "WHERE s.id_solicitud > :ultimo "
        "ORDER BY s.id_solicitud"));
    nuevas.bindValue(":ultimo", m_ultimoIdVisto);

    if (nuevas.exec()) {
        while (nuevas.next()) {
            const int id = nuevas.value("id_solicitud").toInt();
            const QString tipo = nuevas.value("tipo").toString();
            m_ultimoIdVisto = qMax(m_ultimoIdVisto, id);

            if (!rol.isEmpty() && (tipoVisible.isEmpty() || tipoVisible == tipo)) {
                emit nuevaSolicitud(id, tipo, nuevas.value("numero").toString(),
                                    nuevas.value("prioridad").toString());
            }
        }
    } else {
        // Un fallo pasajero se reintenta en el siguiente ciclo.
        qWarning() << "AlertasPersonal: no se pudieron leer solicitudes nuevas:"
                   << nuevas.lastError().text();
    }

    // 2) Lista de pendientes visibles para este usuario.
    QVariantList lista;
    if (!rol.isEmpty()) {
        QString sql = QStringLiteral(
            "SELECT s.id_solicitud, s.tipo, s.prioridad, s.origen, s.estado, "
            "       s.id_responsable_asignado, s.fecha_creacion, h.numero, "
            "       u.nombre || ' ' || u.apellido AS responsable, "
            "       CAST((julianday('now','localtime') - julianday(s.fecha_creacion)) * 1440 AS INTEGER) AS minutos_espera "
            "FROM Solicitud_Servicio s "
            "JOIN Habitacion h ON h.id_habitacion = s.id_habitacion "
            "LEFT JOIN Usuario u ON u.id_usuario = s.id_responsable_asignado "
            "WHERE s.estado IN ('pendiente', 'en_proceso') ");
        if (!tipoVisible.isEmpty()) {
            sql += QStringLiteral("AND s.tipo = :tipo ");
        }
        sql += QStringLiteral(
            "ORDER BY CASE s.prioridad WHEN 'alta' THEN 0 WHEN 'media' THEN 1 ELSE 2 END, "
            "         s.fecha_creacion, s.id_solicitud");

        QSqlQuery pendientes;
        pendientes.prepare(sql);
        if (!tipoVisible.isEmpty()) {
            pendientes.bindValue(":tipo", tipoVisible);
        }

        if (pendientes.exec()) {
            while (pendientes.next()) {
                QVariantMap fila;
                fila[QStringLiteral("idSolicitud")] = pendientes.value("id_solicitud").toInt();
                fila[QStringLiteral("numeroHabitacion")] = pendientes.value("numero").toString();
                fila[QStringLiteral("tipo")] = pendientes.value("tipo").toString();
                fila[QStringLiteral("prioridad")] = pendientes.value("prioridad").toString();
                fila[QStringLiteral("origen")] = pendientes.value("origen").toString();
                fila[QStringLiteral("estado")] = pendientes.value("estado").toString();
                fila[QStringLiteral("idResponsable")] = pendientes.value("id_responsable_asignado").toInt();
                fila[QStringLiteral("responsable")] = pendientes.value("responsable").toString();
                fila[QStringLiteral("fechaCreacion")] = pendientes.value("fecha_creacion").toString();
                fila[QStringLiteral("minutosEspera")] = qMax(0, pendientes.value("minutos_espera").toInt());
                lista.append(fila);
            }
        } else {
            qWarning() << "AlertasPersonal: no se pudieron leer pendientes:"
                       << pendientes.lastError().text();
            return; // Se conserva la lista anterior hasta el proximo ciclo.
        }
    }

    if (lista != m_solicitudes) {
        m_solicitudes = lista;
        emit solicitudesCambiaron();
    }
}
