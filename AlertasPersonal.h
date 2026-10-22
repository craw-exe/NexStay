#ifndef ALERTASPERSONAL_H
#define ALERTASPERSONAL_H

#include <QObject>
#include <QString>
#include <QTimer>
#include <QVariantList>
#include <QtQml/qqmlregistration.h>

// Theme 5, Task 3: notificacion/alerta al personal.
//
// Es el lado "receptor" de lo que SolicitudesHuesped (Task 2) deja en
// Solicitud_Servicio: revisa la BD cada 2 segundos (mismo mecanismo que
// ya usa Habitacion, posible gracias al modo WAL de Database.cpp) y,
// cuando aparece una solicitud NUEVA que le corresponde al usuario con
// sesion activa, emite nuevaSolicitud() para que la pantalla muestre
// una alerta. Tambien mantiene la lista de solicitudes pendientes.
//
// Que le toca a cada quien:
//   - limpieza       -> solo solicitudes de tipo "limpieza"
//   - mantenimiento  -> solo solicitudes de tipo "mantenimiento"
//   - administrador / recepcion -> todas
// y solo si su rol tiene el permiso ('solicitudes', 'ver'). Sin sesion
// activa no se alerta a nadie.
//
// Limite conocido: es una alerta DENTRO de la app (la app debe estar
// abierta). Una notificacion con la app cerrada o en segundo plano, como
// un push al celular, requiere un servidor, que se descarto por ahora.
//
// No cambia el estado de ninguna solicitud: atenderlas es el Task 4 de
// este Theme y la gestion completa es el Theme 6.
class AlertasPersonal : public QObject
{
    Q_OBJECT
    QML_ELEMENT

    // Solicitudes pendientes visibles para el usuario actual, ordenadas
    // por prioridad (alta primero) y luego por antiguedad. Cada elemento:
    // idSolicitud, numeroHabitacion, tipo, prioridad, fechaCreacion.
    Q_PROPERTY(QVariantList solicitudes READ solicitudes NOTIFY solicitudesCambiaron)

public:
    explicit AlertasPersonal(QObject *parent = nullptr);

    QVariantList solicitudes() const;

signals:
    void solicitudesCambiaron();
    void nuevaSolicitud(int idSolicitud, const QString &tipo,
                        const QString &numeroHabitacion, const QString &prioridad);

private slots:
    void refrescar();

private:
    // Rol del usuario con sesion activa, o cadena vacia si no hay
    // sesion o su rol no tiene el permiso ('solicitudes','ver').
    QString rolConPermiso() const;

    QTimer m_timer;
    int m_ultimoIdVisto = 0;
    QVariantList m_solicitudes;
};

#endif // ALERTASPERSONAL_H
