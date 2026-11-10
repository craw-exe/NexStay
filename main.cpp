#include <QDateTime>
#include <QDir>
#include <QFile>
#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QStandardPaths>
#include <QStringList>
#include <QTextStream>

#include "Database.h"

// Theme 10: los avisos y errores tambien se guardan en nexstay.log (en la
// carpeta de datos de la app). En Release no hay consola, asi que sin
// este archivo no habria forma de saber que fallo en el hotel.
namespace {
    QtMessageHandler s_manejadorAnterior = nullptr;
    QString s_rutaLog;

    void guardarEnLog(QtMsgType tipo, const QMessageLogContext &contexto, const QString &mensaje)
    {
        if (tipo != QtDebugMsg && tipo != QtInfoMsg && !s_rutaLog.isEmpty()) {
            QFile archivo(s_rutaLog);
            // shortcut: al pasar de 1 MB se empieza de nuevo; rotar a
            // varios archivos si hace falta guardar mas historia.
            const QIODevice::OpenMode modo = archivo.size() > 1024 * 1024
                ? QIODevice::WriteOnly | QIODevice::Truncate | QIODevice::Text
                : QIODevice::Append | QIODevice::Text;
            if (archivo.open(modo)) {
                const char *nivel = tipo == QtWarningMsg ? "AVISO" : "ERROR";
                QTextStream(&archivo) << QDateTime::currentDateTime().toString(Qt::ISODate)
                                      << ' ' << nivel << ' ' << mensaje << '\n';
            }
        }
        if (s_manejadorAnterior) {
            s_manejadorAnterior(tipo, contexto, mensaje);
        }
    }
}

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);

    const QString carpetaDatos = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
    QDir().mkpath(carpetaDatos);
    s_rutaLog = carpetaDatos + QStringLiteral("/nexstay.log");
    s_manejadorAnterior = qInstallMessageHandler(guardarEnLog);

    // Theme 9 (instalacion en otro hotel):
    //   --db=<ruta>  usa ese archivo de base de datos, en un disco local
    //                (tambien se puede poner en la variable de entorno NEXSTAY_DB).
    //   --sin-demo   no carga habitaciones, huespedes ni solicitudes de prueba.
    //   --habitacion=<numero>  (Theme 10) habitacion que muestra el modo kiosko.
    QString rutaBase = qEnvironmentVariable("NEXSTAY_DB");
    bool cargarDemo = true;
    for (const QString &argumento : app.arguments()) {
        if (argumento.startsWith(QStringLiteral("--db="))) {
            rutaBase = argumento.mid(5);
        } else if (argumento == QStringLiteral("--sin-demo")) {
            cargarDemo = false;
        } else if (argumento.startsWith(QStringLiteral("--habitacion="))) {
            Database::fijarHabitacionKiosko(argumento.mid(13));
        }
    }

    if (!Database::inicializar(rutaBase, cargarDemo)) {
        // La app puede seguir abriendo (para no dejar al usuario con una
        // pantalla negra), pero sin base de datos la interfaz no podra
        // leer ni guardar el estado de la habitacion.
        qWarning("La aplicacion continuara sin conexion a la base de datos.");
    } else {
        Database::respaldarSiHaceFalta();
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
