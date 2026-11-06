#ifndef ADMINISTRACIONUSUARIOS_H
#define ADMINISTRACIONUSUARIOS_H

#include <QObject>
#include <QString>
#include <QVariantList>
#include <QtQml/qqmlregistration.h>

// Theme 7, Task 3: administracion de usuarios y roles.
//
// Es la capa que usa PantallaAdministracion.qml para:
//   - listar, crear, activar/desactivar usuarios, cambiarles el rol y
//     restablecer su contrasena;
//   - consultar y editar la matriz de permisos (tabla Permisos) de cada
//     rol, que es la misma que ya gobierna menus y funciones desde el
//     Task 1 y el Task 2.
//
// Seguridad (defensa en profundidad, igual que el resto del proyecto):
// cada metodo vuelve a comprobar EN C++ que el usuario con sesion activa
// tenga el permiso ('usuarios', accion); que la pantalla oculte un boton
// no es la unica proteccion.
//   ver    -> usuarios(), roles(), permisos(), modulos()
//   crear  -> crearUsuario()
//   editar -> cambiarEstado(), cambiarRol(), restablecerContrasena(),
//             establecerPermiso()
//
// Reglas para que nadie se quede fuera del sistema por accidente:
//   - No puedes desactivar tu propia cuenta ni cambiar tu propio rol.
//   - Siempre debe quedar al menos un administrador activo.
//   - Al rol administrador no se le pueden quitar los permisos
//     ver/crear/editar del modulo 'usuarios'.
//
// Alcance: los 4 roles son fijos (administrador, recepcion, limpieza,
// mantenimiento). Crear roles nuevos queda fuera porque parte de la
// logica (filtro por tipo de solicitud) todavia reconoce roles por nombre.
class AdministracionUsuarios : public QObject
{
    Q_OBJECT
    QML_ELEMENT

public:
    explicit AdministracionUsuarios(QObject *parent = nullptr);

    // Cada elemento: idUsuario, nombre, apellido, correo, idRol, rol,
    // estado ("activo"/"inactivo"), esActual (es la cuenta con sesion).
    Q_INVOKABLE QVariantList usuarios();

    // Cada elemento: idRol, nombre.
    Q_INVOKABLE QVariantList roles();

    // Catalogo de modulos y acciones que se pueden asignar. Cada
    // elemento: modulo, acciones (lista de textos).
    Q_INVOKABLE QVariantList modulos() const;

    // Permisos concedidos hoy. Cada elemento: idRol, modulo, accion.
    Q_INVOKABLE QVariantList permisos();

    // true si el permiso (idRol, modulo, accion) no se puede quitar
    // (proteccion contra bloqueo del administrador).
    Q_INVOKABLE bool permisoBloqueado(int idRol, const QString &modulo,
                                      const QString &accion);

    Q_INVOKABLE bool crearUsuario(const QString &nombre, const QString &apellido,
                                  const QString &correo, const QString &contrasena,
                                  int idRol);
    Q_INVOKABLE bool cambiarEstado(int idUsuario, const QString &estado);
    Q_INVOKABLE bool cambiarRol(int idUsuario, int idRol);
    Q_INVOKABLE bool restablecerContrasena(int idUsuario, const QString &nueva);
    Q_INVOKABLE bool establecerPermiso(int idRol, const QString &modulo,
                                       const QString &accion, bool concedido);

signals:
    void operacionRechazada(const QString &motivo);
    void usuariosCambiaron();
    void permisosCambiaron();

private:
    // true si la sesion actual tiene ('usuarios', accion). Si idActual no
    // es nulo ahi se devuelve el id del usuario con sesion. Si no hay
    // permiso emite operacionRechazada (cuando avisar es true).
    bool autorizar(const QString &accion, int *idActual = nullptr, bool avisar = true);
    bool rechazar(const QString &motivo);

    int idRolPorNombre(const QString &nombre) const;
    // Cuantos administradores activos hay, sin contar a idExcluido.
    int administradoresActivosSin(int idExcluido) const;
};

#endif // ADMINISTRACIONUSUARIOS_H
