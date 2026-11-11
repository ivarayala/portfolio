-- =====================================================================
--  BASE DE DATOS DE PRACTICA: CAJEROS (ATM) - modelo generico de banca
--  Datos 100% FICTICIOS. Inspirada en la estructura de una operacion
--  de cajero (mensajes ISO 8583: STAN, RRN, MTI, codigo de respuesta).
--  Motor: SQLite (para practicar en local con DBeaver).
--  Se puede ejecutar varias veces: borra y vuelve a crear todo.
-- =====================================================================

PRAGMA foreign_keys = ON;   -- en SQLite hay que activar las claves foraneas

-- ---------- 0. Borrar si ya existian (orden inverso a la creacion) ----------
DROP TABLE IF EXISTS reversals;
DROP TABLE IF EXISTS transacciones;
DROP TABLE IF EXISTS codigos_respuesta;
DROP TABLE IF EXISTS cajeros;
DROP TABLE IF EXISTS tarjetas;
DROP TABLE IF EXISTS cuentas;
DROP TABLE IF EXISTS clientes;

-- ---------- 1. CLIENTES: las personas ----------
CREATE TABLE clientes (
    cliente_id      INTEGER      PRIMARY KEY,
    nombre          VARCHAR(50)  NOT NULL,
    apellidos       VARCHAR(80)  NOT NULL,
    fecha_alta      DATE         NOT NULL,
    segmento        VARCHAR(20)  NOT NULL CHECK (segmento IN ('PARTICULAR','SENIOR','JOVEN'))
);

-- ---------- 2. CUENTAS: donde esta el dinero (un cliente puede tener varias) ----------
CREATE TABLE cuentas (
    cuenta_id       INTEGER       PRIMARY KEY,
    cliente_id      INTEGER       NOT NULL REFERENCES clientes(cliente_id),
    iban            VARCHAR(34)   NOT NULL UNIQUE,
    tipo_cuenta     VARCHAR(20)   NOT NULL CHECK (tipo_cuenta IN ('CORRIENTE','AHORRO')),
    saldo           DECIMAL(12,2) NOT NULL,
    moneda          CHAR(3)       NOT NULL DEFAULT 'EUR',
    estado          VARCHAR(15)   NOT NULL CHECK (estado IN ('ACTIVA','BLOQUEADA','CANCELADA'))
);

-- ---------- 3. TARJETAS: el PAN SIEMPRE enmascarado (PCI DSS) ----------
--  cuenta_id es NULL cuando la tarjeta es de OTRA entidad (no tenemos su cuenta)
CREATE TABLE tarjetas (
    tarjeta_id              INTEGER       PRIMARY KEY,
    cuenta_id               INTEGER       REFERENCES cuentas(cuenta_id),
    pan_enmascarado         VARCHAR(19)   NOT NULL,
    entidad_emisora         VARCHAR(20)   NOT NULL,
    tipo_tarjeta            VARCHAR(10)   NOT NULL CHECK (tipo_tarjeta IN ('DEBITO','CREDITO')),
    fecha_caducidad         CHAR(7)       NOT NULL,          -- formato AAAA-MM
    estado                  VARCHAR(15)   NOT NULL CHECK (estado IN ('ACTIVA','BLOQUEADA','CADUCADA')),
    intentos_pin_fallidos   INTEGER       NOT NULL DEFAULT 0,
    limite_diario_retirada  DECIMAL(10,2) NOT NULL DEFAULT 600.00
);

-- ---------- 4. CAJEROS: cada terminal (DE41 en ISO 8583) ----------
CREATE TABLE cajeros (
    terminal_id     CHAR(8)       PRIMARY KEY,
    fabricante      VARCHAR(20)   NOT NULL,
    modelo          VARCHAR(40)   NOT NULL,
    oficina         VARCHAR(40)   NOT NULL,
    ciudad          VARCHAR(30)   NOT NULL,
    version_sw      VARCHAR(10)   NOT NULL,
    estado          VARCHAR(20)   NOT NULL CHECK (estado IN ('EN_SERVICIO','FUERA_DE_SERVICIO'))
);

-- ---------- 5. CODIGOS DE RESPUESTA: tabla de consulta (DE39) ----------
CREATE TABLE codigos_respuesta (
    codigo          CHAR(2)       PRIMARY KEY,
    descripcion     VARCHAR(60)   NOT NULL,
    familia         VARCHAR(10)   NOT NULL CHECK (familia IN ('APROBADA','CLIENTE','TARJETA','SISTEMA'))
);

-- ---------- 6. TRANSACCIONES: cada operacion hecha en un cajero ----------
CREATE TABLE transacciones (
    trx_id               INTEGER       PRIMARY KEY,
    stan                 CHAR(6)       NOT NULL,            -- DE11
    rrn                  CHAR(12)      NOT NULL,            -- DE37
    mti                  CHAR(4)       NOT NULL,            -- 0200 = peticion financiera
    terminal_id          CHAR(8)       NOT NULL REFERENCES cajeros(terminal_id),
    tarjeta_id           INTEGER       NOT NULL REFERENCES tarjetas(tarjeta_id),
    tipo_operacion       VARCHAR(20)   NOT NULL CHECK (tipo_operacion IN ('RETIRADA','CONSULTA_SALDO')),
    codigo_proceso       CHAR(6)       NOT NULL,            -- DE3: 01xxxx retirada, 31xxxx consulta
    importe              DECIMAL(12,2) NOT NULL,            -- DE4 (0 en consultas)
    moneda               CHAR(3)       NOT NULL DEFAULT '978', -- DE49: 978 = euro
    codigo_respuesta     CHAR(2)       NOT NULL REFERENCES codigos_respuesta(codigo), -- DE39
    codigo_autorizacion  CHAR(6),                           -- DE38: solo si se aprobo
    importe_dispensado   DECIMAL(12,2),                     -- lo que salio de verdad; NULL si no aplica
    fecha_hora           DATETIME      NOT NULL
);

-- ---------- 7. REVERSALS: anulaciones (MTI 0420) de operaciones que no se completaron ----------
CREATE TABLE reversals (
    reversal_id        INTEGER       PRIMARY KEY,
    trx_original_id    INTEGER       NOT NULL REFERENCES transacciones(trx_id),  -- DE90
    stan               CHAR(6)       NOT NULL,
    mti                CHAR(4)       NOT NULL DEFAULT '0420',
    importe_revertido  DECIMAL(12,2) NOT NULL,
    motivo             VARCHAR(30)   NOT NULL,
    codigo_respuesta   CHAR(2)       NOT NULL REFERENCES codigos_respuesta(codigo),
    fecha_hora         DATETIME      NOT NULL
);

-- =====================================================================
--  DATOS
-- =====================================================================

INSERT INTO clientes VALUES
 (1, 'Ana',    'Martin Lopez',    '2015-03-12', 'PARTICULAR'),
 (2, 'Jordi',  'Puig Ferrer',     '2019-07-01', 'JOVEN'),
 (3, 'Lucia',  'Romero Diaz',     '2008-11-20', 'PARTICULAR'),
 (4, 'Marc',   'Soler Vila',      '2021-02-15', 'JOVEN'),
 (5, 'Carmen', 'Vidal Ruiz',      '1999-05-30', 'SENIOR'),
 (6, 'Pedro',  'Navarro Gil',     '2012-09-08', 'PARTICULAR');

INSERT INTO cuentas VALUES
 (1, 1, 'ES00 9999 0000 0000 0000 0001', 'CORRIENTE', 1250.00, 'EUR', 'ACTIVA'),
 (2, 2, 'ES00 9999 0000 0000 0000 0002', 'CORRIENTE',   35.20, 'EUR', 'ACTIVA'),
 (3, 3, 'ES00 9999 0000 0000 0000 0003', 'CORRIENTE', 8400.00, 'EUR', 'ACTIVA'),
 (4, 4, 'ES00 9999 0000 0000 0000 0004', 'CORRIENTE',  410.75, 'EUR', 'ACTIVA'),
 (5, 5, 'ES00 9999 0000 0000 0000 0005', 'AHORRO',     620.50, 'EUR', 'ACTIVA'),
 (6, 6, 'ES00 9999 0000 0000 0000 0006', 'CORRIENTE',  150.00, 'EUR', 'ACTIVA'),
 (7, 1, 'ES00 9999 0000 0000 0000 0007', 'AHORRO',    5000.00, 'EUR', 'ACTIVA');

INSERT INTO tarjetas VALUES
 (1, 1,    '400012******0001', 'PROPIA', 'DEBITO',  '2028-05', 'ACTIVA',    0, 600.00),
 (2, 2,    '400012******0002', 'PROPIA', 'DEBITO',  '2027-09', 'ACTIVA',    0, 600.00),
 (3, 3,    '400012******0003', 'PROPIA', 'DEBITO',  '2029-01', 'ACTIVA',    0, 600.00),
 (4, 4,    '400012******0004', 'PROPIA', 'DEBITO',  '2028-12', 'BLOQUEADA', 3, 600.00),
 (5, 5,    '400012******0005', 'PROPIA', 'DEBITO',  '2025-10', 'CADUCADA',  0, 600.00),
 (6, 6,    '400012******0006', 'PROPIA', 'DEBITO',  '2027-03', 'ACTIVA',    0, 600.00),
 (7, 7,    '520011******0007', 'PROPIA', 'CREDITO', '2028-08', 'ACTIVA',    0, 1000.00),
 (8, NULL, '471234******0008', 'OTRA',      'DEBITO',  '2027-06', 'ACTIVA',    0, 600.00);

INSERT INTO cajeros VALUES
 ('ATM00123', 'NCR',             'SelfServ 84',      'Les Corts',  'Barcelona', '5.2.0', 'EN_SERVICIO'),
 ('ATM00124', 'Diebold Nixdorf', 'DN Series 200',    'Sants',      'Barcelona', '5.2.0', 'EN_SERVICIO'),
 ('ATM00231', 'Hyosung',         'MoniMax 8600',     'Castellana', 'Madrid',    '5.1.3', 'EN_SERVICIO'),
 ('ATM00310', 'NCR',             'SelfServ 84',      'Triana',     'Sevilla',   '5.1.3', 'FUERA_DE_SERVICIO'),
 ('ATM00415', 'Diebold Nixdorf', 'DN Series 200',    'Ruzafa',     'Valencia',  '5.2.0', 'EN_SERVICIO');

INSERT INTO codigos_respuesta VALUES
 ('00', 'Aprobada',                              'APROBADA'),
 ('05', 'No autorizada (do not honor)',          'TARJETA'),
 ('14', 'Tarjeta no valida',                     'TARJETA'),
 ('51', 'Saldo insuficiente',                    'CLIENTE'),
 ('54', 'Tarjeta caducada',                      'TARJETA'),
 ('55', 'PIN incorrecto',                        'CLIENTE'),
 ('61', 'Supera el limite de importe',           'CLIENTE'),
 ('75', 'Superados los intentos de PIN',         'CLIENTE'),
 ('91', 'Emisor no disponible',                  'SISTEMA'),
 ('96', 'Fallo del sistema',                     'SISTEMA');

INSERT INTO transacciones
 (trx_id, stan, rrn, mti, terminal_id, tarjeta_id, tipo_operacion, codigo_proceso, importe, moneda, codigo_respuesta, codigo_autorizacion, importe_dispensado, fecha_hora)
VALUES
 ( 1, '004561', '632009004561', '0200', 'ATM00123', 1, 'RETIRADA',       '011000',  50.00, '978', '00', 'A1B2C3',  50.00, '2026-11-16 09:30:15'),
 ( 2, '004562', '632009004562', '0200', 'ATM00123', 1, 'CONSULTA_SALDO', '311000',   0.00, '978', '00', 'A1B2C4',   NULL, '2026-11-16 09:31:02'),
 ( 3, '004563', '632009004563', '0200', 'ATM00123', 2, 'RETIRADA',       '011000', 100.00, '978', '51', NULL,       NULL, '2026-11-16 09:45:40'),
 ( 4, '004564', '632009004564', '0200', 'ATM00124', 4, 'RETIRADA',       '011000',  60.00, '978', '55', NULL,       NULL, '2026-11-16 10:02:11'),
 ( 5, '004565', '632009004565', '0200', 'ATM00124', 4, 'RETIRADA',       '011000',  60.00, '978', '55', NULL,       NULL, '2026-11-16 10:02:48'),
 ( 6, '004566', '632009004566', '0200', 'ATM00124', 4, 'RETIRADA',       '011000',  60.00, '978', '75', NULL,       NULL, '2026-11-16 10:03:20'),
 ( 7, '004567', '632009004567', '0200', 'ATM00124', 3, 'RETIRADA',       '011000', 200.00, '978', '00', 'B7K2P1', 200.00, '2026-11-16 10:15:00'),
 ( 8, '004568', '632009004568', '0200', 'ATM00231', 5, 'RETIRADA',       '011000',  60.00, '978', '54', NULL,       NULL, '2026-11-16 10:40:33'),
 ( 9, '004569', '632009004569', '0200', 'ATM00231', 3, 'RETIRADA',       '011000', 700.00, '978', '61', NULL,       NULL, '2026-11-16 10:52:10'),
 (10, '004570', '632009004570', '0200', 'ATM00231', 3, 'RETIRADA',       '011000', 600.00, '978', '00', 'C3M9Q2', 600.00, '2026-11-16 10:53:01'),
 (11, '004571', '632009004571', '0200', 'ATM00123', 6, 'RETIRADA',       '011000', 100.00, '978', '00', 'D4N8R3',   0.00, '2026-11-16 11:05:02'),
 (12, '004573', '632009004573', '0200', 'ATM00124', 1, 'RETIRADA',       '011000', 150.00, '978', '00', 'E5P7S4',   0.00, '2026-11-16 11:20:45'),
 (13, '004574', '632009004574', '0200', 'ATM00415', 8, 'RETIRADA',       '011000',  40.00, '978', '00', 'F6Q6T5',  40.00, '2026-11-16 12:10:30'),
 (14, '004575', '632009004575', '0200', 'ATM00415', 7, 'RETIRADA',       '011000', 300.00, '978', '91', NULL,       NULL, '2026-11-16 12:30:12'),
 (15, '004576', '632009004576', '0200', 'ATM00415', 6, 'RETIRADA',       '011000',  80.00, '978', '00', 'G7R5U6',  60.00, '2026-11-16 13:00:05'),
 (16, '004578', '632009004578', '0200', 'ATM00124', 3, 'CONSULTA_SALDO', '311000',   0.00, '978', '00', 'H8S4V7',   NULL, '2026-11-16 16:45:00'),
 (17, '004579', '632009004579', '0200', 'ATM00123', 2, 'RETIRADA',       '011000',  20.00, '978', '00', 'J9T3W8',  20.00, '2026-11-16 18:20:00'),
 (18, '004580', '632009004580', '0200', 'ATM00123', 1, 'RETIRADA',       '011000',  40.00, '978', '00', 'K1U2X9',  40.00, '2026-11-17 08:55:10'),
 (19, '004581', '632009004581', '0200', 'ATM00231', 3, 'RETIRADA',       '011000',  50.00, '978', '00', 'L2V1Y1',  50.00, '2026-11-17 09:12:44'),
 (20, '004582', '632009004582', '0200', 'ATM00124', 6, 'RETIRADA',       '011000',  30.00, '978', '00', 'M3W9Z2',  30.00, '2026-11-17 10:05:31'),
 (21, '004583', '632009004583', '0200', 'ATM00124', 2, 'RETIRADA',       '011000',  20.00, '978', '51', NULL,       NULL, '2026-11-17 11:40:18'),
 (22, '004584', '632009004584', '0200', 'ATM00231', 5, 'CONSULTA_SALDO', '311000',   0.00, '978', '54', NULL,       NULL, '2026-11-17 12:15:00');

INSERT INTO reversals
 (reversal_id, trx_original_id, stan, mti, importe_revertido, motivo, codigo_respuesta, fecha_hora)
VALUES
 (1, 11, '004572', '0420', 100.00, 'FALLO_DISPENSADOR',    '00', '2026-11-16 11:05:12'),
 (2, 15, '004577', '0420',  20.00, 'DISPENSACION_PARCIAL', '00', '2026-11-16 13:00:15');

-- =====================================================================
--  COMPROBACION: cuantas filas tiene cada tabla
--  Esperado: clientes 6, cuentas 7, tarjetas 8, cajeros 5,
--            codigos_respuesta 10, transacciones 22, reversals 2
-- =====================================================================
SELECT 'clientes' AS tabla, COUNT(*) AS filas FROM clientes
UNION ALL SELECT 'cuentas',           COUNT(*) FROM cuentas
UNION ALL SELECT 'tarjetas',          COUNT(*) FROM tarjetas
UNION ALL SELECT 'cajeros',           COUNT(*) FROM cajeros
UNION ALL SELECT 'codigos_respuesta', COUNT(*) FROM codigos_respuesta
UNION ALL SELECT 'transacciones',     COUNT(*) FROM transacciones
UNION ALL SELECT 'reversals',         COUNT(*) FROM reversals;
