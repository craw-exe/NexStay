#ifndef RESERVA_H
#define RESERVA_H

#include <QObject>
#include <QString>
#include <QtQml/qqmlregistration.h>

// Theme 3, Task 2: logica de validacion de disponibilidad.
//
// Antes de crear una reserva, hay que comprobar que la habitacion no
// tenga ya otra reserva "confirmada" cuyas fechas se traslapen con las
// solicitadas. Esta clase hace esa comprobacion en C++ (para poder
// mostrar un mensaje claro en la interfaz antes de intentar guardar),
// con la MISMA regla que ya usan los triggers trg_validar_traslape_*
// del Sprint 2 en la base de datos:
//
//   nueva.fecha_entrada < existente.fecha_salida
//   Y nueva.fecha_salida  > existente.fecha_entrada
//
// Esos triggers se dejan activos a proposito como segunda linea de
// defensa: si dos recepcionistas intentaran reservar la misma
// habitacion al mismo tiempo (condicion de carrera), la validacion de
// aqui podria dejar pasar a ambas por una fraccion de segundo, pero el
// trigger de la base de datos rechazaria el INSERT duplicado de todas
// formas. Por eso crearReserva() tambien revisa si el INSERT fallo.
class Reserva : public QObject
{
    Q_OBJECT
    QML_ELEMENT

public:
    explicit Reserva(QObject *parent = nullptr);

    // Solo consulta, no modifica nada. Devuelve true si la habitacion
    // esta libre para ese rango de fechas (sin reservas confirmadas
    // que se traslapen). Fechas en formato "yyyy-MM-dd".
    Q_INVOKABLE bool habitacionDisponible(int idHabitacion,
                                           const QString &fechaEntrada,
                                           const QString &fechaSalida);

    // Valida fechas + disponibilidad y, si todo esta correcto, inserta
    // la reserva (estado_reserva queda 'confirmada' por defecto).
    // Devuelve true si se creo correctamente; en caso de rechazo,
    // devuelve false y emite reservaRechazada con el motivo.
    Q_INVOKABLE bool crearReserva(int idHuesped,
                                   int idHabitacion,
                                   const QString &fechaEntrada,
                                   const QString &fechaSalida);

signals:
    void reservaCreada(int idReserva);
    void reservaRechazada(const QString &motivo);

private:
    // Valida formato y orden de las fechas (salida > entrada).
    // Si algo esta mal, llena motivoError y devuelve false.
    bool fechasValidas(const QString &fechaEntrada,
                        const QString &fechaSalida,
                        QString *motivoError) const;
};

#endif // RESERVA_H
