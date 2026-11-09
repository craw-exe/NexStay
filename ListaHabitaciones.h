#ifndef LISTAHABITACIONES_H
#define LISTAHABITACIONES_H

#include <QObject>
#include <QVariantList>
#include <QtQml/qqmlregistration.h>

// Lista de todas las habitaciones del hotel para el personal.
// Solo LEE la base: el estado de cada habitacion se sigue cambiando desde
// la pantalla de la habitacion (Habitacion) y las solicitudes.
class ListaHabitaciones : public QObject
{
    Q_OBJECT
    QML_ELEMENT

public:
    explicit ListaHabitaciones(QObject *parent = nullptr);

    // Permiso ('habitaciones','ver') del usuario de la sesion, revisado
    // en C++ igual que en las demas pantallas.
    Q_INVOKABLE bool puedeVer();

    // Todas las habitaciones ordenadas por piso y numero. Cada elemento:
    // { numero, piso, tipo, capacidad, estado, huesped, salida }.
    // huesped/salida vienen vacios si hoy no hay una reserva confirmada.
    Q_INVOKABLE QVariantList habitaciones();
};

#endif // LISTAHABITACIONES_H
