#ifndef REPORTES_H
#define REPORTES_H

#include <QObject>
#include <QVariantList>
#include <QVariantMap>
#include <QtQml/qqmlregistration.h>

// Theme 8: Reportes y vistas organizadas.
// Epic: dashboard de reportes en el perfil de administracion.
//
// Las tasks de la propuesta original (modelo de solicitud, vista por
// prioridad, asignacion de responsable y tiempos de atencion) ya se
// hicieron en el Theme 6. Lo que faltaba era juntar esa informacion en
// reportes para el administrador, y eso es lo que hace esta clase.
//
// Igual que BitacoraAcceso, esta clase solo LEE: no modifica ninguna
// tabla. Todas las cuentas (conteos, promedios, porcentaje de ocupacion)
// se hacen en SQL para que la pantalla solo tenga que dibujar.
class Reportes : public QObject
{
    Q_OBJECT
    QML_ELEMENT

public:
    explicit Reportes(QObject *parent = nullptr);

    // Permiso ('reportes','ver') de la tabla Permisos. Se revisa aqui en
    // C++ y no solo en el menu, igual que en las demas pantallas.
    Q_INVOKABLE bool puedeVerReportes();

    // Task 1: cuantas habitaciones hay en cada estado ahorita.
    // Regresa { total, porEstado: [ { estado, cantidad } ] }.
    Q_INVOKABLE QVariantMap estadoHabitaciones();

    // Task 1: ocupacion de los ultimos "dias" dias (incluye hoy).
    // nochesOcupadas cuenta solo los dias de cada reserva que caen dentro
    // del periodo. Regresa { inicio, fin, dias, totalHabitaciones,
    // nochesOcupadas, nochesDisponibles, porcentaje, reservasNuevas }.
    Q_INVOKABLE QVariantMap ocupacion(int dias = 30);

    // Task 2: solicitudes creadas en los ultimos "dias" dias.
    // Regresa { total, pendientes, enProceso, resueltas,
    //           porTipo: [ { tipo, total, resueltas,
    //                        promedioRespuesta, promedioResolucion } ],
    //           activasPorPrioridad: [ { prioridad, cantidad } ] }.
    // Los promedios van en minutos (-1 si todavia no hay datos).
    Q_INVOKABLE QVariantMap resumenSolicitudes(int dias = 30);

    // Task 2: habitaciones que necesitan limpieza: las que estan en
    // estado 'en limpieza' o tienen una solicitud de limpieza sin resolver.
    // Cada elemento: { numero, piso, estadoActual, solicitudesAbiertas }.
    Q_INVOKABLE QVariantList pendientesLimpieza();

    // Task 2: ultimas solicitudes de mantenimiento ya resueltas, con su
    // tiempo de respuesta y de resolucion en minutos.
    Q_INVOKABLE QVariantList historialMantenimiento(int limite = 20);
};

#endif // REPORTES_H
