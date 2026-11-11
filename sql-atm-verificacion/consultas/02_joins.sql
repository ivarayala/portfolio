-- =====================================================================
--  02 - JOIN: una operacion con todo su contexto
--  Metodo: empezar en la tabla con el dato conocido, saltar por las
--  claves foraneas (Owner.Column = RefTable.ReferenceColumn) hasta el dato que falta.
-- =====================================================================

-- Operacion rechazada: codigo, descripcion, estado de tarjeta y saldo
-- Camino: transacciones -> codigos_respuesta, transacciones -> tarjetas -> cuentas
-- Esperado: 004563 | 100 | 51 | Saldo insuficiente | ACTIVA | 35.2  (rechazo correcto)
SELECT t.stan, t.importe, t.codigo_respuesta, c.descripcion,
       ta.estado AS estado_tarjeta, cu.saldo
FROM transacciones t
JOIN codigos_respuesta c ON t.codigo_respuesta = c.codigo
JOIN tarjetas ta         ON t.tarjeta_id       = ta.tarjeta_id
JOIN cuentas cu          ON ta.cuenta_id       = cu.cuenta_id
WHERE t.stan = '004563';

-- Varios JOIN en estrella: fabricante del cajero y descripcion del codigo
-- Esperado: 5 filas (dia 17)
SELECT t.stan, ca.fabricante, c.descripcion
FROM transacciones t
JOIN cajeros ca          ON t.terminal_id      = ca.terminal_id
JOIN codigos_respuesta c ON t.codigo_respuesta = c.codigo
WHERE t.fecha_hora LIKE '2026-11-17%'
ORDER BY t.fecha_hora;

-- Reversals con su operacion original: revertido = pedido - dispensado
-- Esperado: 004572 anula 004571 (100), 004577 anula 004576 (20)
SELECT r.stan AS stan_reversal, r.importe_revertido, r.motivo,
       t.stan AS stan_original, t.importe, t.importe_dispensado
FROM reversals r
JOIN transacciones t ON r.trx_original_id = t.trx_id;

-- LEFT JOIN: tarjetas de otra entidad no tienen cuenta propia
-- Esperado: 8 filas, la tarjeta 8 (OTRA) con saldo NULL
SELECT ta.tarjeta_id, ta.entidad_emisora, cu.saldo
FROM tarjetas ta
LEFT JOIN cuentas cu ON ta.cuenta_id = cu.cuenta_id;
