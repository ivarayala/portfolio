-- =====================================================================
--  AMPLIACION: CIERRE DIARIO (CUADRE) DE LOS CAJEROS
--  Requiere haber ejecutado antes 01_crear_bd_cajeros.sql
--  Datos FICTICIOS. Cierre del dia de negocio 2026-11-16.
--  Se puede ejecutar varias veces.
-- =====================================================================

PRAGMA foreign_keys = ON;

DROP TABLE IF EXISTS contadores_cassette;
DROP TABLE IF EXISTS cierres;

-- ---------- CIERRES: lo que el cajero y el host informan al cerrar el dia ----------
--  total_terminal = lo que el CAJERO dice que dispenso (sus contadores)
--  total_host     = lo que el HOST dice que se cargo en cuentas (aprobadas - reversals)
--  Si el cajero esta cuadrado, los dos deben coincidir.
CREATE TABLE cierres (
    cierre_id        INTEGER       PRIMARY KEY,
    terminal_id      CHAR(8)       NOT NULL REFERENCES cajeros(terminal_id),
    fecha_negocio    DATE          NOT NULL,
    hora_cierre      DATETIME      NOT NULL,
    total_terminal   DECIMAL(12,2) NOT NULL,
    total_host       DECIMAL(12,2) NOT NULL,
    resultado_host   VARCHAR(10)   NOT NULL CHECK (resultado_host IN ('OK','FALLIDO'))
);

-- ---------- CONTADORES POR CASSETTE: los billetes de cada cajon ----------
--  Regla: cargados - dispensados - rechazados = restantes (lo que el cajero calcula)
--  contados = lo que el operador cuenta a mano en el arqueo fisico
CREATE TABLE contadores_cassette (
    cierre_id             INTEGER       NOT NULL REFERENCES cierres(cierre_id),
    cassette_num          INTEGER       NOT NULL,
    denominacion          DECIMAL(6,2)  NOT NULL,   -- valor del billete: 10, 20, 50
    billetes_cargados     INTEGER       NOT NULL,   -- al reponer el cajero
    billetes_dispensados  INTEGER       NOT NULL,   -- entregados a clientes
    billetes_rechazados   INTEGER       NOT NULL,   -- al cajon de rechazo (atascos, billetes malos)
    billetes_restantes    INTEGER       NOT NULL,   -- segun los contadores del cajero
    billetes_contados     INTEGER       NOT NULL,   -- arqueo fisico
    PRIMARY KEY (cierre_id, cassette_num)
);

INSERT INTO cierres VALUES
 (1, 'ATM00123', '2026-11-16', '2026-11-16 23:59:00',  70.00,  70.00, 'OK'),
 (2, 'ATM00124', '2026-11-16', '2026-11-16 23:59:00', 200.00, 350.00, 'OK'),
 (3, 'ATM00231', '2026-11-16', '2026-11-16 23:59:00', 600.00, 600.00, 'OK'),
 (4, 'ATM00415', '2026-11-16', '2026-11-16 23:59:00', 100.00, 100.00, 'OK');

INSERT INTO contadores_cassette VALUES
 -- ATM00123: dispenso 1x50 (trx 004561) y 1x20 (004579); atasco en 004571: 2x50 al rechazo
 (1, 1, 10, 2000, 0, 0, 2000, 2000),
 (1, 2, 20, 2000, 1, 0, 1999, 1999),
 (1, 3, 50, 1000, 1, 2,  997,  997),
 -- ATM00124: dispenso 4x50 (004567); atasco en 004573: 3x50 al rechazo
 (2, 1, 10, 2000, 0, 0, 2000, 2000),
 (2, 2, 20, 2000, 0, 0, 2000, 2000),
 (2, 3, 50, 1000, 4, 3,  993,  993),
 -- ATM00231: dispenso 12x50 (004570)
 (3, 1, 10, 2000, 0, 0, 2000, 2000),
 (3, 2, 20, 2000, 0, 0, 2000, 2000),
 (3, 3, 50, 1000, 12, 0, 988, 987),
 -- ATM00415: 2x20 (004574) y 1x50 + 1x10 (004576); un billete de 20 al rechazo en 004576
 (4, 1, 10, 2000, 1, 0, 1999, 1999),
 (4, 2, 20, 2000, 2, 1, 1997, 1997),
 (4, 3, 50, 1000, 1, 0,  999,  999);

-- Comprobacion: esperado cierres 4, contadores_cassette 12
SELECT 'cierres' AS tabla, COUNT(*) AS filas FROM cierres
UNION ALL SELECT 'contadores_cassette', COUNT(*) FROM contadores_cassette;
