# Verificación de operaciones de cajero con SQL

Base de datos **ficticia** que imita lo que registra un banco cuando se usa un cajero automático,
con los campos de un mensaje ISO 8583 (STAN, RRN, MTI, código de respuesta). Sirve para practicar
las consultas que hace un QA para verificar operaciones.

## Modelo de datos (9 tablas)

| Tabla | Qué representa | Campo ISO 8583 |
| --- | --- | --- |
| clientes | Titulares | - |
| cuentas | Cuentas y saldo | - |
| tarjetas | Tarjetas (PAN siempre enmascarado) | DE2 |
| cajeros | Terminales: fabricante, modelo, oficina | DE41 |
| codigos_respuesta | Diccionario de códigos (00, 51, 55...) | DE39 |
| transacciones | Cada operación: STAN, importe, respuesta, importe dispensado | DE11, DE4, DE39, DE38 |
| reversals | Anulaciones de operaciones no completadas | MTI 0420, DE90 |
| cierres | Cierre diario por cajero: total terminal y total host | - |
| contadores_cassette | Billetes por cassette: cargados, dispensados, rechazados, restantes, arqueo | - |

Relaciones: transacciones -> tarjetas -> cuentas -> clientes, transacciones -> cajeros,
transacciones -> codigos_respuesta, reversals -> transacciones, contadores_cassette -> cierres -> cajeros.

## Cómo usarlo (DBeaver + SQLite)

1. DBeaver -> New Database Connection -> SQLite -> Path: **Create...** -> `cajeros.db`.
2. Abrir `01_crear_bd_cajeros.sql`, conexión `cajeros.db`, ejecutar con **Alt + X**.
3. Repetir con `02_cierre_cajero.sql`.
4. Ejecutar las consultas de `consultas/` con **Ctrl + Enter**. Cada una indica su resultado esperado.

## Consultas

| Archivo | Contenido |
| --- | --- |
| consultas/01_select_basico.sql | Buscar por STAN, filtrar rechazos, franja horaria, coherencia de autorizaciones |
| consultas/02_joins.sql | Operación con todo su contexto, JOIN en estrella y en cadena, reversals, LEFT JOIN |
| consultas/03_agregaciones.sql | COUNT, GROUP BY, HAVING |
| consultas/04_cierre_diario.sql | Cuadre diario: contadores de cassettes, total terminal frente a host, informe CUADRADO/DESCUADRADO |

## Hallazgos del cierre del 16-11-2026

| Hallazgo | Tipo | Estado |
| --- | --- | --- |
| ATM00124 descuadrado: el host cobró 150 EUR más de lo dispensado | Transacciones | En investigación |
| ATM00231: el arqueo físico cuenta 1 billete de 50 EUR menos que los contadores | Efectivo | Pendiente de revisar |
