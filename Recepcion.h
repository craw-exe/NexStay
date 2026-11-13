#ifndef RECEPCION_H
#define RECEPCION_H

#include <QObject>
#include <QString>
#include <QVariantList>
#include <QVariantMap>
#include <QtQml/qqmlregistration.h>

// Theme 10: flujo de recepcion completo.
// Antes, el registro de huesped solo era interfaz y no habia forma de
// hacer check-in ni check-out desde la app. Esta clase guarda al
// huesped y mueve una reserva por sus pasos:
//   confirmada --check-in--> estadia abierta (habitacion ocupada)
//              --check-out--> finalizada (habitacion en limpieza)
//   confirmada --cancelar--> cancelada
// Crear la reserva sigue en la clase Reserva (valida traslapes).
// Todo revisa el permiso en C++ y cada cambio de varias tablas va en
// una transaccion, para no dejar la base a medias si algo falla.
class Recepcion : public QObject
{
    Q_OBJECT
    QML_ELEMENT

public:
    explicit Recepcion(QObject *parent = nullptr);

    // Permiso ('huespedes','crear'). Devuelve el id del huesped o -1.
    // Theme 11: el correo es opcional.
    Q_INVOKABLE int registrarHuesped(const QString &nombre, const QString &apellido,
                                     const QString &documento, const QString &telefono,
                                     const QString &correo);

    // Huespedes cuyo nombre, apellido o documento contienen el texto.
    // Busca tambien por telefono (Theme 11).
    // Cada elemento: { idHuesped, nombre, documento, telefono }.
    Q_INVOKABLE QVariantList buscarHuespedes(const QString &texto, int limite = 20);

    // { idReserva, huesped, documento, numero, entrada, salida, estado,
    //   enEstadia, puedeCheckIn, puedeCheckOut, puedeCancelar }
    // Mapa vacio si no existe o no hay permiso.
    Q_INVOKABLE QVariantMap detalleReserva(int idReserva);

    Q_INVOKABLE bool checkIn(int idReserva);
    Q_INVOKABLE bool checkOut(int idReserva);
    Q_INVOKABLE bool cancelarReserva(int idReserva);

signals:
    void huespedRegistrado(int idHuesped, const QString &nombre);
    void operacionRealizada(const QString &mensaje);
    void operacionRechazada(const QString &motivo);

private:
    bool rechazar(const QString &motivo);
    bool autorizar(const QString &modulo, const QString &accion);
};

#endif // RECEPCION_H
