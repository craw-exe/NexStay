#ifndef SESION_H
#define SESION_H

#include <QDateTime>
#include <QHash>
#include <QObject>
#include <QString>
#include <QtQml/qqmlregistration.h>

// Theme 4, Task 2: logica de autenticacion en C++.
//
// Sesion es un singleton QML: una sola instancia compartida por toda
// la app (igual que la fila unica de Sesion_Actual en la base de
// datos, que ya traia el esquema del Sprint 2). Cualquier pantalla
// QML puede leer "Sesion.nombreCompleto" o "Sesion.nombreRol" sin
// tener que volver a consultar la BD ni pasarse el usuario de
// pantalla en pantalla (eso es justo lo que necesitara Theme 7 para
// decidir que vistas mostrar segun el rol).
//
// iniciarSesion() valida correo + contrasena contra la tabla Usuario:
//   1. Busca un usuario ACTIVO con ese correo.
//   2. Compara el hash de la contrasena ingresada contra el hash
//      guardado (nunca se compara ni se guarda texto plano).
//   3. Si coincide, guarda el usuario en memoria Y actualiza
//      Sesion_Actual en la BD (fila id=1), que es lo que ya usa el
//      trigger trg_actualizar_historial del Sprint 2 para saber quien
//      hizo cada cambio de estado de habitacion.
//
// Importante: ante un error, el mensaje es el mismo sin importar si
// fallo el correo o la contrasena ("Correo o contrasena incorrectos"),
// para no darle a quien intenta entrar una pista de cual de los dos
// esta mal (practica basica de seguridad).
class Sesion : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    Q_PROPERTY(bool haySesion READ haySesion NOTIFY sesionCambio)
    Q_PROPERTY(int idUsuario READ idUsuario NOTIFY sesionCambio)
    Q_PROPERTY(QString nombreCompleto READ nombreCompleto NOTIFY sesionCambio)
    Q_PROPERTY(QString correo READ correo NOTIFY sesionCambio)
    Q_PROPERTY(QString nombreRol READ nombreRol NOTIFY sesionCambio)

public:
    explicit Sesion(QObject *parent = nullptr);

    bool haySesion() const;
    int idUsuario() const;
    QString nombreCompleto() const;
    QString correo() const;
    QString nombreRol() const;

    // Intenta iniciar sesion. Devuelve true si las credenciales son
    // correctas (y entonces deja la sesion activa); false en caso
    // contrario (y emite sesionRechazada con el motivo).
    Q_INVOKABLE bool iniciarSesion(const QString &correo, const QString &contrasena);

    // Cierra la sesion activa (limpia memoria y Sesion_Actual en la BD).
    Q_INVOKABLE void cerrarSesion();

    // Theme 10 (seguridad): ya no se recupera la sesion anterior sin
    // contrasena. Al abrir la app se limpia Sesion_Actual y siempre se
    // pide login (antes, quien abriera la app entraba con el ultimo
    // usuario, aunque fuera el administrador).
    Q_INVOKABLE void restaurarSesionGuardada();

    // Theme 10 (seguridad): la contrasena se guarda como
    // "pbkdf2$<vueltas>$<sal hex>$<hash hex>" con PBKDF2-HMAC-SHA256 y
    // una sal aleatoria por usuario. Asi dos usuarios con la misma
    // contrasena no tienen el mismo hash y probar contrasenas a la
    // fuerza es mucho mas lento. Lo usa tambien AdministracionUsuarios.
    static QString hashContrasena(const QString &contrasenaPlano);

    // Compara una contrasena contra lo guardado. Acepta tambien el
    // formato viejo (SHA-256 sin sal) para no dejar fuera a nadie; esos
    // hashes se reemplazan por el nuevo la primera vez que el usuario entra.
    static bool verificarContrasena(const QString &contrasenaPlano, const QString &guardado);
    static bool esHashAntiguo(const QString &guardado);

    // PBKDF2-HMAC-SHA256 (RFC 8018) de 32 bytes. Publica para probarla
    // con los vectores conocidos en las pruebas unitarias.
    static QByteArray pbkdf2Sha256(const QByteArray &contrasena, const QByteArray &sal, int vueltas);

    // Bloqueo por intentos fallidos: tras kMaxIntentos errores seguidos
    // con el mismo correo, ese correo no puede entrar por kMinutosBloqueo.
    static constexpr int kMaxIntentos = 5;
    static constexpr int kMinutosBloqueo = 5;

signals:
    // Se emite tanto al iniciar como al cerrar sesion (cualquier
    // cambio del usuario activo). Las Q_PROPERTY de arriba usan esta
    // misma senal como NOTIFY.
    void sesionCambio();
    void sesionRechazada(const QString &motivo);

private:

    bool cargarUsuarioPorId(int idUsuario);
    void limpiarSesion();

    // Intentos fallidos por correo (en memoria).
    // shortcut: se reinician al cerrar la app; guardarlos en la base si
    // se necesita que el bloqueo sobreviva a un reinicio.
    struct Intentos { int fallos = 0; QDateTime bloqueadoHasta; };
    QHash<QString, Intentos> m_intentos;
    bool registrarFallo(const QString &correo);

    int m_idUsuario = -1;
    QString m_nombreCompleto;
    QString m_correo;
    QString m_nombreRol;
};

#endif // SESION_H
