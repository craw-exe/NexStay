#ifndef SOLICITUDESHUESPED_H
#define SOLICITUDESHUESPED_H

#include <QHash>
#include <QObject>
#include <QString>
#include <QTimer>
#include <QtQml/qqmlregistration.h>

// Theme 5, Task 2: "protocolo de comunicacion app -> servidor".
//
// Decision de arquitectura (acordada con el equipo): NexStay todavia no
// tiene un servidor de red; todas las pantallas leen y escriben en el
// mismo SQLite. Por eso, el "protocolo" por ahora es esta capa: la
// pantalla del huesped NO hace SQL, solo le pide a esta clase dos cosas
// -cambiar su presencia o crear una solicitud- y la clase valida y
// deja el dato en la BD, que es el canal compartido con el personal.
//
//   - cambiarPresencia()  -> Estado_Presencia (dentro / fuera)
//   - crearSolicitud()    -> Solicitud_Servicio (origen = 'huesped')
//
// El aviso al personal lo hace AlertasPersonal (Task 3). Task 4: el
// camino de vuelta; cuando el personal marca una solicitud como
// atendida, esta clase lo detecta (revisa la BD cada 2 s) y emite
// solicitudAtendida() para que la pantalla se lo confirme al huesped.
// Si algun dia se agrega un
// servidor real, esta clase es el unico lugar que habria que cambiar
// para que envie estos mismos datos por red; las pantallas no.
//
// Igual que Habitacion, trabaja con la primera habitacion de la BD
// mientras no exista una forma de asociar cada pantalla a su habitacion.
class SolicitudesHuesped : public QObject
{
    Q_OBJECT
    QML_ELEMENT

    // "dentro", "fuera", o cadena vacia si aun no hay registro.
    Q_PROPERTY(QString presencia READ presencia NOTIFY presenciaCambiada)

public:
    explicit SolicitudesHuesped(QObject *parent = nullptr);

    QString presencia() const;

    // nuevoEstado: "dentro" o "fuera". Hace upsert en Estado_Presencia.
    Q_INVOKABLE bool cambiarPresencia(const QString &nuevoEstado);

    // tipo: "limpieza" o "mantenimiento". prioridad: "baja", "media"
    // (por defecto) o "alta". Se rechaza si la habitacion no tiene una
    // estadia abierta (no hay huesped al que atribuir la solicitud) o si
    // ya hay una solicitud pendiente/en proceso del mismo tipo.
    Q_INVOKABLE bool crearSolicitud(const QString &tipo,
                                    const QString &prioridad = QStringLiteral("media"));

signals:
    void presenciaCambiada(const QString &nuevoEstado);
    void solicitudCreada(const QString &tipo);
    // El personal marco como atendida una solicitud de esta habitacion.
    void solicitudAtendida(const QString &tipo);
    // Presencia o solicitud rechazada; el texto ya esta listo para
    // mostrarse al huesped.
    void operacionRechazada(const QString &motivo);

private slots:
    void revisarSolicitudesAtendidas();

private:
    void cargarDesdeBaseDeDatos();

    QTimer m_timer;
    // Solicitudes de esta habitacion aun sin resolver: id -> tipo.
    QHash<int, QString> m_enCurso;

    int m_idHabitacion = -1;
    QString m_presencia;
};

#endif // SOLICITUDESHUESPED_H
