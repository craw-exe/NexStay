#ifndef HABITACION_H
#define HABITACION_H

#include <QObject>
#include <QString>
#include <QStringList>
#include <QtQml/qqmlregistration.h>

// Representa la habitación mostrada en la pantalla táctil.
// Expone el estado actual a QML y valida cada cambio de estado
// contra la lista de estados permitidos (Theme 2, Task 2).
class Habitacion : public QObject
{
    Q_OBJECT
    QML_ELEMENT

    Q_PROPERTY(int numero READ numero CONSTANT)
    Q_PROPERTY(int piso READ piso CONSTANT)
    Q_PROPERTY(QString tipo READ tipo CONSTANT)
    Q_PROPERTY(int capacidad READ capacidad CONSTANT)
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

    // Intenta cambiar el estado de la habitación.
    // Devuelve true si el estado era válido y se aplicó el cambio.
    // La sincronización con la base de datos se añadirá en el
    // siguiente task ("Sincronizar estado con la base de datos").
    Q_INVOKABLE bool cambiarEstado(const QString &nuevoEstado);

signals:
    void estadoCambiado(const QString &nuevoEstado);
    void cambioRechazado(const QString &estadoInvalido);

private:
    int m_numero = 204;
    int m_piso = 2;
    QString m_tipo = QStringLiteral("Doble");
    int m_capacidad = 2;
    QString m_estadoActual = QStringLiteral("ocupada");

    // Mismos 5 estados definidos en el CHECK de la tabla Habitacion (Sprint 1).
    const QStringList m_estadosValidos = {
        QStringLiteral("ocupada"),
        QStringLiteral("libre"),
        QStringLiteral("en limpieza"),
        QStringLiteral("reservada"),
        QStringLiteral("fuera de servicio")
    };
};

#endif // HABITACION_H
