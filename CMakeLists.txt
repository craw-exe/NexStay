cmake_minimum_required(VERSION 3.16)

project(NexStay VERSION 0.1 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(QT_QML_GENERATE_QMLLS_INI ON)

find_package(Qt6 REQUIRED COMPONENTS Quick Sql Network)

qt_standard_project_setup(REQUIRES 6.8)

# Content of downloaded design from Figma to Qt or similar
if (EXISTS "${CMAKE_CURRENT_LIST_DIR}/importedcontent/CMakeLists.txt")
    add_subdirectory(${CMAKE_CURRENT_LIST_DIR}/importedcontent)
endif()

qt_add_executable(appNexStay
    main.cpp
    Database.h
    Database.cpp
)

# Rediseño de interfaz: paleta comun para todas las pantallas.
set_source_files_properties(Tema.qml PROPERTIES QT_QML_SINGLETON_TYPE TRUE)

qt_add_qml_module(appNexStay
    URI NexStay
    QML_FILES
        Main.qml
        RegistroHuesped.qml
        PantallaCalendarioReservas.qml
        PantallaLogin.qml
        PantallaBitacoraAcceso.qml
        PantallaSolicitudes.qml
        PantallaPrincipal.qml
        PantallaAdministracion.qml
        PantallaReportes.qml
        PantallaHabitaciones.qml
        Tema.qml
        ResaltadoHover.qml
        BotonApp.qml
        SelectorFecha.qml
        ConfiguracionKiosko.qml
        AppMovil.qml
    SOURCES
        Habitacion.h
        Habitacion.cpp
        Reserva.h
        Reserva.cpp
        HistorialEstadia.h
        HistorialEstadia.cpp
        CalendarioReservas.h
        CalendarioReservas.cpp
        Sesion.h
        Sesion.cpp
        ControlAcceso.h
        ControlAcceso.cpp
        BitacoraAcceso.h
        BitacoraAcceso.cpp
        SolicitudesHuesped.h
        SolicitudesHuesped.cpp
        AlertasPersonal.h
        AlertasPersonal.cpp
        AdministracionUsuarios.h
        AdministracionUsuarios.cpp
        Reportes.h
        Reportes.cpp
        ListaHabitaciones.h
        ListaHabitaciones.cpp
        Recepcion.h
        Recepcion.cpp
        ServidorPersonal.h
        ServidorPersonal.cpp
        ConexionHotel.h
        ConexionHotel.cpp
    RESOURCES
        datos_demo.sql
)

# Qt for iOS sets MACOSX_BUNDLE_GUI_IDENTIFIER automatically since Qt 6.1.
# If you are developing for iOS or macOS you should consider setting an
# explicit, fixed bundle identifier manually though.
set_target_properties(appNexStay PROPERTIES
#    MACOSX_BUNDLE_GUI_IDENTIFIER com.example.appNexStay
    MACOSX_BUNDLE_BUNDLE_VERSION ${PROJECT_VERSION}
    MACOSX_BUNDLE_SHORT_VERSION_STRING ${PROJECT_VERSION_MAJOR}.${PROJECT_VERSION_MINOR}
    MACOSX_BUNDLE TRUE
    WIN32_EXECUTABLE TRUE
)

target_link_libraries(appNexStay
    PRIVATE Qt6::Quick Qt6::Sql Qt6::Network
)

# Theme 11 Task 5: datos de la app para Android (version celular).
set_target_properties(appNexStay PROPERTIES
    QT_ANDROID_PACKAGE_NAME "mx.nexora.nexstay"
    QT_ANDROID_APP_NAME "NexStay"
    QT_ANDROID_VERSION_NAME "1.1"
    QT_ANDROID_VERSION_CODE 2
)

# Theme 10: pruebas unitarias (carpeta tests). En Android no se compilan:
# se corren en la PC.
if (NOT ANDROID)
    enable_testing()
    add_subdirectory(tests)
endif()

install(TARGETS appNexStay
    BUNDLE DESTINATION .
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
)
