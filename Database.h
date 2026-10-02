#ifndef DATABASE_H
#define DATABASE_H

#include <QSqlDatabase>

// Encargado de abrir la conexión SQLite de NexStay y, la primera vez
// que se ejecuta en una máquina, crear todo el esquema (tablas,
// índices, triggers y datos semilla) a partir del script de la base
// de datos del Sprint 2.
namespace Database
{
    // Abre (o crea) la base de datos en una ruta portable
    // (AppDataLocation, válida tanto en Windows como en Linux/Android),
    // activa el enforcement de llaves foráneas y, si las tablas todavía
    // no existen, ejecuta el esquema completo.
    // Devuelve true si la conexión quedó lista para usarse.
    bool inicializar();

    // Ruta completa del archivo .db que se está usando. Útil para
    // mostrarla en los logs o para depuración.
    QString rutaArchivo();
}

#endif // DATABASE_H
