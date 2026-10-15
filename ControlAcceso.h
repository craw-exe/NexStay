#ifndef CONTROLACCESO_H
#define CONTROLACCESO_H

#include <QObject>
#include <QString>
#include <QtQml/qqmlregistration.h>

// Theme 4, Task 3: logica de "acceso" validado por rol.
//
// Esta es la pieza central del Epic "Control de accesos por perfil
// (sin llave fisica)": decidir si alguien puede ENTRAR fisicamente a
// una habitacion, sin usar una llave, sino el permiso de su rol (para
// personal) o su estadia abierta (para huespedes).
//
// El trabajo pesado ya estaba en el esquema del Sprint 2 — esta clase
// solo lo activa y lee el resultado:
//   1. intentarAccesoPersonal()/intentarAccesoHuesped() insertan una
//      fila en Bitacora_acceso con tipo_evento = 'entrada'.
//   2. Los triggers trg_forzar_intento_fallido_usuario /
//      _huesped (ya creados por Database.cpp) revisan AUTOMATICAMENTE,
//      justo despues del INSERT, si quien entro tenia permiso
//      ('entrar' en el modulo 'habitaciones' para personal; una
//      estadia abierta en esa habitacion para huespedes) y, si no,
//      cambian ese mismo registro a 'intento_fallido'.
//   3. Esta clase vuelve a leer la fila recien insertada para saber
//      que decidio el trigger, y se lo reporta a QML con una señal
//      clara (accesoConcedido / accesoDenegado).
//
// Asi, la "regla de negocio" de quien puede entrar vive en un solo
// lugar (los triggers de la BD, documentados en el Sprint 2) y no se
// duplica aqui en C++: esta clase solo dispara el intento y traduce
// el resultado para la interfaz.
//
// tienePermiso() es una utilidad mas general (no solo para "entrar")
// pensada para reusarse en Theme 7 ("control de vistas/funciones por
// rol"): cualquier pantalla podra preguntar, por ejemplo,
// "tienePermiso('reservas', 'crear')" antes de mostrar un boton.
class ControlAcceso : public QObject
{
    Q_OBJECT
    QML_ELEMENT

public:
    explicit ControlAcceso(QObject *parent = nullptr);

    // Revisa si el rol del usuario con sesion activa (Sesion.idUsuario)
    // tiene el permiso dado, consultando Permisos directamente (sin
    // pasar por Bitacora_acceso ni registrar nada). Utilidad general,
    // pensada para que otras pantallas decidan que mostrar segun el
    // rol. Devuelve false si no hay sesion activa.
    Q_INVOKABLE bool tienePermiso(const QString &modulo, const QString &accion);

    // Intenta el acceso fisico de PERSONAL (usuario con sesion activa)
    // a una habitacion: inserta el evento en Bitacora_acceso y
    // devuelve true solo si el trigger de la BD lo dejo como
    // 'entrada' (no 'intento_fallido'). Requiere sesion activa.
    Q_INVOKABLE bool intentarAccesoPersonal(int idHabitacion);

    // Igual que arriba, pero para un HUESPED (sin sesion de personal):
    // el trigger trg_forzar_intento_fallido_huesped valida que tenga
    // una estadia abierta en esa habitacion (Historial_Estadia).
    Q_INVOKABLE bool intentarAccesoHuesped(int idHuesped, int idHabitacion);

signals:
    // tipoActor: "personal" o "huesped", para que la interfaz pueda
    // mostrar un mensaje distinto si hace falta.
    void accesoConcedido(const QString &tipoActor, int idHabitacion);
    void accesoDenegado(const QString &tipoActor, int idHabitacion, const QString &motivo);

private:
    // Inserta la fila en Bitacora_acceso y devuelve su id_registro
    // (o -1 si fallo el INSERT). idUsuario y idHuesped: solo UNO de
    // los dos debe ser >= 0 (mismo CHECK "un_solo_actor" de la BD).
    int registrarIntento(int idUsuario, int idHuesped, int idHabitacion, const QString &rolUsado);

    // Vuelve a leer esa fila para saber si el trigger la cambio a
    // 'intento_fallido'. Devuelve true si quedo como 'entrada'.
    bool accesoFueConcedido(int idRegistro);
};

#endif // CONTROLACCESO_H
