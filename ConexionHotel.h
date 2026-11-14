#ifndef CONEXIONHOTEL_H
#define CONEXIONHOTEL_H

#include <QJsonObject>
#include <QObject>
#include <QTcpSocket>
#include <QTimer>
#include <QVariantList>
#include <QtQml/qqmlregistration.h>

// Theme 11 Task 6: lado del CELULAR del personal. Se conecta por WiFi al
// ServidorPersonal de la PC de recepcion, inicia sesion con la cuenta del
// empleado y mantiene la lista de solicitudes en vivo. Si el WiFi se
// corta, reintenta solo cada 3 segundos con la misma cuenta.
// La IP del hotel y el correo se recuerdan en el celular (la contrasena no).
class ConexionHotel : public QObject
{
    Q_OBJECT
    QML_ELEMENT

    // "desconectado", "conectando" o "conectado"
    Q_PROPERTY(QString estado READ estado NOTIFY estadoCambio)
    Q_PROPERTY(QString nombre READ nombre NOTIFY estadoCambio)
    Q_PROPERTY(QString rol READ rol NOTIFY estadoCambio)
    Q_PROPERTY(int idUsuario READ idUsuario NOTIFY estadoCambio)
    Q_PROPERTY(bool puedeAtender READ puedeAtender NOTIFY estadoCambio)
    Q_PROPERTY(QString servidor READ servidor NOTIFY estadoCambio)
    Q_PROPERTY(QString correoGuardado READ correoGuardado CONSTANT)
    // Mismos campos que AlertasPersonal::solicitudes.
    Q_PROPERTY(QVariantList solicitudes READ solicitudes NOTIFY solicitudesCambiaron)

public:
    explicit ConexionHotel(QObject *parent = nullptr);

    QString estado() const { return m_estado; }
    QString nombre() const { return m_nombre; }
    QString rol() const { return m_rol; }
    int idUsuario() const { return m_idUsuario; }
    bool puedeAtender() const { return m_puedeAtender; }
    QString servidor() const { return m_servidor; }
    QString correoGuardado() const;
    QVariantList solicitudes() const { return m_solicitudes; }

    // servidor: IP de la PC de recepcion, por ejemplo "192.168.1.20".
    Q_INVOKABLE void conectar(const QString &servidor, const QString &correo,
                              const QString &contrasena);
    Q_INVOKABLE void desconectar();
    Q_INVOKABLE void tomar(int idSolicitud);
    Q_INVOKABLE void atender(int idSolicitud);

signals:
    void estadoCambio();
    void solicitudesCambiaron();
    void nuevaSolicitud(int idSolicitud, const QString &tipo,
                        const QString &numeroHabitacion, const QString &prioridad);
    void error(const QString &motivo);
    void aviso(const QString &mensaje);

private:
    void ponerEstado(const QString &estado);
    void abrirSocket();
    void leer();
    void procesar(const QJsonObject &mensaje);
    void enviar(const QJsonObject &mensaje);
    void perdida();

    QTcpSocket m_socket;
    QTimer m_reintento;
    QTimer m_tiempoLimite;
    QByteArray m_pendiente;

    QString m_estado = QStringLiteral("desconectado");
    QString m_servidor;
    quint16 m_puerto = 5150;
    QString m_correo;
    QString m_contrasena;
    bool m_quiereConexion = false;  // el usuario pidio conectarse
    bool m_sesionValida = false;    // ya entro al menos una vez

    QString m_nombre;
    QString m_rol;
    int m_idUsuario = -1;
    bool m_puedeAtender = false;
    QVariantList m_solicitudes;
};

#endif // CONEXIONHOTEL_H
