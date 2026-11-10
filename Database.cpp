#include "Database.h"

#include <QDate>
#include <QDebug>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QRegularExpression>
#include <QSqlError>
#include <QSqlQuery>
#include <QStandardPaths>
#include <QStringList>

namespace
{
    QString s_rutaArchivo;
    QString s_numeroKiosko;

    // Esquema completo del Sprint 2 (archivo "BASE DE DATOS 2.txt").
    // Se ejecuta una sola vez, la primera vez que la app corre en una
    // máquina (cuando la tabla Habitacion todavía no existe).
    const char *const kEsquemaSQL = R"SQL(
PRAGMA foreign_keys = ON;

CREATE TABLE "Rol" (
    "id_rol"          INTEGER NOT NULL,
    "nombre"          TEXT NOT NULL UNIQUE,
    "rol_descripcion" TEXT NOT NULL,
    PRIMARY KEY("id_rol" AUTOINCREMENT)
);

CREATE TABLE "Usuario" (
    "id_usuario"     INTEGER NOT NULL,
    "nombre"         TEXT NOT NULL,
    "apellido"       TEXT NOT NULL,
    "correo"         TEXT NOT NULL UNIQUE,
    "contrasena"     TEXT NOT NULL,
    "id_rol"         INTEGER NOT NULL,
    "estado"         TEXT NOT NULL DEFAULT 'activo',
    "fecha_creacion" TEXT NOT NULL DEFAULT (datetime('now','localtime')),
    PRIMARY KEY("id_usuario" AUTOINCREMENT),
    CONSTRAINT "usuario_rol" FOREIGN KEY("id_rol") REFERENCES "Rol"("id_rol"),
    CONSTRAINT "usuario_estado" CHECK("estado" IN ('activo','inactivo'))
);

CREATE TABLE "Permisos" (
    "id_permisos"      INTEGER NOT NULL,
    "modulo"           TEXT NOT NULL,
    "accion_permitida" TEXT NOT NULL,
    "id_rol"           INTEGER NOT NULL,
    PRIMARY KEY("id_permisos" AUTOINCREMENT),
    CONSTRAINT "permisos_rol" FOREIGN KEY("id_rol") REFERENCES "Rol"("id_rol"),
    CONSTRAINT "acciones" CHECK("accion_permitida" IN ('ver','editar','crear','eliminar','entrar')),
    CONSTRAINT "permiso_unico" UNIQUE("modulo","accion_permitida","id_rol")
);

CREATE TABLE "Habitacion" (
    "id_habitacion" INTEGER NOT NULL,
    "numero"        TEXT NOT NULL UNIQUE,
    "piso"          INTEGER NOT NULL,
    "tipo"          TEXT NOT NULL,
    "estado_actual" TEXT NOT NULL DEFAULT 'libre',
    "capacidad"     INTEGER NOT NULL,
    PRIMARY KEY("id_habitacion" AUTOINCREMENT),
    CONSTRAINT "tipos_habitacion" CHECK("tipo" IN ('individual','doble','suite')),
    CONSTRAINT "habitacion_estado" CHECK("estado_actual" IN ('ocupada','libre','en limpieza','reservada','fuera de servicio')),
    CONSTRAINT "capacidad_positiva" CHECK("capacidad" > 0)
);

CREATE TABLE "Historial_Estado" (
    "id_historial"          INTEGER NOT NULL,
    "id_habitacion"         INTEGER NOT NULL,
    "estado"                TEXT NOT NULL,
    "fecha_hora_cambio"     TEXT NOT NULL DEFAULT (datetime('now','localtime')),
    "id_usuario_que_cambio" INTEGER,
    PRIMARY KEY("id_historial" AUTOINCREMENT),
    CONSTRAINT "historial_habitacion" FOREIGN KEY("id_habitacion") REFERENCES "Habitacion"("id_habitacion"),
    CONSTRAINT "historial_usuario" FOREIGN KEY("id_usuario_que_cambio") REFERENCES "Usuario"("id_usuario"),
    CONSTRAINT "historial_estado_valido" CHECK("estado" IN ('ocupada','libre','en limpieza','reservada','fuera de servicio'))
);

CREATE TABLE "Huesped" (
    "id_huesped"          INTEGER NOT NULL,
    "nombre"              TEXT NOT NULL,
    "apellido"            TEXT NOT NULL,
    "documento_identidad" TEXT NOT NULL UNIQUE,
    "telefono"            TEXT NOT NULL,
    "correo"              TEXT NOT NULL,
    PRIMARY KEY("id_huesped" AUTOINCREMENT)
);

CREATE TABLE "Reserva" (
    "id_reserva"     INTEGER NOT NULL,
    "id_huesped"     INTEGER NOT NULL,
    "id_habitacion"  INTEGER NOT NULL,
    "fecha_entrada"  TEXT NOT NULL,
    "fecha_salida"   TEXT NOT NULL,
    "estado_reserva" TEXT NOT NULL DEFAULT 'confirmada',
    "fecha_registro" TEXT NOT NULL DEFAULT (datetime('now','localtime')),
    PRIMARY KEY("id_reserva" AUTOINCREMENT),
    CONSTRAINT "reserva_habitacion" FOREIGN KEY("id_habitacion") REFERENCES "Habitacion"("id_habitacion"),
    CONSTRAINT "reserva_huesped" FOREIGN KEY("id_huesped") REFERENCES "Huesped"("id_huesped"),
    CONSTRAINT "estado_reserva" CHECK("estado_reserva" IN ('confirmada','cancelada','finalizada')),
    CONSTRAINT "fechas_validas" CHECK("fecha_salida" > "fecha_entrada")
);

CREATE TABLE "Historial_Estadia" (
    "id_estadia"          INTEGER NOT NULL,
    "id_reserva"          INTEGER,
    "id_huesped"          INTEGER NOT NULL,
    "id_habitacion"       INTEGER NOT NULL,
    "fecha_entrada_real"  TEXT NOT NULL,
    "fecha_salida_real"   TEXT,
    PRIMARY KEY("id_estadia" AUTOINCREMENT),
    CONSTRAINT "estadia_reserva" FOREIGN KEY("id_reserva") REFERENCES "Reserva"("id_reserva"),
    CONSTRAINT "estadia_habitacion" FOREIGN KEY("id_habitacion") REFERENCES "Habitacion"("id_habitacion"),
    CONSTRAINT "estadia_huesped" FOREIGN KEY("id_huesped") REFERENCES "Huesped"("id_huesped")
);

CREATE TABLE "Bitacora_acceso" (
    "id_registro"   INTEGER NOT NULL,
    "id_usuario"    INTEGER,
    "id_huesped"    INTEGER,
    "id_habitacion" INTEGER NOT NULL,
    "rol_usado"     TEXT NOT NULL,
    "fecha_hora"    TEXT NOT NULL DEFAULT (datetime('now','localtime')),
    "tipo_evento"   TEXT NOT NULL,
    PRIMARY KEY("id_registro" AUTOINCREMENT),
    CONSTRAINT "acceso_habitacion" FOREIGN KEY("id_habitacion") REFERENCES "Habitacion"("id_habitacion"),
    CONSTRAINT "acceso_usuario" FOREIGN KEY("id_usuario") REFERENCES "Usuario"("id_usuario"),
    CONSTRAINT "acceso_huesped" FOREIGN KEY("id_huesped") REFERENCES "Huesped"("id_huesped"),
    CONSTRAINT "tipo_evento" CHECK("tipo_evento" IN ('entrada','salida','intento_fallido')),
    CONSTRAINT "un_solo_actor" CHECK(("id_usuario" IS NOT NULL AND "id_huesped" IS NULL)
                                  OR ("id_usuario" IS NULL AND "id_huesped" IS NOT NULL))
);

CREATE TABLE "Estado_Presencia" (
    "id_habitacion"            INTEGER NOT NULL,
    "estado"                   TEXT NOT NULL,
    "fecha_hora_actualizacion" TEXT NOT NULL DEFAULT (datetime('now','localtime')),
    PRIMARY KEY("id_habitacion"),
    CONSTRAINT "presencia_habitacion" FOREIGN KEY("id_habitacion") REFERENCES "Habitacion"("id_habitacion"),
    CONSTRAINT "presencia_estado" CHECK("estado" IN ('dentro','fuera'))
);

CREATE TABLE "Solicitud_Servicio" (
    "id_solicitud"            INTEGER NOT NULL,
    "id_habitacion"           INTEGER NOT NULL,
    "id_huesped"              INTEGER,
    "origen"                  TEXT NOT NULL,
    "tipo"                    TEXT NOT NULL,
    "descripcion"             TEXT,
    "prioridad"               TEXT NOT NULL DEFAULT 'media',
    "id_responsable_asignado" INTEGER,
    "estado"                  TEXT NOT NULL DEFAULT 'pendiente',
    "fecha_creacion"          TEXT NOT NULL DEFAULT (datetime('now','localtime')),
    "fecha_atencion"          TEXT,
    "fecha_resolucion"        TEXT,
    PRIMARY KEY("id_solicitud" AUTOINCREMENT),
    CONSTRAINT "servicio_habitacion" FOREIGN KEY("id_habitacion") REFERENCES "Habitacion"("id_habitacion"),
    CONSTRAINT "servicio_huesped" FOREIGN KEY("id_huesped") REFERENCES "Huesped"("id_huesped"),
    CONSTRAINT "usuario_servicio" FOREIGN KEY("id_responsable_asignado") REFERENCES "Usuario"("id_usuario"),
    CONSTRAINT "origen" CHECK("origen" IN ('huesped','personal','automatico')),
    CONSTRAINT "tipo" CHECK("tipo" IN ('limpieza','mantenimiento')),
    CONSTRAINT "prioridad" CHECK("prioridad" IN ('alta','media','baja')),
    CONSTRAINT "estado" CHECK("estado" IN ('pendiente','en_proceso','resuelta')),
    CONSTRAINT "huesped_si_origen_huesped" CHECK("origen" <> 'huesped' OR "id_huesped" IS NOT NULL)
);

CREATE TABLE "Sesion_Actual" (
    "id"         INTEGER PRIMARY KEY CHECK("id" = 1),
    "id_usuario" INTEGER,
    FOREIGN KEY("id_usuario") REFERENCES "Usuario"("id_usuario")
);
INSERT INTO Sesion_Actual (id, id_usuario) VALUES (1, NULL);

CREATE INDEX idx_reserva_hab_fechas ON Reserva(id_habitacion, fecha_entrada, fecha_salida);
CREATE INDEX idx_historial_estado_hab ON Historial_Estado(id_habitacion);
CREATE INDEX idx_bitacora_hab ON Bitacora_acceso(id_habitacion, fecha_hora);
CREATE INDEX idx_servicio_estado ON Solicitud_Servicio(estado, prioridad);

CREATE TRIGGER "trg_actualizar_historial"
AFTER UPDATE OF "estado_actual" ON "Habitacion"
FOR EACH ROW
WHEN OLD."estado_actual" IS NOT NEW."estado_actual"
BEGIN
    INSERT INTO "Historial_Estado" (id_habitacion, estado, fecha_hora_cambio, id_usuario_que_cambio)
    VALUES (
        NEW.id_habitacion,
        NEW.estado_actual,
        datetime('now','localtime'),
        (SELECT id_usuario FROM Sesion_Actual WHERE id = 1)
    );
END;

CREATE TRIGGER "trg_validar_traslape_insert"
BEFORE INSERT ON "Reserva"
FOR EACH ROW
WHEN NEW.estado_reserva = 'confirmada'
BEGIN
    SELECT RAISE(ABORT, 'Traslape: la habitacion ya tiene una reserva activa en esas fechas')
    WHERE EXISTS (
        SELECT 1 FROM Reserva
        WHERE id_habitacion = NEW.id_habitacion
          AND estado_reserva = 'confirmada'
          AND NEW.fecha_entrada < fecha_salida
          AND NEW.fecha_salida > fecha_entrada
    );
END;

CREATE TRIGGER "trg_validar_traslape_update"
BEFORE UPDATE ON "Reserva"
FOR EACH ROW
WHEN NEW.estado_reserva = 'confirmada'
BEGIN
    SELECT RAISE(ABORT, 'Traslape: la habitacion ya tiene una reserva activa en esas fechas')
    WHERE EXISTS (
        SELECT 1 FROM Reserva
        WHERE id_habitacion = NEW.id_habitacion
          AND estado_reserva = 'confirmada'
          AND id_reserva != NEW.id_reserva
          AND NEW.fecha_entrada < fecha_salida
          AND NEW.fecha_salida > fecha_entrada
    );
END;

CREATE TRIGGER "trg_forzar_intento_fallido_usuario"
AFTER INSERT ON "Bitacora_acceso"
FOR EACH ROW
WHEN NEW.tipo_evento = 'entrada'
     AND NEW.id_usuario IS NOT NULL
     AND NOT EXISTS (
        SELECT 1
        FROM Usuario u
        JOIN Permisos p ON u.id_rol = p.id_rol
        WHERE u.id_usuario = NEW.id_usuario
          AND u.estado = 'activo'
          AND p.modulo = 'habitaciones'
          AND p.accion_permitida = 'entrar'
     )
BEGIN
    UPDATE Bitacora_acceso
    SET tipo_evento = 'intento_fallido'
    WHERE id_registro = NEW.id_registro;
END;

CREATE TRIGGER "trg_forzar_intento_fallido_huesped"
AFTER INSERT ON "Bitacora_acceso"
FOR EACH ROW
WHEN NEW.tipo_evento = 'entrada'
     AND NEW.id_huesped IS NOT NULL
     AND NOT EXISTS (
        SELECT 1
        FROM Historial_Estadia e
        WHERE e.id_huesped = NEW.id_huesped
          AND e.id_habitacion = NEW.id_habitacion
          AND e.fecha_salida_real IS NULL
     )
BEGIN
    UPDATE Bitacora_acceso
    SET tipo_evento = 'intento_fallido'
    WHERE id_registro = NEW.id_registro;
END;

INSERT INTO Rol (nombre, rol_descripcion) VALUES
('administrador', 'Acceso total al sistema'),
('recepcion',     'Gestiona reservas, huespedes y estado de habitaciones'),
('limpieza',      'Atiende solicitudes de limpieza y accede a habitaciones'),
('mantenimiento', 'Atiende solicitudes de mantenimiento y accede a habitaciones');

INSERT INTO Permisos (modulo, accion_permitida, id_rol)
SELECT m.modulo, a.accion, r.id_rol
FROM Rol r
CROSS JOIN (SELECT 'habitaciones' AS modulo UNION ALL SELECT 'reservas'
            UNION ALL SELECT 'huespedes' UNION ALL SELECT 'usuarios'
            UNION ALL SELECT 'solicitudes') m
CROSS JOIN (SELECT 'ver' AS accion UNION ALL SELECT 'crear'
            UNION ALL SELECT 'editar' UNION ALL SELECT 'eliminar'
            UNION ALL SELECT 'entrar') a
WHERE r.nombre = 'administrador';

INSERT INTO Permisos (modulo, accion_permitida, id_rol)
SELECT p.modulo, p.accion, r.id_rol
FROM Rol r
CROSS JOIN (SELECT 'habitaciones' AS modulo, 'ver' AS accion
            UNION ALL SELECT 'habitaciones', 'editar'
            UNION ALL SELECT 'reservas', 'ver'
            UNION ALL SELECT 'reservas', 'crear'
            UNION ALL SELECT 'reservas', 'editar'
            UNION ALL SELECT 'huespedes', 'ver'
            UNION ALL SELECT 'huespedes', 'crear'
            UNION ALL SELECT 'huespedes', 'editar'
            UNION ALL SELECT 'solicitudes', 'ver'
            UNION ALL SELECT 'solicitudes', 'crear') p
WHERE r.nombre = 'recepcion';

INSERT INTO Permisos (modulo, accion_permitida, id_rol)
SELECT p.modulo, p.accion, r.id_rol
FROM Rol r
CROSS JOIN (SELECT 'habitaciones' AS modulo, 'ver' AS accion
            UNION ALL SELECT 'habitaciones', 'entrar'
            UNION ALL SELECT 'solicitudes', 'ver'
            UNION ALL SELECT 'solicitudes', 'editar') p
WHERE r.nombre = 'limpieza';

INSERT INTO Permisos (modulo, accion_permitida, id_rol)
SELECT p.modulo, p.accion, r.id_rol
FROM Rol r
CROSS JOIN (SELECT 'habitaciones' AS modulo, 'ver' AS accion
            UNION ALL SELECT 'habitaciones', 'entrar'
            UNION ALL SELECT 'solicitudes', 'ver'
            UNION ALL SELECT 'solicitudes', 'editar') p
WHERE r.nombre = 'mantenimiento';

-- Usuarios de ejemplo. La contrasena se guarda como SHA-256 (nunca en
-- texto plano); los hashes de abajo corresponden a estas contrasenas
-- de PRUEBA (solo para desarrollo, no usar en un hotel real):
--   admin@hotel.com  -> admin123
--   ana@hotel.com     -> limpieza123
INSERT INTO Usuario (nombre, apellido, correo, contrasena, id_rol, estado) VALUES
('Admin', 'Sistema', 'admin@hotel.com',
    '240be518fabd2724ddb6f04eeb1da5967448d7e831c08c8fa822809f74c720a9',
    (SELECT id_rol FROM Rol WHERE nombre = 'administrador'), 'activo'),
('Ana',   'Lopez',   'ana@hotel.com',
    'b86470658679da7944ebcc2ade103747d547e6cb60ae276a549d9f18fe0676b8',
    (SELECT id_rol FROM Rol WHERE nombre = 'limpieza'), 'activo');

-- Habitacion de demostracion para que el kiosco (Theme 2) tenga datos
-- reales con los que trabajar mientras no existe todavia el modulo
-- de reservas (Theme 3) ni el de administracion de habitaciones.
INSERT INTO Habitacion (numero, piso, tipo, estado_actual, capacidad) VALUES
('204', 2, 'doble', 'ocupada', 2);
)SQL";

    // Separa un script de varias sentencias SQL en statements individuales.
    // No se puede usar un simple split(";") porque los triggers contienen
    // ";" dentro de su cuerpo BEGIN...END; aqui se lleva la cuenta de
    // cuantos BEGIN siguen "abiertos" y solo se corta en el ";" que
    // cierra la sentencia completa (profundidad 0).
    QStringList dividirSentencias(const QString &script)
    {
        // Quita comentarios de linea completa (--) antes de procesar.
        QString limpio;
        const QStringList lineas = script.split('\n');
        for (const QString &lineaOriginal : lineas) {
            QString linea = lineaOriginal;
            const int idx = linea.indexOf(QStringLiteral("--"));
            if (idx >= 0) {
                linea = linea.left(idx);
            }
            limpio += linea;
            limpio += '\n';
        }

        QStringList sentencias;
        QString actual;
        int profundidadBeginEnd = 0;

        static const QRegularExpression palabra(QStringLiteral("[A-Za-z_][A-Za-z0-9_]*"));

        int i = 0;
        const int n = limpio.size();
        while (i < n) {
            QChar c = limpio.at(i);

            if (c.isLetter() || c == '_') {
                QRegularExpressionMatch m = palabra.match(limpio, i,
                    QRegularExpression::NormalMatch, QRegularExpression::AnchoredMatchOption);
                QString w;
                if (m.hasMatch()) {
                    w = m.captured(0);
                }
                if (!w.isEmpty()) {
                    const QString wUpper = w.toUpper();
                    if (wUpper == QLatin1String("BEGIN")) {
                        profundidadBeginEnd++;
                    } else if (wUpper == QLatin1String("END")) {
                        if (profundidadBeginEnd > 0) {
                            profundidadBeginEnd--;
                        }
                    }
                    actual += w;
                    i += w.size();
                    continue;
                }
            }

            if (c == ';' && profundidadBeginEnd == 0) {
                const QString trimmed = actual.trimmed();
                if (!trimmed.isEmpty()) {
                    sentencias << trimmed;
                }
                actual.clear();
            } else {
                actual += c;
            }
            i++;
        }

        const QString ultimo = actual.trimmed();
        if (!ultimo.isEmpty()) {
            sentencias << ultimo;
        }

        return sentencias;
    }

    // SOLO DESARROLLO: deja listo un huesped de demostracion con una
    // estadia abierta en la primera habitacion, y su presencia en
    // "dentro". Sin una estadia abierta, Solicitud_Servicio no puede
    // crearse desde la pantalla del huesped (exige id_huesped) y no habria
    // forma de probar el Theme 5 mientras el registro de huespedes
    // (Theme 3, Task 1) siga siendo solo interfaz. Es idempotente: se
    // ejecuta en cada arranque, pero no duplica nada si ya existe.
    // Quitar cuando exista el flujo real de check-in.
    void sembrarHuespedDemo(QSqlDatabase &db)
    {
        const QStringList sentencias = {
            QStringLiteral(
                "INSERT OR IGNORE INTO Huesped (nombre, apellido, documento_identidad, telefono, correo) "
                "VALUES ('Huesped', 'Demo', 'DEMO-0001', '0000000000', 'demo@nexstay.test')"),
            QStringLiteral(
                "INSERT INTO Historial_Estadia (id_reserva, id_huesped, id_habitacion, fecha_entrada_real) "
                "SELECT NULL, hu.id_huesped, h.id_habitacion, datetime('now','localtime') "
                "FROM Huesped hu, Habitacion h "
                "WHERE hu.documento_identidad = 'DEMO-0001' "
                "  AND h.id_habitacion = (SELECT MIN(id_habitacion) FROM Habitacion) "
                "  AND NOT EXISTS (SELECT 1 FROM Historial_Estadia e "
                "                  WHERE e.id_habitacion = h.id_habitacion AND e.fecha_salida_real IS NULL)"),
            QStringLiteral(
                "INSERT OR IGNORE INTO Estado_Presencia (id_habitacion, estado) "
                "SELECT id_habitacion, 'dentro' FROM Habitacion "
                "WHERE id_habitacion = (SELECT MIN(id_habitacion) FROM Habitacion)")
        };
        for (const QString &sql : sentencias) {
            QSqlQuery q(db);
            if (!q.exec(sql)) {
                qWarning() << "No se pudo sembrar el huesped de demostracion:" << q.lastError().text();
            }
        }
    }

    // Datos de demostracion: se leen del archivo datos_demo.sql (va
    // dentro del ejecutable como recurso). Ese archivo parte del script
    // "Tablas llenas" del equipo, adaptado al esquema actual, y agrega
    // datos de volumen: 40 habitaciones, 22 usuarios, 68 huespedes,
    // ~600 reservas de los ultimos 90 dias y ~600 solicitudes, para que
    // el calendario, las solicitudes y los reportes (Theme 8) tengan
    // que mostrar. Todas sus fechas son relativas a "hoy".
    //
    // Solo se carga una vez (si todavia no existe la huesped Sofia
    // Navarro) y nunca con --sin-demo (instalacion real, Theme 9).
    void sembrarDatosDemo(QSqlDatabase &db)
    {
        QSqlQuery yaExiste(db);
        yaExiste.exec(QStringLiteral(
            "SELECT 1 FROM Huesped WHERE documento_identidad = 'NASO900315MCLVRF01'"));
        if (yaExiste.next()) {
            return;
        }

        QFile archivo(QStringLiteral(":/qt/qml/NexStay/datos_demo.sql"));
        if (!archivo.open(QIODevice::ReadOnly | QIODevice::Text)) {
            qWarning() << "No se encontro datos_demo.sql en los recursos";
            return;
        }
        const QStringList sentencias = dividirSentencias(QString::fromUtf8(archivo.readAll()));

        // El trigger de Historial_Estado toma el usuario de Sesion_Actual
        // y el script la cambia; se guarda la que hubiera para regresarla
        // al final y no dejar a nadie con la sesion iniciada.
        QSqlQuery sesion(db);
        sesion.exec(QStringLiteral("SELECT id_usuario FROM Sesion_Actual WHERE id = 1"));
        const QVariant sesionAnterior = sesion.next() ? sesion.value(0) : QVariant();

        db.transaction();
        bool ok = true;
        for (const QString &sql : sentencias) {
            QSqlQuery q(db);
            if (!q.exec(sql)) {
                qWarning() << "Datos demo:" << q.lastError().text() << "\n" << sql.left(300);
                ok = false;
                break;
            }
        }

        QSqlQuery regresar(db);
        regresar.prepare(QStringLiteral("UPDATE Sesion_Actual SET id_usuario = :id WHERE id = 1"));
        regresar.bindValue(QStringLiteral(":id"), sesionAnterior);
        regresar.exec();

        if (ok) {
            db.commit();
            qDebug() << "Datos de demostracion cargados:" << sentencias.size() << "sentencias.";
        } else {
            db.rollback(); // todo o nada: si algo falla no se deja la demo a medias
            qWarning() << "No se cargaron los datos de demostracion.";
        }
    }

    // Theme 7 (Tasks 1 y 2): deja la tabla Permisos igual que la matriz
    // definitiva de roles y permisos. Corre en cada arranque y es
    // idempotente: INSERT OR IGNORE no duplica nada (la tabla tiene
    // UNIQUE modulo+accion+rol), asi que tambien actualiza las bases de
    // datos que se crearon antes de que existiera esta matriz, sin tener
    // que borrarlas.
    void aplicarPermisosBase(QSqlDatabase &db)
    {
        struct Permiso { const char *rol; const char *modulo; const char *accion; };
        static const Permiso nuevos[] = {
            { "recepcion",     "habitaciones", "entrar" },
            { "limpieza",      "habitaciones", "editar" },
            { "mantenimiento", "habitaciones", "editar" },
            { "administrador", "bitacora",     "ver"    },
            { "administrador", "reportes",     "ver"    },
        };

        for (const Permiso &p : nuevos) {
            QSqlQuery q(db);
            q.prepare(QStringLiteral(
                "INSERT OR IGNORE INTO Permisos (modulo, accion_permitida, id_rol) "
                "SELECT :modulo, :accion, id_rol FROM Rol WHERE nombre = :rol"));
            q.bindValue(":modulo", QString::fromLatin1(p.modulo));
            q.bindValue(":accion", QString::fromLatin1(p.accion));
            q.bindValue(":rol", QString::fromLatin1(p.rol));
            if (!q.exec()) {
                qWarning() << "No se pudo aplicar el permiso base:" << q.lastError().text();
            }
        }

        // "entrar" solo tiene sentido en habitaciones (acceso fisico sin
        // llave); el esquema original lo sembraba tambien en otros modulos.
        QSqlQuery quitar(db);
        if (!quitar.exec(QStringLiteral(
                "DELETE FROM Permisos WHERE accion_permitida = 'entrar' AND modulo <> 'habitaciones'"))) {
            qWarning() << "No se pudieron limpiar permisos 'entrar':" << quitar.lastError().text();
        }
    }
}

namespace Database
{
    QString rutaArchivo()
    {
        return s_rutaArchivo;
    }

    void fijarHabitacionKiosko(const QString &numero)
    {
        s_numeroKiosko = numero.trimmed();
    }

    int idHabitacionKiosko()
    {
        if (!s_numeroKiosko.isEmpty()) {
            QSqlQuery porNumero;
            porNumero.prepare(QStringLiteral("SELECT id_habitacion FROM Habitacion WHERE numero = :n"));
            porNumero.bindValue(":n", s_numeroKiosko);
            if (porNumero.exec() && porNumero.next()) {
                return porNumero.value(0).toInt();
            }
            qWarning() << "No existe la habitacion" << s_numeroKiosko << "- se usa la primera.";
        }
        QSqlQuery primera;
        if (primera.exec(QStringLiteral("SELECT MIN(id_habitacion) FROM Habitacion"))
            && primera.next() && !primera.value(0).isNull()) {
            return primera.value(0).toInt();
        }
        return -1;
    }

    bool respaldarSiHaceFalta()
    {
        if (s_rutaArchivo.isEmpty()) {
            return false;
        }
        const QFileInfo info(s_rutaArchivo);
        QDir carpeta(info.absolutePath() + QStringLiteral("/respaldos"));
        if (!carpeta.exists() && !QDir().mkpath(carpeta.absolutePath())) {
            qWarning() << "No se pudo crear la carpeta de respaldos:" << carpeta.absolutePath();
            return false;
        }
        const QString nombre = info.completeBaseName() + QLatin1Char('_')
                               + QDate::currentDate().toString(QStringLiteral("yyyy-MM-dd"))
                               + QStringLiteral(".db");
        if (carpeta.exists(nombre)) {
            return true; // ya hay respaldo de hoy
        }
        // VACUUM INTO hace una copia completa y consistente aunque la base
        // este en uso (en modo WAL copiar el .db a mano podria dejarla a medias).
        QSqlQuery copia;
        if (!copia.exec(QStringLiteral("VACUUM INTO '%1'")
                            .arg(carpeta.absoluteFilePath(nombre).replace(QLatin1Char('\''), QStringLiteral("''"))))) {
            qWarning() << "No se pudo respaldar la base de datos:" << copia.lastError().text();
            return false;
        }
        qDebug() << "Respaldo de la base creado en:" << carpeta.absoluteFilePath(nombre);

        const QStringList respaldos = carpeta.entryList(
            {info.completeBaseName() + QStringLiteral("_*.db")}, QDir::Files, QDir::Name);
        for (int i = 0; i < respaldos.size() - 7; ++i) {
            carpeta.remove(respaldos.at(i));
        }
        return true;
    }

    bool inicializar(const QString &rutaPersonalizada, bool cargarDemo)
    {
        // Theme 9: la ruta se puede cambiar para elegir donde vive la base
        // en cada instalacion (por ejemplo, un disco que se respalda).
        // Debe ser un disco LOCAL: SQLite en modo WAL no funciona bien en
        // carpetas compartidas de red. Si no se indica, se usa la carpeta
        // de datos de la aplicacion como hasta ahora.
        if (rutaPersonalizada.isEmpty()) {
            const QString carpeta = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
            QDir().mkpath(carpeta);
            s_rutaArchivo = carpeta + QStringLiteral("/nexstay_hotel.db");
        } else {
            QDir().mkpath(QFileInfo(rutaPersonalizada).absolutePath());
            s_rutaArchivo = rutaPersonalizada;
        }

        QSqlDatabase db = QSqlDatabase::addDatabase(QStringLiteral("QSQLITE"));
        db.setDatabaseName(s_rutaArchivo);

        if (!db.open()) {
            qWarning() << "No se pudo abrir la base de datos:" << db.lastError().text();
            return false;
        }

        qDebug() << "Base de datos SQLite abierta en:" << s_rutaArchivo;

        // SQLite exige activar esta pragma en CADA conexion; no basta con
        // que el script de creacion la tenga una vez.
        QSqlQuery pragma(db);
        if (!pragma.exec(QStringLiteral("PRAGMA foreign_keys = ON;"))) {
            qWarning() << "No se pudo activar foreign_keys:" << pragma.lastError().text();
        }

        // Modo WAL (Write-Ahead Logging): permite que varias instancias
        // de la app (p. ej. la pantalla de una habitacion y la de otra,
        // o un futuro panel de administracion) lean y escriban la misma
        // base de datos al mismo tiempo sin bloquearse entre si. Esto es
        // lo que hace viable el refresco en tiempo real del Task 4.
        QSqlQuery walMode(db);
        if (!walMode.exec(QStringLiteral("PRAGMA journal_mode = WAL;"))) {
            qWarning() << "No se pudo activar journal_mode WAL:" << walMode.lastError().text();
        } else if (walMode.next()) {
            // SQLite responde el modo que quedo; si no es "wal" (por ejemplo
            // en una carpeta de red), se avisa en lugar de fallar en silencio.
            const QString modo = walMode.value(0).toString();
            if (modo.compare(QLatin1String("wal"), Qt::CaseInsensitive) != 0) {
                qWarning() << "SQLite no pudo usar el modo WAL, quedo en:" << modo;
            } else {
                qDebug() << "Modo de diario de SQLite:" << modo;
            }
        }
        walMode.finish();

        QSqlQuery existe(db);
        existe.exec(QStringLiteral(
            "SELECT name FROM sqlite_master WHERE type='table' AND name='Habitacion'"));

        if (!existe.next()) {
            qDebug() << "Tablas no encontradas, creando esquema de NexStay...";

            const QStringList sentencias = dividirSentencias(QString::fromUtf8(kEsquemaSQL));
            for (const QString &sentencia : sentencias) {
                QSqlQuery q(db);
                if (!q.exec(sentencia)) {
                    qWarning() << "Error ejecutando sentencia SQL:" << q.lastError().text()
                               << "\n--- Sentencia ---\n" << sentencia;
                }
            }

            qDebug() << "Esquema de NexStay creado correctamente.";
        } else {
            qDebug() << "Esquema de NexStay ya existia, no se vuelve a crear.";
        }

        aplicarPermisosBase(db);
        if (cargarDemo) {
            sembrarHuespedDemo(db);
            sembrarDatosDemo(db);
        }

        return true;
    }
}
