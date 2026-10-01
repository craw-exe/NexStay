#include "Habitacion.h"
#include <QDebug>

Habitacion::Habitacion(QObject *parent)
    : QObject(parent)
{
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
        emit cambioRechazado(nuevoEstado);
        return false;
    }

    if (nuevoEstado == m_estadoActual) {
        return true; // Nada que hacer, ya está en ese estado
    }

    m_estadoActual = nuevoEstado;
    emit estadoCambiado(m_estadoActual);

    // TODO (Task 3 - "Sincronizar estado con la base de datos"):
    // aquí se insertará el registro correspondiente en Historial_Estado
    // y se actualizará Habitacion.estado_actual en la BD SQLite.

    return true;
}
