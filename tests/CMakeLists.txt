# Theme 10: pruebas unitarias con Qt Test.
# En Qt Creator: compilar y correr el objetivo "pruebasNexStay", o abrir
# el panel de Pruebas (Tests) y darle "Ejecutar todas".
find_package(Qt6 REQUIRED COMPONENTS Test Sql Qml)

qt_add_executable(pruebasNexStay
    tst_nexstay.cpp
    ../Database.cpp
    ../Sesion.cpp
    ../ControlAcceso.cpp
    ../Reserva.cpp
    ../Recepcion.cpp
)

target_include_directories(pruebasNexStay PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/..)
target_link_libraries(pruebasNexStay PRIVATE Qt6::Test Qt6::Sql Qt6::Qml)

add_test(NAME pruebasNexStay COMMAND pruebasNexStay)
