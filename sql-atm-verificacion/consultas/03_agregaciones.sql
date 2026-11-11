-- =====================================================================
--  03 - COUNT, SUM, GROUP BY, HAVING
-- =====================================================================

-- Operaciones por codigo de respuesta
-- Esperado: 00 Aprobada 13, 51/54/55 2 cada uno, 61/75/91 1 cada uno
SELECT t.codigo_respuesta, c.descripcion, COUNT(*) AS total
FROM transacciones t
JOIN codigos_respuesta c ON t.codigo_respuesta = c.codigo
GROUP BY t.codigo_respuesta, c.descripcion
ORDER BY total DESC;

-- Operaciones por fabricante de cajero
-- Esperado: Diebold Nixdorf 11, Hyosung 5, NCR 6
SELECT ca.fabricante, COUNT(*) AS operaciones
FROM transacciones t
JOIN cajeros ca ON t.terminal_id = ca.terminal_id
GROUP BY ca.fabricante;

-- Tarjetas con 2 o mas rechazos
-- Esperado: tarjeta 2 -> 2, tarjeta 4 -> 3, tarjeta 5 -> 2
SELECT tarjeta_id, COUNT(*) AS rechazos
FROM transacciones
WHERE codigo_respuesta <> '00'
GROUP BY tarjeta_id
HAVING COUNT(*) >= 2;
