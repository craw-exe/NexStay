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

QString AlertasPersonal::rolConPermiso() const
{
    QSqlQuery query;
    if (!query.exec(QStringLiteral(
            "SELECT r.nombre AS rol "
            "FROM Sesion_Actual s "
            "JOIN Usuario u ON u.id_usuario = s.id_usuario AND u.estado = 'activo' "
            "JOIN Rol r ON r.id_rol = u.id_rol "
            "WHERE s.id = 1 "
            "  AND EXISTS (SELECT 1 FROM Permisos p WHERE p.id_rol = u.id_rol "
            "              AND p.modulo = 'solicitudes' AND p.accion_permitida = 'ver')"))
        || !query.next()) {
        return QString();
    }
    return query.value("rol").toString();
}

void AlertasPersonal::refrescar()
{
    const QString rol = rolConPermiso();
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
            "SELECT s.id_solicitud, s.tipo, s.prioridad, s.fecha_creacion, h.numero "
            "FROM Solicitud_Servicio s "
            "JOIN Habitacion h ON h.id_habitacion = s.id_habitacion "
            "WHERE s.estado = 'pendiente' ");
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
                fila[QStringLiteral("fechaCreacion")] = pendientes.value("fecha_creacion").toString();
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
