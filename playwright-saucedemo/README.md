# SauceDemo - Playwright + TypeScript

Pruebas E2E sobre [saucedemo.com](https://www.saucedemo.com), una tienda de demostración pública.

## Casos de prueba

| ID | Caso | Resultado esperado | Resultado |
| --- | --- | --- | --- |
| TC-01 | Login correcto con standard_user | Se muestra la página "Products" | PASS |
| TC-02 | Login con usuario bloqueado | Mensaje de error "locked out" | PASS |
| TC-03 | Ordenar por precio de menor a mayor (problem_user) | El primer producto cuesta $7.99 | **FAIL** -> [BUG-001](../bug-reports/BUG-001-saucedemo-ordenación-problem-user.md) |

## Ejecutar

```bash
npm install
npx playwright install chromium
npx playwright test          # terminal
npx playwright test --ui     # modo visual
npx playwright show-report   # informe HTML con capturas y trazas
```

## Qué demuestra

- Función reutilizable de login y `beforeEach` como precondicion.
- Aserciones con auto-wait (`toHaveText`, `toContainText`).
- Evidencias automáticas: captura y traza de cada prueba.
- Análisis del fallo: el resultado esperado se validó manualmente con standard_user antes de reportar.
