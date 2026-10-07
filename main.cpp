#include <QGuiApplication>
#include <QQmlApplicationEngine>

#include "Database.h"

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);

    if (!Database::inicializar()) {
        // La app puede seguir abriendo (para no dejar al usuario con una
        // pantalla negra), pero sin base de datos la interfaz no podra
        // leer ni guardar el estado de la habitacion.
        qWarning("La aplicacion continuara sin conexion a la base de datos.");
    }

    QQmlApplicationEngine engine;
    QObject::connect(
        &engine,
        &QQmlApplicationEngine::objectCreationFailed,
        &app,
        []() { QCoreApplication::exit(-1); },
        Qt::QueuedConnection);
       engine.loadFromModule("NexStay", "RegistroHuesped");

    return QGuiApplication::exec();
}
