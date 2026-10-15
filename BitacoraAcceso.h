#ifndef BITACORAACCESO_H
#define BITACORAACCESO_H

#include <QObject>
#include <QString>
#include <QVariantList>
#include <QtQml/qqmlregistration.h>

// Theme 4, Task 4: "Registrar bitacora de accesos".
//
// El REGISTRO en si ya ocurre automaticamente desde el Task 3: cada vez
// que ControlAcceso::intentarAccesoPersonal()/intentarAccesoHuesped() se
// llama, queda una fila en Bitacora_acceso (concedido o intento_fallido,
// segun lo que hayan decidido los triggers del Sprint 2). Esta clase no
// vuelve a escribir ahi: solo LEE esa bitacora para que el personal
// autorizado pueda auditarla desde una pantalla, con el nombre de quien
// entro (o intento entrar) y a que habitacion, ya resuelto via JOIN.
//
// Por ahora es un listado de solo lectura, sin filtros de fecha (Theme 9
// -reportes- es el lugar natural para filtros/exportacion mas finos si
// el equipo decide que hacen falta).
class BitacoraAcceso : public QObject
{
    Q_OBJECT
    QML_ELEMENT

public:
    explicit BitacoraAcceso(QObject *parent = nullptr);

    // La bitacora de accesos es informacion de seguridad: solo el rol
    // "administrador" (el de recepcion, segun lo definido en Theme 4
    // Task 1) puede verla. Se revisa aqui, en C++, en vez de solo
    // esconder el boton en QML, para que no baste con conocer la ruta
    // de la pantalla para saltarse el permiso.
    Q_INVOKABLE bool puedeVerBitacora();

    // Los ultimos "limite" registros de Bitacora_acceso, mas recientes
    // primero. Si idHabitacion es -1 (por defecto) trae de todas las
    // habitaciones; si no, filtra por esa habitacion. Cada elemento
    // trae: idRegistro, fechaHora, numeroHabitacion, actor (nombre de
    // usuario o huesped, ya resuelto), tipoActor ("personal"/"huesped"),
    // rolUsado, tipoEvento ("entrada"/"salida"/"intento_fallido").
    Q_INVOKABLE QVariantList registros(int idHabitacion = -1, int limite = 100);
};

#endif // BITACORAACCESO_H
