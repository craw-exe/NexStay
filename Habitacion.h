#ifndef HABITACION_H
#define HABITACION_H

#include <QObject>
#include <QString>
#include <QStringList>
#include <QTimer>
#include <QtQml/qqmlregistration.h>

// Representa la habitacion mostrada en la pantalla tactil.
// Carga sus datos desde la tabla Habitacion (SQLite) y, al cambiar de
// estado, escribe el cambio en la base de datos: el trigger
// trg_actualizar_historial se encarga de dejar constancia en
// Historial_Estado automaticamente (Theme 2, Task 2 y Task 3).
//
// Ademas, consulta periodicamente la BD (Task 4): si otro perfil u
// otra instancia de la app cambio el estado de esta misma habitacion,
// esta pantalla lo detecta sola y se actualiza, sin que nadie tenga
// que cerrar y volver a abrir la aplicacion.
class Habitacion : public QObject
{
    Q_OBJECT
    QML_ELEMENT

    Q_PROPERTY(int numero READ numero NOTIFY datosCargados)
    Q_PROPERTY(int piso READ piso NOTIFY datosCargados)
    Q_PROPERTY(QString tipo READ tipo NOTIFY datosCargados)
    Q_PROPERTY(int capacidad READ capacidad NOTIFY datosCargados)
    Q_PROPERTY(QString estadoActual READ estadoActual NOTIFY estadoCambiado)
    Q_PROPERTY(QStringList estadosDisponibles READ estadosDisponibles CONSTANT)

public:
    explicit Habitacion(QObject *parent = nullptr);

    int numero() const;
    int piso() const;
    QString tipo() const;
    int capacidad() const;
    QString estadoActual() const;
    QStringList estadosDisponibles() const;

    // Intenta cambiar el estado de la habitacion y lo guarda en la BD.
    // Devuelve true si el estado era valido y el UPDATE se aplico.
    Q_INVOKABLE bool cambiarEstado(const QString &nuevoEstado);

signals:
    void datosCargados();
    void estadoCambiado(const QString &nuevoEstado);
    void cambioRechazado(const QString &motivo);

private slots:
    // Vuelve a preguntarle a la BD cual es el estado actual (consulta
    // ligera, solo esa columna) y, si cambio desde afuera, actualiza
    // la interfaz. Se llama sola cada 2 segundos mientras la pantalla
    // esta abierta.
    void refrescarEstadoDesdeBaseDeDatos();

private:
    // Carga la primera habitacion que encuentre en la BD (por ahora
    // solo existe la de demostracion, numero 204). Cuando exista el
    // modulo de reservas/login (Theme 3/4), esto se reemplazara por
    // "cargar la habitacion asociada a esta pantalla".
    void cargarDesdeBaseDeDatos();

    QTimer m_timerActualizacion;

    int m_idHabitacion = -1;
    int m_numero = 0;
    int m_piso = 0;
    QString m_tipo;
    int m_capacidad = 0;
    QString m_estadoActual;

    // Mismos 5 estados definidos en el CHECK de la tabla Habitacion.
    const QStringList m_estadosValidos = {
        QStringLiteral("ocupada"),
        QStringLiteral("libre"),
        QStringLiteral("en limpieza"),
        QStringLiteral("reservada"),
        QStringLiteral("fuera de servicio")
    };
};

#endif // HABITACION_H
