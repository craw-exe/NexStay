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
// Task 4: tambien es el lado del personal para CONFIRMAR que una
// solicitud ya fue atendida (marcarAtendida). El huesped se entera por
// SolicitudesHuesped, que revisa la BD y emite solicitudAtendida(). El
// flujo completo de gestion (asignar responsable, "en proceso",
// reportes) es el Theme 6.
class AlertasPersonal : public QObject
{
    Q_OBJECT
    QML_ELEMENT

    // Solicitudes ABIERTAS (pendientes o en proceso) visibles para el
    // usuario actual, ordenadas por prioridad (alta primero) y luego por
    // antiguedad. Cada elemento: idSolicitud, numeroHabitacion, tipo,
    // prioridad, origen, estado, idResponsable (0 si no tiene),
    // responsable (nombre, vacio si no tiene), fechaCreacion y
    // minutosEspera (Theme 6, Tasks 2 y 3).
    Q_PROPERTY(QVariantList solicitudes READ solicitudes NOTIFY solicitudesCambiaron)

public:
    explicit AlertasPersonal(QObject *parent = nullptr);

    QVariantList solicitudes() const;

    // true si el rol de la sesion actual tiene el permiso
    // ('solicitudes','editar'), es decir, puede marcar solicitudes como
    // atendidas. Sirve para mostrar u ocultar el boton "Atender".
    Q_INVOKABLE bool puedeAtender() const;

    // Theme 6, Task 3: el usuario con sesion TOMA la solicitud: pasa de
    // 'pendiente' a 'en_proceso', queda como responsable y se registra
    // fecha_atencion. Asi nadie mas la toma y se sabe quien la atiende.
    // Rechaza si el rol no puede editar solicitudes, si no le
    // corresponde por tipo, o si otra persona ya la tomo o la resolvio.
    Q_INVOKABLE bool tomarSolicitud(int idSolicitud);

    // Marca la solicitud como atendida (estado 'resuelta'), dejando
    // constancia de quien la atendio y cuando. Rechaza si no hay
    // sesion, si el rol no puede editar solicitudes, si la solicitud no
    // le corresponde a su rol (limpieza solo limpieza, etc.) o si ya
    // estaba atendida. Si esta en proceso, solo la puede terminar su
    // responsable o un administrador.
    Q_INVOKABLE bool marcarAtendida(int idSolicitud);

signals:
    void solicitudTomada(int idSolicitud);
    void solicitudAtendida(int idSolicitud);
    void operacionRechazada(const QString &motivo);
    void solicitudesCambiaron();
    void nuevaSolicitud(int idSolicitud, const QString &tipo,
                        const QString &numeroHabitacion, const QString &prioridad);

private slots:
    void refrescar();

private:
    // Rol del usuario con sesion activa, o cadena vacia si no hay
    // sesion o su rol no tiene el permiso ('solicitudes', accion).
    // Si idUsuario no es nulo, ahi se devuelve el id de ese usuario.
    QString rolConPermiso(const QString &accion, int *idUsuario = nullptr) const;

    QTimer m_timer;
    int m_ultimoIdVisto = 0;
    QVariantList m_solicitudes;
};

#endif // ALERTASPERSONAL_H
