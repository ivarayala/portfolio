-- =====================================================================
--  04 - Verificacion del cierre diario (cuadre) de cajeros
--  Requiere 01_crear_bd_cajeros.sql y 02_cierre_cajero.sql
-- =====================================================================

-- V1. Contadores de cassettes: formula y arqueo fisico
-- cargados - dispensados - rechazados = restantes, contados (arqueo) = restantes
-- Esperado: 1 fila -> ATM00231 cassette 3 (50 EUR): faltan 50 EUR en el arqueo
SELECT ci.terminal_id, cc.cassette_num, cc.denominacion,
       cc.billetes_cargados - cc.billetes_dispensados - cc.billetes_rechazados AS restantes_calculados,
       cc.billetes_restantes, cc.billetes_contados,
       (cc.billetes_contados - cc.billetes_restantes) * cc.denominacion AS diferencia_eur
FROM contadores_cassette cc
JOIN cierres ci ON cc.cierre_id = ci.cierre_id
WHERE cc.billetes_cargados - cc.billetes_dispensados - cc.billetes_rechazados <> cc.billetes_restantes
   OR cc.billetes_contados <> cc.billetes_restantes;

-- V2. Total del terminal frente a sus propios contadores
-- Esperado: coinciden los 4 cajeros
SELECT ci.terminal_id, ci.total_terminal,
       SUM(cc.billetes_dispensados * cc.denominacion) AS dispensado_segun_contadores
FROM cierres ci
JOIN contadores_cassette cc ON cc.cierre_id = ci.cierre_id
GROUP BY ci.terminal_id, ci.total_terminal;

-- V3. Total del terminal frente a las operaciones registradas
-- Esperado: ATM00123 70, ATM00124 200, ATM00231 600, ATM00415 100
SELECT terminal_id, SUM(importe_dispensado) AS dispensado_segun_operaciones
FROM transacciones
WHERE tipo_operacion = 'RETIRADA' AND fecha_hora LIKE '2026-11-16%'
GROUP BY terminal_id;

-- V4a. Lo que el host cobro (retiradas aprobadas)
-- Esperado: ATM00123 170, ATM00124 350, ATM00231 600, ATM00415 120
SELECT terminal_id, SUM(importe) AS cobrado
FROM transacciones
WHERE tipo_operacion = 'RETIRADA' AND codigo_respuesta = '00'
  AND fecha_hora LIKE '2026-11-16%'
GROUP BY terminal_id;

-- V4b. Lo que el host devolvio (reversals)
-- Esperado: ATM00123 100, ATM00415 20
SELECT t.terminal_id, SUM(r.importe_revertido) AS devuelto
FROM reversals r
JOIN transacciones t ON r.trx_original_id = t.trx_id
WHERE t.fecha_hora LIKE '2026-11-16%'
GROUP BY t.terminal_id;

-- V5. Informe de cuadre
-- Esperado: ATM00124 DESCUADRADO (+150 EUR cobrados por el host), el resto CUADRADO
SELECT terminal_id, total_terminal, total_host,
       total_host - total_terminal AS diferencia,
       CASE WHEN total_host = total_terminal THEN 'CUADRADO' ELSE 'DESCUADRADO' END AS estado
FROM cierres
WHERE fecha_negocio = '2026-11-16';
