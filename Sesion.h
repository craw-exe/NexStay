#ifndef SESION_H
#define SESION_H

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

    // Se llama una vez al arrancar la app (ver PantallaLogin.qml,
    // Component.onCompleted): si Sesion_Actual ya tenia un usuario
    // guardado de una sesion anterior que no se cerro explicitamente,
    // lo recupera sin pedir contrasena de nuevo.
    Q_INVOKABLE void restaurarSesionGuardada();

signals:
    // Se emite tanto al iniciar como al cerrar sesion (cualquier
    // cambio del usuario activo). Las Q_PROPERTY de arriba usan esta
    // misma senal como NOTIFY.
    void sesionCambio();
    void sesionRechazada(const QString &motivo);

private:
    // SHA-256 en hexadecimal. Nota de alcance: Qt no trae bcrypt ni
    // argon2 "de fabrica" (que es lo recomendado para contrasenas en
    // produccion, como ya advertia el propio script SQL del Sprint 2);
    // usar una libreria externa de esas era mas complejidad de la que
    // amerita este proyecto escolar. SHA-256 al menos evita guardar
    // la contrasena en texto plano, que era el requisito minimo.
    static QString hashContrasena(const QString &contrasenaPlano);

    bool cargarUsuarioPorId(int idUsuario);
    void limpiarSesion();

    int m_idUsuario = -1;
    QString m_nombreCompleto;
    QString m_correo;
    QString m_nombreRol;
};

#endif // SESION_H
