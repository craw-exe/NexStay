// Theme 10: pruebas unitarias de NexStay (Qt Test).
// Cada corrida crea una base nueva en una carpeta temporal, sin datos de
// demostracion, asi que no toca la base que se usa en la app.
#include <QDate>
#include <QDir>
#include <QSignalSpy>
#include <QSqlDatabase>
#include <QSqlQuery>
#include <QTemporaryDir>
#include <QtTest>

#include "ControlAcceso.h"
#include "Database.h"
#include "Recepcion.h"
#include "Reserva.h"
#include "Sesion.h"

namespace {
    QString fecha(int diasDesdeHoy)
    {
        return QDate::currentDate().addDays(diasDesdeHoy).toString(QStringLiteral("yyyy-MM-dd"));
    }

    int idHabitacion(const QString &numero)
    {
        QSqlQuery q;
        q.prepare(QStringLiteral("SELECT id_habitacion FROM Habitacion WHERE numero = :n"));
        q.bindValue(":n", numero);
        return q.exec() && q.next() ? q.value(0).toInt() : -1;
    }

    QString valor(const QString &sql)
    {
        QSqlQuery q;
        return q.exec(sql) && q.next() ? q.value(0).toString() : QString();
    }
}

class PruebasNexStay : public QObject
{
    Q_OBJECT

private:
    QTemporaryDir m_carpeta;

private slots:
    void initTestCase()
    {
        QVERIFY(m_carpeta.isValid());
        QVERIFY(Database::inicializar(m_carpeta.filePath(QStringLiteral("prueba.db")), false));
        // Habitaciones extra para las pruebas de reservas.
        QSqlQuery q;
        QVERIFY(q.exec(QStringLiteral(
            "INSERT INTO Habitacion (numero, piso, tipo, estado_actual, capacidad) VALUES "
            "('301', 3, 'doble', 'libre', 2), ('302', 3, 'suite', 'fuera de servicio', 4)")));
    }

    // --- Contrasenas ---
    void pbkdf2ConVectoresConocidos()
    {
        // Vectores publicados de PBKDF2-HMAC-SHA256 (password / salt).
        QCOMPARE(Sesion::pbkdf2Sha256("password", "salt", 1).toHex(),
                 QByteArray("120fb6cffcf8b32c43e7225256c4f837a86548c92ccc35480805987cb70be17b"));
        QCOMPARE(Sesion::pbkdf2Sha256("password", "salt", 4096).toHex(),
                 QByteArray("c5e478d59288c841aa530db6845c4c8d962893a001ce4e11a4963873aa98134a"));
    }

    void hashConSalYVerificacion()
    {
        const QString a = Sesion::hashContrasena(QStringLiteral("secreto123"));
        const QString b = Sesion::hashContrasena(QStringLiteral("secreto123"));
        QVERIFY(a.startsWith(QStringLiteral("pbkdf2$")));
        QVERIFY(a != b); // misma contrasena, distinta sal
        QVERIFY(Sesion::verificarContrasena(QStringLiteral("secreto123"), a));
        QVERIFY(!Sesion::verificarContrasena(QStringLiteral("secreto124"), a));
        QVERIFY(!Sesion::verificarContrasena(QStringLiteral("secreto123"), QStringLiteral("pbkdf2$basura")));
    }

    // --- Inicio de sesion ---
    void hashAntiguoSeMigraAlEntrar()
    {
        // El esquema trae al admin con SHA-256 sin sal (formato viejo).
        QVERIFY(Sesion::esHashAntiguo(valor(QStringLiteral(
            "SELECT contrasena FROM Usuario WHERE correo = 'admin@hotel.com'"))));
        Sesion sesion;
        QVERIFY(sesion.iniciarSesion(QStringLiteral("admin@hotel.com"), QStringLiteral("admin123")));
        QVERIFY(!Sesion::esHashAntiguo(valor(QStringLiteral(
            "SELECT contrasena FROM Usuario WHERE correo = 'admin@hotel.com'"))));
        sesion.cerrarSesion();
        QVERIFY(sesion.iniciarSesion(QStringLiteral("ADMIN@hotel.com "), QStringLiteral("admin123")));
        sesion.cerrarSesion();
    }

    void loginIncorrectoDaMensajeGenerico()
    {
        Sesion sesion;
        QSignalSpy rechazo(&sesion, &Sesion::sesionRechazada);
        QVERIFY(!sesion.iniciarSesion(QStringLiteral("admin@hotel.com"), QStringLiteral("incorrecta")));
        QVERIFY(!sesion.iniciarSesion(QStringLiteral("noexiste@hotel.com"), QStringLiteral("admin123")));
        QCOMPARE(rechazo.count(), 2);
        QCOMPARE(rechazo.at(0).at(0).toString(), rechazo.at(1).at(0).toString());
        QVERIFY(!sesion.haySesion());
    }

    void bloqueoTrasCincoIntentos()
    {
        Sesion sesion;
        QSignalSpy rechazo(&sesion, &Sesion::sesionRechazada);
        for (int i = 0; i < Sesion::kMaxIntentos; ++i) {
            QVERIFY(!sesion.iniciarSesion(QStringLiteral("ana@hotel.com"), QStringLiteral("mala")));
        }
        // Aun con la contrasena correcta, queda bloqueado.
        QVERIFY(!sesion.iniciarSesion(QStringLiteral("ana@hotel.com"), QStringLiteral("limpieza123")));
        QVERIFY(rechazo.last().at(0).toString().contains(QStringLiteral("Demasiados")));
        // Otro correo no se ve afectado.
        QVERIFY(sesion.iniciarSesion(QStringLiteral("admin@hotel.com"), QStringLiteral("admin123")));
        sesion.cerrarSesion();
    }

    void usuarioInactivoNoEntra()
    {
        QSqlQuery q;
        q.prepare(QStringLiteral(
            "INSERT INTO Usuario (nombre, apellido, correo, contrasena, id_rol, estado) "
            "SELECT 'Ina', 'Activa', 'inactiva@hotel.com', :h, id_rol, 'inactivo' "
            "FROM Rol WHERE nombre = 'limpieza'"));
        q.bindValue(":h", Sesion::hashContrasena(QStringLiteral("hotel1234")));
        QVERIFY(q.exec());
        Sesion sesion;
        QVERIFY(!sesion.iniciarSesion(QStringLiteral("inactiva@hotel.com"), QStringLiteral("hotel1234")));
    }

    // --- Permisos ---
    void limpiezaNoPuedeReservarNiRegistrar()
    {
        Sesion sesion;
        // ana@hotel.com quedo bloqueada en otra prueba; se usa un usuario nuevo de limpieza.
        QSqlQuery q;
        q.prepare(QStringLiteral(
            "INSERT INTO Usuario (nombre, apellido, correo, contrasena, id_rol, estado) "
            "SELECT 'Lupe', 'Limpia', 'lupe@hotel.com', :h, id_rol, 'activo' "
            "FROM Rol WHERE nombre = 'limpieza'"));
        q.bindValue(":h", Sesion::hashContrasena(QStringLiteral("hotel1234")));
        QVERIFY(q.exec());
        QVERIFY(sesion.iniciarSesion(QStringLiteral("lupe@hotel.com"), QStringLiteral("hotel1234")));

        QVERIFY(!ControlAcceso::sesionTienePermiso(QStringLiteral("reservas"), QStringLiteral("crear")));
        Reserva reserva;
        QVERIFY(!reserva.crearReserva(1, idHabitacion(QStringLiteral("301")), fecha(1), fecha(2)));
        Recepcion recepcion;
        QCOMPARE(recepcion.registrarHuesped(QStringLiteral("A"), QStringLiteral("B"),
                                            QStringLiteral("DOC-X"), QStringLiteral("8710000000"),
                                            QStringLiteral("a@b.com")), -1);
        sesion.cerrarSesion();
        QVERIFY(!ControlAcceso::sesionTienePermiso(QStringLiteral("reservas"), QStringLiteral("ver")));
    }

    // --- Flujo de recepcion ---
    void flujoCompletoDeRecepcion()
    {
        Sesion sesion;
        QVERIFY(sesion.iniciarSesion(QStringLiteral("admin@hotel.com"), QStringLiteral("admin123")));
        Recepcion recepcion;
        Reserva reserva;

        const int idHuesped = recepcion.registrarHuesped(
            QStringLiteral("Laura"), QStringLiteral("Prueba"), QStringLiteral("lapr900101"),
            QStringLiteral("871-555-0000"), QStringLiteral("laura@correo.com"));
        QVERIFY(idHuesped > 0);
        // Documento repetido (aunque cambie mayusculas) y correo invalido.
        QCOMPARE(recepcion.registrarHuesped(QStringLiteral("Otra"), QStringLiteral("Persona"),
                                            QStringLiteral("LAPR900101"), QStringLiteral("8710000000"),
                                            QStringLiteral("otra@correo.com")), -1);
        QCOMPARE(recepcion.registrarHuesped(QStringLiteral("Otra"), QStringLiteral("Persona"),
                                            QStringLiteral("OTRA-1"), QStringLiteral("8710000000"),
                                            QStringLiteral("sin-arroba")), -1);
        QVERIFY(!recepcion.buscarHuespedes(QStringLiteral("laura pru")).isEmpty());

        const int h301 = idHabitacion(QStringLiteral("301"));
        QVERIFY(!reserva.crearReserva(idHuesped, h301, fecha(2), fecha(2)));   // salida = entrada
        QVERIFY(!reserva.crearReserva(idHuesped, h301, fecha(-1), fecha(1)));  // en el pasado
        QVERIFY(!reserva.crearReserva(idHuesped, idHabitacion(QStringLiteral("302")), fecha(0), fecha(1))); // fuera de servicio
        QVERIFY(!reserva.crearReserva(9999, h301, fecha(0), fecha(1)));        // huesped inexistente

        QSignalSpy creada(&reserva, &Reserva::reservaCreada);
        QVERIFY(reserva.crearReserva(idHuesped, h301, fecha(0), fecha(2)));
        const int idReserva = creada.at(0).at(0).toInt();
        QCOMPARE(valor(QStringLiteral("SELECT estado_actual FROM Habitacion WHERE numero = '301'")),
                 QStringLiteral("reservada"));
        QVERIFY(!reserva.crearReserva(idHuesped, h301, fecha(1), fecha(3)));   // se traslapa

        QVariantMap d = recepcion.detalleReserva(idReserva);
        QVERIFY(d.value(QStringLiteral("puedeCheckIn")).toBool());
        QVERIFY(!d.value(QStringLiteral("puedeCheckOut")).toBool());

        QVERIFY(recepcion.checkIn(idReserva));
        QVERIFY(!recepcion.checkIn(idReserva)); // no dos veces
        QCOMPARE(valor(QStringLiteral("SELECT estado_actual FROM Habitacion WHERE numero = '301'")),
                 QStringLiteral("ocupada"));
        QVERIFY(!recepcion.cancelarReserva(idReserva)); // ya esta hospedado

        QVERIFY(recepcion.checkOut(idReserva));
        QCOMPARE(valor(QStringLiteral("SELECT estado_reserva FROM Reserva WHERE id_reserva = %1").arg(idReserva)),
                 QStringLiteral("finalizada"));
        QCOMPARE(valor(QStringLiteral("SELECT estado_actual FROM Habitacion WHERE numero = '301'")),
                 QStringLiteral("en limpieza"));
        QCOMPARE(valor(QStringLiteral(
                     "SELECT COUNT(*) FROM Solicitud_Servicio s JOIN Habitacion h USING (id_habitacion) "
                     "WHERE h.numero = '301' AND s.tipo = 'limpieza' AND s.estado = 'pendiente'")),
                 QStringLiteral("1"));

        // Una reserva futura se puede cancelar.
        creada.clear();
        QVERIFY(reserva.crearReserva(idHuesped, h301, fecha(5), fecha(7)));
        const int idFutura = creada.at(0).at(0).toInt();
        QVERIFY(!recepcion.detalleReserva(idFutura).value(QStringLiteral("puedeCheckIn")).toBool());
        QVERIFY(recepcion.cancelarReserva(idFutura));
        QCOMPARE(valor(QStringLiteral("SELECT estado_reserva FROM Reserva WHERE id_reserva = %1").arg(idFutura)),
                 QStringLiteral("cancelada"));
        sesion.cerrarSesion();
    }

    void habitacionDelKiosko()
    {
        Database::fijarHabitacionKiosko(QStringLiteral("301"));
        QCOMPARE(Database::idHabitacionKiosko(), idHabitacion(QStringLiteral("301")));
        Database::fijarHabitacionKiosko(QStringLiteral("999")); // no existe: la primera
        QCOMPARE(Database::idHabitacionKiosko(), idHabitacion(QStringLiteral("204")));
        Database::fijarHabitacionKiosko(QString());
    }

    void cleanupTestCase()
    {
        // Se cierra la base para que QTemporaryDir pueda borrar la carpeta.
        const QString nombre = QSqlDatabase::database().connectionName();
        QSqlDatabase::database().close();
        QSqlDatabase::removeDatabase(nombre);
    }

    void respaldoDiario()
    {
        QVERIFY(Database::respaldarSiHaceFalta());
        QDir respaldos(m_carpeta.filePath(QStringLiteral("respaldos")));
        QCOMPARE(respaldos.entryList({QStringLiteral("prueba_*.db")}, QDir::Files).size(), 1);
        QVERIFY(Database::respaldarSiHaceFalta()); // el segundo del dia no duplica
        QCOMPARE(respaldos.entryList({QStringLiteral("prueba_*.db")}, QDir::Files).size(), 1);
    }
};

QTEST_GUILESS_MAIN(PruebasNexStay)
#include "tst_nexstay.moc"
