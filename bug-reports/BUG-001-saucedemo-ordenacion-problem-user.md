# BUG-001 - Inventario: "Price (low to high)" no ordena los productos (problem_user)

| Campo | Valor |
| --- | --- |
| Entorno | https://www.saucedemo.com, Chromium (Playwright), Windows 11 |
| Severidad | Media (la función no hace nada, pero se puede comprar sin ordenar) |
| Caso relacionado | TC-03 Ordenar productos por precio de menor a mayor |
| Reproducible | Sí, 3 de 3 (automático y manual) |

## Precondiciones
Usuario `problem_user` / `secret_sauce`.

## Pasos para reproducir
1. Abrir https://www.saucedemo.com
2. Hacer login con problem_user
3. En el desplegable de ordenar, elegir "Price (low to high)"

## Resultado esperado
El primer producto es el más barato ($7.99).

## Resultado obtenido
La lista no cambia de orden: el primer producto cuesta $29.99.

## Alcance
Con `standard_user` la ordenación funcióna correctamente: el defecto afecta solo a problem_user.

## Evidencias
- Salida de la prueba: `Expected: "$7.99" / Received: "$29.99"`
- Captura y traza de Playwright (informe HTML de la ejecución)

## Análisis
Antes de reportar se validó el resultado esperado (con standard_user el primer precio es $7.99)
y se reprodujo manualmente, descartando un error del script.
