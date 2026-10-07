#ifndef CALENDARIORESERVAS_H
#define CALENDARIORESERVAS_H

#include <QObject>
#include <QString>
#include <QStringList>
#include <QVariantList>
#include <QtQml/qqmlregistration.h>

// Theme 3, Task 4: vista de calendario de reservas (estilo Gantt:
// habitaciones en filas, dias en columnas).
//
// Esta clase solo LEE de la base de datos y le entrega a QML datos ya
// listos para dibujar la cuadricula, para no tener que resolver fechas
// ni hacer SQL desde el QML:
//   - habitaciones(): una fila por habitacion (para el eje vertical).
//   - rangoFechas(): los dias a mostrar como lista de cadenas
//     "yyyy-MM-dd" (para el eje horizontal). Se genera en C++ con
//     QDate en vez de con el objeto Date de JavaScript, para evitar
//     los problemas de zona horaria que ese objeto suele dar.
//   - reservasEntre(): las reservas confirmadas que tocan ese rango de
//     fechas, con el nombre del huesped ya incluido (via JOIN), listas
//     para que QML las use para pintar las celdas ocupadas.
class CalendarioReservas : public QObject
{
    Q_OBJECT
    QML_ELEMENT

public:
    explicit CalendarioReservas(QObject *parent = nullptr);

    // Fecha de hoy en formato "yyyy-MM-dd", para usar como punto de
    // partida del calendario al abrir la pantalla.
    Q_INVOKABLE QString hoy() const;

    // Lista de "dias" fechas consecutivas en formato "yyyy-MM-dd",
    // empezando en fechaInicio (incluida).
    Q_INVOKABLE QStringList rangoFechas(const QString &fechaInicio, int dias) const;

    // Suma (o resta, si dias es negativo) dias a una fecha
    // "yyyy-MM-dd" y devuelve el resultado en el mismo formato. Se usa
    // para la navegacion "semana anterior / semana siguiente" del
    // calendario, evitando manejar fechas a mano en QML.
    Q_INVOKABLE QString sumarDias(const QString &fecha, int dias) const;

    // Todas las habitaciones, ordenadas por numero. Cada elemento trae:
    // idHabitacion, numero, tipo.
    Q_INVOKABLE QVariantList habitaciones();

    // Reservas CONFIRMADAS cuyo rango de fechas se cruza con
    // [fechaInicio, fechaFin). Cada elemento trae: idReserva,
    // idHabitacion, fechaEntrada, fechaSalida, nombreHuesped.
    Q_INVOKABLE QVariantList reservasEntre(const QString &fechaInicio, const QString &fechaFin);
};

#endif // CALENDARIORESERVAS_H
