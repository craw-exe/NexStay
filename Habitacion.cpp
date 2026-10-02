#include "Habitacion.h"

#include <QDebug>
#include <QSqlError>
#include <QSqlQuery>

Habitacion::Habitacion(QObject *parent)
    : QObject(parent)
{
    cargarDesdeBaseDeDatos();

    // Task 4: revisa cada 2 segundos si el estado cambio desde otra
    // pantalla/perfil u otra instancia de la app (misma BD compartida).
    connect(&m_timerActualizacion, &QTimer::timeout,
            this, &Habitacion::refrescarEstadoDesdeBaseDeDatos);
    m_timerActualizacion.start(2000);
}

void Habitacion::cargarDesdeBaseDeDatos()
{
    QSqlQuery query;
    query.prepare(QStringLiteral(
        "SELECT id_habitacion, numero, piso, tipo, estado_actual, capacidad "
        "FROM Habitacion ORDER BY id_habitacion LIMIT 1"));

    if (!query.exec()) {
        qWarning() << "No se pudo leer Habitacion:" << query.lastError().text();
        return;
    }

    if (!query.next()) {
        qWarning() << "La tabla Habitacion esta vacia. "
                       "Verifica que Database::inicializar() se haya ejecutado.";
        return;
    }

    m_idHabitacion = query.value("id_habitacion").toInt();
    m_numero = query.value("numero").toInt();
    m_piso = query.value("piso").toInt();
    m_tipo = query.value("tipo").toString();
    m_estadoActual = query.value("estado_actual").toString();
    m_capacidad = query.value("capacidad").toInt();

    emit datosCargados();
    emit estadoCambiado(m_estadoActual);
}

void Habitacion::refrescarEstadoDesdeBaseDeDatos()
{
    if (m_idHabitacion < 0) {
        return;
    }

    QSqlQuery query;
    query.prepare(QStringLiteral(
        "SELECT estado_actual FROM Habitacion WHERE id_habitacion = :id"));
    query.bindValue(":id", m_idHabitacion);

    if (!query.exec() || !query.next()) {
        // No se interrumpe la app por un fallo de lectura pasajero;
        // simplemente se reintenta en el siguiente ciclo del timer.
        return;
    }

    const QString estadoEnBD = query.value("estado_actual").toString();
    if (estadoEnBD != m_estadoActual) {
        qDebug() << "Estado actualizado por otro perfil/instancia:"
                  << m_estadoActual << "->" << estadoEnBD;
        m_estadoActual = estadoEnBD;
        emit estadoCambiado(m_estadoActual);
    }
}

int Habitacion::numero() const
{
    return m_numero;
}

int Habitacion::piso() const
{
    return m_piso;
}

QString Habitacion::tipo() const
{
    return m_tipo;
}

int Habitacion::capacidad() const
{
    return m_capacidad;
}

QString Habitacion::estadoActual() const
{
    return m_estadoActual;
}

QStringList Habitacion::estadosDisponibles() const
{
    return m_estadosValidos;
}

bool Habitacion::cambiarEstado(const QString &nuevoEstado)
{
    if (!m_estadosValidos.contains(nuevoEstado)) {
        qWarning() << "Estado invalido rechazado:" << nuevoEstado;
        emit cambioRechazado(QStringLiteral("Estado invalido: ") + nuevoEstado);
        return false;
    }

    if (nuevoEstado == m_estadoActual) {
        return true; // Nada que hacer, ya esta en ese estado
    }

    if (m_idHabitacion < 0) {
        qWarning() << "No hay una habitacion cargada desde la BD; no se puede actualizar.";
        emit cambioRechazado(QStringLiteral("No hay conexion con la base de datos"));
        return false;
    }

    QSqlQuery query;
    query.prepare(QStringLiteral(
        "UPDATE Habitacion SET estado_actual = :estado WHERE id_habitacion = :id"));
    query.bindValue(":estado", nuevoEstado);
    query.bindValue(":id", m_idHabitacion);

    if (!query.exec()) {
        qWarning() << "No se pudo actualizar el estado en la BD:" << query.lastError().text();
        emit cambioRechazado(query.lastError().text());
        return false;
    }

    // El trigger trg_actualizar_historial ya dejo el registro en
    // Historial_Estado automaticamente; aqui solo reflejamos el
    // cambio en la interfaz.
    m_estadoActual = nuevoEstado;
    emit estadoCambiado(m_estadoActual);

    return true;
}
