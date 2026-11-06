#include "AdministracionUsuarios.h"

#include "Sesion.h"

#include <QDebug>
#include <QRegularExpression>
#include <QSqlError>
#include <QSqlQuery>
#include <QVariantMap>

namespace
{
    constexpr int kLargoMinimoContrasena = 6;

    // Modulos y acciones asignables. 'entrar' (acceso fisico a la
    // habitacion) solo tiene sentido en 'habitaciones'; bitacora y
    // reportes solo se consultan.
    struct ModuloDef {
        const char *modulo;
        QStringList acciones;
    };

    const QList<ModuloDef> &catalogo()
    {
        static const QList<ModuloDef> c = {
            { "habitaciones", { "ver", "crear", "editar", "eliminar", "entrar" } },
            { "huespedes",    { "ver", "crear", "editar", "eliminar" } },
            { "reservas",     { "ver", "crear", "editar", "eliminar" } },
            { "solicitudes",  { "ver", "crear", "editar", "eliminar" } },
            { "usuarios",     { "ver", "crear", "editar", "eliminar" } },
            { "bitacora",     { "ver" } },
            { "reportes",     { "ver" } },
        };
        return c;
    }

    bool permisoValido(const QString &modulo, const QString &accion)
    {
        for (const ModuloDef &m : catalogo()) {
            if (modulo == QLatin1String(m.modulo)) {
                return m.acciones.contains(accion);
            }
        }
        return false;
    }

    bool esAccionProtegidaDelAdmin(const QString &modulo, const QString &accion)
    {
        return modulo == QLatin1String("usuarios")
               && (accion == QLatin1String("ver") || accion == QLatin1String("crear")
                   || accion == QLatin1String("editar"));
    }
}

AdministracionUsuarios::AdministracionUsuarios(QObject *parent)
    : QObject(parent)
{
}

bool AdministracionUsuarios::rechazar(const QString &motivo)
{
    emit operacionRechazada(motivo);
    return false;
}

bool AdministracionUsuarios::autorizar(const QString &accion, int *idActual, bool avisar)
{
    QSqlQuery query;
    query.prepare(QStringLiteral(
        "SELECT u.id_usuario "
        "FROM Sesion_Actual s "
        "JOIN Usuario u ON u.id_usuario = s.id_usuario AND u.estado = 'activo' "
        "WHERE s.id = 1 "
        "  AND EXISTS (SELECT 1 FROM Permisos p WHERE p.id_rol = u.id_rol "
        "              AND p.modulo = 'usuarios' AND p.accion_permitida = :accion)"));
    query.bindValue(":accion", accion);

    if (!query.exec() || !query.next()) {
        if (avisar) {
            emit operacionRechazada(tr("Tu rol no tiene permiso para esta operación."));
        }
        return false;
    }
    if (idActual) {
        *idActual = query.value(0).toInt();
    }
    return true;
}

int AdministracionUsuarios::idRolPorNombre(const QString &nombre) const
{
    QSqlQuery query;
    query.prepare(QStringLiteral("SELECT id_rol FROM Rol WHERE nombre = :n"));
    query.bindValue(":n", nombre);
    return (query.exec() && query.next()) ? query.value(0).toInt() : -1;
}

int AdministracionUsuarios::administradoresActivosSin(int idExcluido) const
{
    QSqlQuery query;
    query.prepare(QStringLiteral(
        "SELECT COUNT(*) FROM Usuario u JOIN Rol r ON r.id_rol = u.id_rol "
        "WHERE r.nombre = 'administrador' AND u.estado = 'activo' "
        "  AND u.id_usuario <> :excluido"));
    query.bindValue(":excluido", idExcluido);
    return (query.exec() && query.next()) ? query.value(0).toInt() : 0;
}

QVariantList AdministracionUsuarios::usuarios()
{
    QVariantList lista;
    int idActual = -1;
    if (!autorizar(QStringLiteral("ver"), &idActual, false)) {
        return lista;
    }

    QSqlQuery query;
    if (!query.exec(QStringLiteral(
            "SELECT u.id_usuario, u.nombre, u.apellido, u.correo, u.id_rol, "
            "       r.nombre AS rol, u.estado "
            "FROM Usuario u JOIN Rol r ON r.id_rol = u.id_rol "
            "ORDER BY (u.estado = 'activo') DESC, u.nombre COLLATE NOCASE, u.apellido COLLATE NOCASE"))) {
        qWarning() << "usuarios():" << query.lastError().text();
        return lista;
    }
    while (query.next()) {
        QVariantMap u;
        u["idUsuario"] = query.value("id_usuario");
        u["nombre"] = query.value("nombre");
        u["apellido"] = query.value("apellido");
        u["correo"] = query.value("correo");
        u["idRol"] = query.value("id_rol");
        u["rol"] = query.value("rol");
        u["estado"] = query.value("estado");
        u["esActual"] = query.value("id_usuario").toInt() == idActual;
        lista.append(u);
    }
    return lista;
}

QVariantList AdministracionUsuarios::roles()
{
    QVariantList lista;
    if (!autorizar(QStringLiteral("ver"), nullptr, false)) {
        return lista;
    }
    QSqlQuery query;
    if (query.exec(QStringLiteral("SELECT id_rol, nombre FROM Rol ORDER BY id_rol"))) {
        while (query.next()) {
            QVariantMap r;
            r["idRol"] = query.value(0);
            r["nombre"] = query.value(1);
            lista.append(r);
        }
    }
    return lista;
}

QVariantList AdministracionUsuarios::modulos() const
{
    QVariantList lista;
    for (const ModuloDef &m : catalogo()) {
        QVariantMap mapa;
        mapa["modulo"] = QString::fromLatin1(m.modulo);
        mapa["acciones"] = m.acciones;
        lista.append(mapa);
    }
    return lista;
}

QVariantList AdministracionUsuarios::permisos()
{
    QVariantList lista;
    if (!autorizar(QStringLiteral("ver"), nullptr, false)) {
        return lista;
    }
    QSqlQuery query;
    if (query.exec(QStringLiteral(
            "SELECT id_rol, modulo, accion_permitida FROM Permisos"))) {
        while (query.next()) {
            QVariantMap p;
            p["idRol"] = query.value(0);
            p["modulo"] = query.value(1);
            p["accion"] = query.value(2);
            lista.append(p);
        }
    }
    return lista;
}

bool AdministracionUsuarios::permisoBloqueado(int idRol, const QString &modulo,
                                              const QString &accion)
{
    return idRol == idRolPorNombre(QStringLiteral("administrador"))
           && esAccionProtegidaDelAdmin(modulo, accion);
}

bool AdministracionUsuarios::crearUsuario(const QString &nombre, const QString &apellido,
                                          const QString &correo, const QString &contrasena,
                                          int idRol)
{
    if (!autorizar(QStringLiteral("crear"))) {
        return false;
    }

    const QString n = nombre.trimmed();
    const QString a = apellido.trimmed();
    const QString c = correo.trimmed().toLower();

    if (n.isEmpty() || a.isEmpty() || c.isEmpty() || contrasena.isEmpty()) {
        return rechazar(tr("Completa nombre, apellido, correo y contraseña."));
    }
    static const QRegularExpression formatoCorreo(
        QStringLiteral("^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$"));
    if (!formatoCorreo.match(c).hasMatch()) {
        return rechazar(tr("El correo no tiene un formato válido."));
    }
    if (contrasena.size() < kLargoMinimoContrasena) {
        return rechazar(tr("La contraseña debe tener al menos %1 caracteres.")
                            .arg(kLargoMinimoContrasena));
    }

    QSqlQuery rol;
    rol.prepare(QStringLiteral("SELECT 1 FROM Rol WHERE id_rol = :r"));
    rol.bindValue(":r", idRol);
    if (!rol.exec() || !rol.next()) {
        return rechazar(tr("El rol elegido no existe."));
    }

    QSqlQuery existe;
    existe.prepare(QStringLiteral("SELECT 1 FROM Usuario WHERE correo = :c COLLATE NOCASE"));
    existe.bindValue(":c", c);
    if (existe.exec() && existe.next()) {
        return rechazar(tr("Ya existe un usuario con ese correo."));
    }

    QSqlQuery insertar;
    insertar.prepare(QStringLiteral(
        "INSERT INTO Usuario (nombre, apellido, correo, contrasena, id_rol, estado) "
        "VALUES (:n, :a, :c, :h, :r, 'activo')"));
    insertar.bindValue(":n", n);
    insertar.bindValue(":a", a);
    insertar.bindValue(":c", c);
    insertar.bindValue(":h", Sesion::hashContrasena(contrasena));
    insertar.bindValue(":r", idRol);
    if (!insertar.exec()) {
        qWarning() << "crearUsuario():" << insertar.lastError().text();
        return rechazar(tr("No se pudo crear el usuario."));
    }
    emit usuariosCambiaron();
    return true;
}

bool AdministracionUsuarios::cambiarEstado(int idUsuario, const QString &estado)
{
    int idActual = -1;
    if (!autorizar(QStringLiteral("editar"), &idActual)) {
        return false;
    }
    if (estado != QLatin1String("activo") && estado != QLatin1String("inactivo")) {
        return rechazar(tr("Estado no válido."));
    }

    QSqlQuery info;
    info.prepare(QStringLiteral(
        "SELECT r.nombre, u.estado FROM Usuario u JOIN Rol r ON r.id_rol = u.id_rol "
        "WHERE u.id_usuario = :id"));
    info.bindValue(":id", idUsuario);
    if (!info.exec() || !info.next()) {
        return rechazar(tr("El usuario no existe."));
    }
    const bool esAdmin = info.value(0).toString() == QLatin1String("administrador");

    if (estado == QLatin1String("inactivo")) {
        if (idUsuario == idActual) {
            return rechazar(tr("No puedes desactivar tu propia cuenta."));
        }
        if (esAdmin && administradoresActivosSin(idUsuario) < 1) {
            return rechazar(tr("Debe quedar al menos un administrador activo."));
        }
    }

    QSqlQuery upd;
    upd.prepare(QStringLiteral("UPDATE Usuario SET estado = :e WHERE id_usuario = :id"));
    upd.bindValue(":e", estado);
    upd.bindValue(":id", idUsuario);
    if (!upd.exec()) {
        qWarning() << "cambiarEstado():" << upd.lastError().text();
        return rechazar(tr("No se pudo cambiar el estado."));
    }
    // Una cuenta desactivada no debe conservar una sesion guardada.
    if (estado == QLatin1String("inactivo")) {
        QSqlQuery cerrar;
        cerrar.prepare(QStringLiteral(
            "UPDATE Sesion_Actual SET id_usuario = NULL WHERE id = 1 AND id_usuario = :id"));
        cerrar.bindValue(":id", idUsuario);
        cerrar.exec();
    }
    emit usuariosCambiaron();
    return true;
}

bool AdministracionUsuarios::cambiarRol(int idUsuario, int idRol)
{
    int idActual = -1;
    if (!autorizar(QStringLiteral("editar"), &idActual)) {
        return false;
    }
    if (idUsuario == idActual) {
        return rechazar(tr("No puedes cambiar tu propio rol."));
    }

    QSqlQuery rolNuevo;
    rolNuevo.prepare(QStringLiteral("SELECT 1 FROM Rol WHERE id_rol = :r"));
    rolNuevo.bindValue(":r", idRol);
    if (!rolNuevo.exec() || !rolNuevo.next()) {
        return rechazar(tr("El rol elegido no existe."));
    }

    QSqlQuery info;
    info.prepare(QStringLiteral(
        "SELECT r.nombre, u.estado FROM Usuario u JOIN Rol r ON r.id_rol = u.id_rol "
        "WHERE u.id_usuario = :id"));
    info.bindValue(":id", idUsuario);
    if (!info.exec() || !info.next()) {
        return rechazar(tr("El usuario no existe."));
    }
    const bool eraAdmin = info.value(0).toString() == QLatin1String("administrador");
    const bool activo = info.value(1).toString() == QLatin1String("activo");
    if (eraAdmin && activo && idRol != idRolPorNombre(QStringLiteral("administrador"))
        && administradoresActivosSin(idUsuario) < 1) {
        return rechazar(tr("Debe quedar al menos un administrador activo."));
    }

    QSqlQuery upd;
    upd.prepare(QStringLiteral("UPDATE Usuario SET id_rol = :r WHERE id_usuario = :id"));
    upd.bindValue(":r", idRol);
    upd.bindValue(":id", idUsuario);
    if (!upd.exec()) {
        qWarning() << "cambiarRol():" << upd.lastError().text();
        return rechazar(tr("No se pudo cambiar el rol."));
    }
    emit usuariosCambiaron();
    return true;
}

bool AdministracionUsuarios::restablecerContrasena(int idUsuario, const QString &nueva)
{
    if (!autorizar(QStringLiteral("editar"))) {
        return false;
    }
    if (nueva.size() < kLargoMinimoContrasena) {
        return rechazar(tr("La contraseña debe tener al menos %1 caracteres.")
                            .arg(kLargoMinimoContrasena));
    }
    QSqlQuery upd;
    upd.prepare(QStringLiteral("UPDATE Usuario SET contrasena = :h WHERE id_usuario = :id"));
    upd.bindValue(":h", Sesion::hashContrasena(nueva));
    upd.bindValue(":id", idUsuario);
    if (!upd.exec() || upd.numRowsAffected() < 1) {
        return rechazar(tr("No se pudo restablecer la contraseña."));
    }
    return true;
}

bool AdministracionUsuarios::establecerPermiso(int idRol, const QString &modulo,
                                               const QString &accion, bool concedido)
{
    if (!autorizar(QStringLiteral("editar"))) {
        return false;
    }
    if (!permisoValido(modulo, accion)) {
        return rechazar(tr("Ese permiso no existe."));
    }
    QSqlQuery rol;
    rol.prepare(QStringLiteral("SELECT 1 FROM Rol WHERE id_rol = :r"));
    rol.bindValue(":r", idRol);
    if (!rol.exec() || !rol.next()) {
        return rechazar(tr("El rol elegido no existe."));
    }
    if (!concedido && permisoBloqueado(idRol, modulo, accion)) {
        return rechazar(tr("Al administrador no se le pueden quitar los permisos de usuarios "
                           "(se quedaría sin forma de administrar el sistema)."));
    }

    QSqlQuery q;
    if (concedido) {
        q.prepare(QStringLiteral(
            "INSERT OR IGNORE INTO Permisos (modulo, accion_permitida, id_rol) "
            "VALUES (:m, :a, :r)"));
    } else {
        q.prepare(QStringLiteral(
            "DELETE FROM Permisos WHERE modulo = :m AND accion_permitida = :a AND id_rol = :r"));
    }
    q.bindValue(":m", modulo);
    q.bindValue(":a", accion);
    q.bindValue(":r", idRol);
    if (!q.exec()) {
        qWarning() << "establecerPermiso():" << q.lastError().text();
        return rechazar(tr("No se pudo guardar el permiso."));
    }
    emit permisosCambiaron();
    return true;
}
