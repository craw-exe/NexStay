#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QStringList>

#include "Database.h"

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);

    // Theme 9 (instalacion en otro hotel):
    //   --db=<ruta>  usa ese archivo de base de datos, en un disco local
    //                (tambien se puede poner en la variable de entorno NEXSTAY_DB).
    //   --sin-demo   no carga habitaciones, huespedes ni solicitudes de prueba.
    QString rutaBase = qEnvironmentVariable("NEXSTAY_DB");
    bool cargarDemo = true;
    for (const QString &argumento : app.arguments()) {
        if (argumento.startsWith(QStringLiteral("--db="))) {
            rutaBase = argumento.mid(5);
        } else if (argumento == QStringLiteral("--sin-demo")) {
            cargarDemo = false;
        }
    }

    if (!Database::inicializar(rutaBase, cargarDemo)) {
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
    // Dos aplicaciones en un mismo ejecutable:
    //   - Por defecto: la app del PERSONAL (login y vistas por rol).
    //   - Con el argumento --kiosko: la pantalla de la HABITACION que usa
    //     el huesped (Main.qml). En Qt Creator: Projects > Run >
    //     "Command line arguments".
    const bool modoKiosko = app.arguments().contains(QStringLiteral("--kiosko"));
    engine.loadFromModule("NexStay", modoKiosko ? "Main" : "PantallaPrincipal");

    return QGuiApplication::exec();
}
