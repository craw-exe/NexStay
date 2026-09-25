#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QSqlDatabase>
#include <QSqlQuery>
#include <QSqlError>
#include <QStandardPaths>
#include <QDir>
#include <QDebug>

void inicializarBaseDatos() {
    QSqlDatabase db = QSqlDatabase::addDatabase("QSQLITE");

    // Obtiene una ruta de almacenamiento persistente válida para PC y Android
    QString ruta = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
    QDir().mkpath(ruta);
    db.setDatabaseName("C:/Users/bjaco/Desktop/NexStay/nexstay_hotel.db");

    if (!db.open()) {
        qDebug() << "Error al abrir la BD:" << db.lastError().text();
        return;
    }

    qDebug() << "Base de datos SQLite abierta exitosamente en:" << db.databaseName();

    // Crear tabla de habitaciones de ejemplo
    QSqlQuery query;
    query.exec("CREATE TABLE IF NOT EXISTS habitaciones ("
               "id INTEGER PRIMARY KEY AUTOINCREMENT, "
               "numero TEXT NOT NULL, "
               "tipo TEXT, "
               "precio REAL, "
               "estado TEXT DEFAULT 'Disponible')");
}

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);

    inicializarBaseDatos();

    QQmlApplicationEngine engine;
    QObject::connect(
        &engine,
        &QQmlApplicationEngine::objectCreationFailed,
        &app,
        []() { QCoreApplication::exit(-1); },
        Qt::QueuedConnection);
    engine.loadFromModule("NexStay", "Main");



    return QGuiApplication::exec();
}
