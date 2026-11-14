#ifndef SERVIDORPERSONAL_H
#define SERVIDORPERSONAL_H

#include <QDateTime>
#include <QHash>
#include <QJsonObject>
#include <QObject>
#include <QTcpServer>
#include <QTimer>
#include <QVariantList>
#include <QtQml/qqmlregistration.h>

class QTcpSocket;

// Theme 11 Task 6: servidor del personal.
//
// Corre dentro de la app de la PC de recepcion (la que tiene la base de
// datos). Los celulares del personal se conectan por el WiFi del hotel
// (puerto kPuerto) para ver las solicitudes de los cuartos en vivo,
// recibir el aviso de las nuevas y tomarlas o terminarlas. Lo que hacen
// en el celular se guarda en la misma base, asi que la PC lo ve, y al
// reves.
//
// Protocolo: una linea de JSON por mensaje.
//   Celular -> PC: {"cmd":"login","correo","contrasena"}
//                  {"cmd":"tomar","id"}  {"cmd":"atender","id"}
//   PC -> celular: {"tipo":"login","ok",...}  {"tipo":"lista","solicitudes"}
//                  {"tipo":"nueva",...}       {"tipo":"resultado","ok",...}
//
// Las reglas (que le toca a cada rol, quien puede tomar/terminar) son
// las mismas de AlertasPersonal, que se reutilizan. El login usa la
// misma verificacion PBKDF2 de Sesion y su propio bloqueo por intentos.
//
// Limite conocido: la conexion no va cifrada (red local del hotel) y la
// app del celular debe estar abierta para recibir avisos.
class ServidorPersonal : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    Q_PROPERTY(bool activo READ activo NOTIFY cambio)
    Q_PROPERTY(QString direccion READ direccion NOTIFY cambio)
    Q_PROPERTY(int celulares READ celulares NOTIFY cambio)

public:
    static constexpr quint16 kPuerto = 5150;

    explicit ServidorPersonal(QObject *parent = nullptr);

    bool activo() const;
    QString direccion() const;   // IP de esta PC en la red local
    int celulares() const;       // celulares con sesion iniciada

signals:
    void cambio();

private slots:
    void nuevaConexion();
    void revisar();

private:
    struct Cliente {
        int idUsuario = -1;
        QString rol;
        QVariantList ultimaLista;
        QByteArray pendiente;
    };
    struct Intentos {
        int fallos = 0;
        QDateTime bloqueadoHasta;
    };

    void procesar(QTcpSocket *socket, const QJsonObject &mensaje);
    void iniciarSesion(QTcpSocket *socket, const QJsonObject &mensaje);
    void enviar(QTcpSocket *socket, const QJsonObject &mensaje);
    void enviarLista(QTcpSocket *socket, bool forzar);

    QTcpServer m_servidor;
    QTimer m_timer;
    QHash<QTcpSocket *, Cliente> m_clientes;
    QHash<QString, Intentos> m_intentos;
    int m_ultimoIdVisto = 0;
};

#endif // SERVIDORPERSONAL_H
