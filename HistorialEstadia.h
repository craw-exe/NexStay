#ifndef HISTORIALESTADIA_H
#define HISTORIALESTADIA_H

#include <QObject>
#include <QString>
#include <QVariantList>
#include <QtQml/qqmlregistration.h>

// Theme 3, Task 3: historial de estadias por huesped.
//
// Una "Reserva" (Theme 3, Task 2) es la intencion de hospedarse en
// ciertas fechas. Una "Estadia" (tabla Historial_Estadia) es el hecho
// real de que el huesped ya esta físicamente en la habitacion: se abre
// con el check-in (fecha_entrada_real) y se cierra con el check-out
// (fecha_salida_real). Mientras fecha_salida_real sea NULL, la estadia
// se considera "abierta".
//
// Esta distincion importa para Theme 4: el trigger
// trg_forzar_intento_fallido_huesped (Sprint 2) solo deja pasar al
// huesped por la puerta si tiene una fila en Historial_Estadia con
// fecha_salida_real IS NULL para esa habitacion. Es decir, el check-in
// que se hace aqui es lo que luego habilita su acceso.
class HistorialEstadia : public QObject
{
    Q_OBJECT
    QML_ELEMENT

public:
    explicit HistorialEstadia(QObject *parent = nullptr);

    // Abre una nueva estadia (check-in real) para un huesped en una
    // habitacion. idReserva es opcional (-1 si la estadia no viene de
    // una reserva previa, por ejemplo un huesped que se registra en el
    // momento). Devuelve el id_estadia creado, o -1 si fue rechazado.
    Q_INVOKABLE int registrarCheckIn(int idHuesped, int idHabitacion, int idReserva = -1);

    // Cierra la estadia abierta (check-out real), guardando la fecha
    // y hora actuales como fecha_salida_real. Devuelve true si se
    // actualizo una estadia que seguia abierta.
    Q_INVOKABLE bool registrarCheckOut(int idEstadia);

    // Devuelve el historial de estadias de un huesped (mas reciente
    // primero), listo para alimentar un ListView/Repeater en QML.
    // Cada elemento trae: idEstadia, idHabitacion, numeroHabitacion,
    // fechaEntradaReal, fechaSalidaReal (cadena vacia si sigue abierta).
    Q_INVOKABLE QVariantList historialPorHuesped(int idHuesped);

signals:
    void checkInRegistrado(int idEstadia);
    void checkOutRegistrado(int idEstadia);
    void operacionRechazada(const QString &motivo);

private:
    // true si este huesped ya tiene una estadia sin cerrar en esa
    // habitacion (evita abrir dos veces la misma estadia por error).
    bool tieneEstadiaAbierta(int idHuesped, int idHabitacion);
};

#endif // HISTORIALESTADIA_H
