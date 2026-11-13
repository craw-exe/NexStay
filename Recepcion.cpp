#include "Recepcion.h"

#include "ControlAcceso.h"

#include <QDate>
#include <QDebug>
#include <QRegularExpression>
#include <QSqlDatabase>
#include <QSqlError>
#include <QSqlQuery>
#include <QStringList>

Recepcion::Recepcion(QObject *parent)
    : QObject(parent)
{
}

bool Recepcion::rechazar(const QString &motivo)
{
    emit operacionRechazada(motivo);
    return false;
}

bool Recepcion::autorizar(const QString &modulo, const QString &accion)
{
    if (ControlAcceso::sesionTienePermiso(modulo, accion)) {
        return true;
    }
    return rechazar(tr("Tu rol no tiene permiso para esta acción."));
}

int Recepcion::registrarHuesped(const QString &nombre, const QString &apellido,
                                const QString &documento, const QString &telefono,
                                const QString &correo)
{
    if (!autorizar(QStringLiteral("huespedes"), QStringLiteral("crear"))) {
        return -1;
    }
    const QString n = nombre.trimmed();
    const QString a = apellido.trimmed();
    const QString d = documento.trimmed().toUpper();
    const QString t = telefono.trimmed();
    const QString c = correo.trimmed().toLower();

    // Theme 11: el correo es opcional (muchos huespedes no lo dan en
    // recepcion); si se escribe, se sigue validando el formato.
    if (n.isEmpty() || a.isEmpty() || d.isEmpty() || t.isEmpty()) {
        rechazar(tr("Completa nombre, apellido, documento y teléfono."));
        return -1;
    }
    static const QRegularExpression formatoCorreo(QStringLiteral("^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$"));
    if (!c.isEmpty() && !formatoCorreo.match(c).hasMatch()) {
        rechazar(tr("El correo no tiene un formato válido."));
        return -1;
    }
    static const QRegularExpression formatoTelefono(QStringLiteral("^[0-9 +()-]{7,20}$"));
    if (!formatoTelefono.match(t).hasMatch()) {
        rechazar(tr("El teléfono solo puede tener números, espacios y los signos + - ( )."));
        return -1;
    }

    QSqlQuery existe;
    existe.prepare(QStringLiteral("SELECT 1 FROM Huesped WHERE documento_identidad = :d"));
    existe.bindValue(":d", d);
    if (existe.exec() && existe.next()) {
        rechazar(tr("Ya hay un huésped registrado con ese documento."));
        return -1;
    }

    QSqlQuery insertar;
    insertar.prepare(QStringLiteral(
        "INSERT INTO Huesped (nombre, apellido, documento_identidad, telefono, correo) "
        "VALUES (:n, :a, :d, :t, :c)"));
    insertar.bindValue(":n", n);
    insertar.bindValue(":a", a);
    insertar.bindValue(":d", d);
    insertar.bindValue(":t", t);
    insertar.bindValue(":c", c);
    if (!insertar.exec()) {
        qWarning() << "registrarHuesped():" << insertar.lastError().text();
        rechazar(tr("No se pudo registrar al huésped."));
        return -1;
    }
    const int id = insertar.lastInsertId().toInt();
    emit huespedRegistrado(id, n + QLatin1Char(' ') + a);
    return id;
}

QVariantList Recepcion::buscarHuespedes(const QString &texto, int limite)
{
    QVariantList resultado;
    if (!ControlAcceso::sesionTienePermiso(QStringLiteral("huespedes"), QStringLiteral("ver"))) {
        return resultado;
    }
    QSqlQuery query;
    query.prepare(QStringLiteral(
        "SELECT id_huesped, nombre || ' ' || apellido AS completo, documento_identidad, telefono "
        "FROM Huesped "
        "WHERE (nombre || ' ' || apellido) LIKE :t OR documento_identidad LIKE :t2 "
        "OR telefono LIKE :t3 "
        "ORDER BY apellido, nombre LIMIT :limite"));
    const QString patron = QLatin1Char('%') + texto.trimmed() + QLatin1Char('%');
    query.bindValue(":t", patron);
    query.bindValue(":t2", patron);
    query.bindValue(":t3", patron);
    query.bindValue(":limite", qBound(1, limite, 100));
    if (!query.exec()) {
        qWarning() << "buscarHuespedes():" << query.lastError().text();
        return resultado;
    }
    while (query.next()) {
        QVariantMap fila;
        fila[QStringLiteral("idHuesped")] = query.value(0).toInt();
        fila[QStringLiteral("nombre")] = query.value(1).toString();
        fila[QStringLiteral("documento")] = query.value(2).toString();
        fila[QStringLiteral("telefono")] = query.value(3).toString();
        resultado.append(fila);
    }
    return resultado;
}

QVariantMap Recepcion::detalleReserva(int idReserva)
{
    QVariantMap d;
    if (!ControlAcceso::sesionTienePermiso(QStringLiteral("reservas"), QStringLiteral("ver"))) {
        return d;
    }
    QSqlQuery query;
    query.prepare(QStringLiteral(
        "SELECT r.id_reserva, g.nombre || ' ' || g.apellido, g.documento_identidad, h.numero, "
        "  date(r.fecha_entrada), date(r.fecha_salida), r.estado_reserva, h.estado_actual, "
        "  EXISTS (SELECT 1 FROM Historial_Estadia e WHERE e.id_reserva = r.id_reserva "
        "          AND e.fecha_salida_real IS NULL) AS en_estadia, "
        "  EXISTS (SELECT 1 FROM Historial_Estadia e WHERE e.id_habitacion = r.id_habitacion "
        "          AND e.fecha_salida_real IS NULL) AS habitacion_ocupada "
        "FROM Reserva r "
        "JOIN Huesped g ON g.id_huesped = r.id_huesped "
        "JOIN Habitacion h ON h.id_habitacion = r.id_habitacion "
        "WHERE r.id_reserva = :id"));
    query.bindValue(":id", idReserva);
    if (!query.exec() || !query.next()) {
        return d;
    }
    const QString hoy = QDate::currentDate().toString(QStringLiteral("yyyy-MM-dd"));
    const QString entrada = query.value(4).toString();
    const QString salida = query.value(5).toString();
    const QString estado = query.value(6).toString();
    const bool confirmada = estado == QLatin1String("confirmada");
    const bool enEstadia = query.value(8).toBool();

    d[QStringLiteral("idReserva")] = query.value(0).toInt();
    d[QStringLiteral("huesped")] = query.value(1).toString();
    d[QStringLiteral("documento")] = query.value(2).toString();
    d[QStringLiteral("numero")] = query.value(3).toString();
    d[QStringLiteral("entrada")] = entrada;
    d[QStringLiteral("salida")] = salida;
    d[QStringLiteral("estado")] = estado;
    d[QStringLiteral("enEstadia")] = enEstadia;
    d[QStringLiteral("puedeCheckIn")] = confirmada && !enEstadia
        && entrada <= hoy && hoy < salida
        && !query.value(9).toBool()
        && query.value(7).toString() != QLatin1String("fuera de servicio");
    d[QStringLiteral("puedeCheckOut")] = confirmada && enEstadia;
    d[QStringLiteral("puedeCancelar")] = confirmada && !enEstadia;
    return d;
}

bool Recepcion::checkIn(int idReserva)
{
    if (!autorizar(QStringLiteral("reservas"), QStringLiteral("editar"))) {
        return false;
    }
    const QVariantMap d = detalleReserva(idReserva);
    if (d.isEmpty()) {
        return rechazar(tr("La reserva no existe."));
    }
    if (!d.value(QStringLiteral("puedeCheckIn")).toBool()) {
        return rechazar(tr("No se puede hacer check-in: revisa que la reserva sea de hoy, "
                           "esté confirmada y la habitación no tenga a otro huésped."));
    }

    QSqlDatabase db = QSqlDatabase::database();
    db.transaction();
    QSqlQuery estadia;
    estadia.prepare(QStringLiteral(
        "INSERT INTO Historial_Estadia (id_reserva, id_huesped, id_habitacion, fecha_entrada_real) "
        "SELECT id_reserva, id_huesped, id_habitacion, datetime('now','localtime') "
        "FROM Reserva WHERE id_reserva = :id"));
    estadia.bindValue(":id", idReserva);
    QSqlQuery habitacion;
    habitacion.prepare(QStringLiteral(
        "UPDATE Habitacion SET estado_actual = 'ocupada' "
        "WHERE id_habitacion = (SELECT id_habitacion FROM Reserva WHERE id_reserva = :id)"));
    habitacion.bindValue(":id", idReserva);
    if (!estadia.exec() || !habitacion.exec()) {
        qWarning() << "checkIn():" << estadia.lastError().text() << habitacion.lastError().text();
        db.rollback();
        return rechazar(tr("No se pudo registrar el check-in."));
    }
    db.commit();
    emit operacionRealizada(tr("Check-in registrado: %1 en la habitación %2.")
                                .arg(d.value(QStringLiteral("huesped")).toString(),
                                     d.value(QStringLiteral("numero")).toString()));
    return true;
}

bool Recepcion::checkOut(int idReserva)
{
    if (!autorizar(QStringLiteral("reservas"), QStringLiteral("editar"))) {
        return false;
    }
    const QVariantMap d = detalleReserva(idReserva);
    if (d.isEmpty() || !d.value(QStringLiteral("puedeCheckOut")).toBool()) {
        return rechazar(tr("Esta reserva no tiene un huésped hospedado."));
    }

    // Al salir el huesped: se cierra la estadia, la reserva queda
    // finalizada, la habitacion pasa a limpieza y se avisa a limpieza.
    const QStringList sentencias = {
        QStringLiteral("UPDATE Historial_Estadia SET fecha_salida_real = datetime('now','localtime') "
                       "WHERE id_reserva = :id AND fecha_salida_real IS NULL"),
        QStringLiteral("UPDATE Reserva SET estado_reserva = 'finalizada' WHERE id_reserva = :id"),
        QStringLiteral("UPDATE Habitacion SET estado_actual = 'en limpieza' "
                       "WHERE id_habitacion = (SELECT id_habitacion FROM Reserva WHERE id_reserva = :id)"),
        QStringLiteral("INSERT INTO Solicitud_Servicio (id_habitacion, origen, tipo, descripcion, prioridad) "
                       "SELECT id_habitacion, 'automatico', 'limpieza', 'Limpieza por check-out', 'media' "
                       "FROM Reserva WHERE id_reserva = :id"),
    };
    QSqlDatabase db = QSqlDatabase::database();
    db.transaction();
    for (const QString &sql : sentencias) {
        QSqlQuery q;
        q.prepare(sql);
        q.bindValue(":id", idReserva);
        if (!q.exec()) {
            qWarning() << "checkOut():" << q.lastError().text();
            db.rollback();
            return rechazar(tr("No se pudo registrar el check-out."));
        }
    }
    db.commit();
    emit operacionRealizada(tr("Check-out registrado. La habitación %1 pasó a limpieza.")
                                .arg(d.value(QStringLiteral("numero")).toString()));
    return true;
}

bool Recepcion::cancelarReserva(int idReserva)
{
    if (!autorizar(QStringLiteral("reservas"), QStringLiteral("editar"))) {
        return false;
    }
    const QVariantMap d = detalleReserva(idReserva);
    if (d.isEmpty() || !d.value(QStringLiteral("puedeCancelar")).toBool()) {
        return rechazar(tr("Solo se pueden cancelar reservas confirmadas sin check-in."));
    }

    QSqlDatabase db = QSqlDatabase::database();
    db.transaction();
    QSqlQuery cancelar;
    cancelar.prepare(QStringLiteral(
        "UPDATE Reserva SET estado_reserva = 'cancelada' WHERE id_reserva = :id"));
    cancelar.bindValue(":id", idReserva);
    // Si la habitacion estaba apartada para esta llegada, se libera.
    QSqlQuery liberar;
    liberar.prepare(QStringLiteral(
        "UPDATE Habitacion SET estado_actual = 'libre' "
        "WHERE estado_actual = 'reservada' "
        "  AND id_habitacion = (SELECT id_habitacion FROM Reserva WHERE id_reserva = :id) "
        "  AND NOT EXISTS (SELECT 1 FROM Reserva r WHERE r.id_habitacion = Habitacion.id_habitacion "
        "      AND r.estado_reserva = 'confirmada' "
        "      AND date(r.fecha_entrada) <= date('now','localtime','+1 day'))"));
    liberar.bindValue(":id", idReserva);
    if (!cancelar.exec() || !liberar.exec()) {
        qWarning() << "cancelarReserva():" << cancelar.lastError().text() << liberar.lastError().text();
        db.rollback();
        return rechazar(tr("No se pudo cancelar la reserva."));
    }
    db.commit();
    emit operacionRealizada(tr("Reserva cancelada."));
    return true;
}
