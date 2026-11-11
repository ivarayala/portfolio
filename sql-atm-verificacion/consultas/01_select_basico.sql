-- =====================================================================
--  01 - SELECT basico: buscar y filtrar operaciones
--  Ejecutar sobre la base creada con 01_crear_bd_cajeros.sql
-- =====================================================================

-- Buscar una operacion concreta por su STAN (DE11)
-- Esperado: 1 fila -> ATM00124, RETIRADA, 200, codigo 00
SELECT trx_id, stan, terminal_id, tipo_operacion, importe, codigo_respuesta
FROM transacciones
WHERE stan = '004567';

-- Retiradas rechazadas (codigo distinto de 00)
-- Esperado: 8 filas
SELECT stan, importe, codigo_respuesta
FROM transacciones
WHERE tipo_operacion = 'RETIRADA'
  AND codigo_respuesta <> '00';

-- Operaciones de un cajero en una franja horaria (verificar un caso recien ejecutado)
-- Esperado: 004568 (54), 004569 (61), 004570 (00)
SELECT stan, tipo_operacion, importe, codigo_respuesta, importe_dispensado, fecha_hora
FROM transacciones
WHERE terminal_id = 'ATM00231'
  AND fecha_hora BETWEEN '2026-11-16 10:30:00' AND '2026-11-16 11:00:00'
ORDER BY fecha_hora;

-- Coherencia: las operaciones no aprobadas no deben tener codigo de autorizacion (DE38)
-- Esperado: 0 filas
SELECT stan, codigo_respuesta, codigo_autorizacion
FROM transacciones
WHERE codigo_respuesta <> '00'
  AND codigo_autorizacion IS NOT NULL;
