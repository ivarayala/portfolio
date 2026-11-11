# Portfolio QA - Ivar Ayala

> QA Engineer (manual -> automation) orientado a banca y fintech.
> Proyectos prácticos de verificación de datos con SQL y automatización de pruebas web.

## Contenido

| Proyecto | Qué demuestra | Tecnologías |
| --- | --- | --- |
| [sql-atm-verificacion](sql-atm-verificacion/) | Verificar operaciones de cajero con SQL: buscar por STAN, cruzar tablas con JOIN, detectar inconsistencias y comprobar el cierre diario (cuadre) | SQL, SQLite, DBeaver |
| [playwright-saucedemo](playwright-saucedemo/) | Automatización E2E: login, usuario bloqueado y detección de un bug de ordenación, con evidencias (capturas y trazas) | Playwright, TypeScript |
| [selenium-saucedemo](selenium-saucedemo/) | Los mismos casos con Selenium WebDriver, JUnit 5 y Maven (esperas explícitas, capturas) | Java, Selenium, JUnit 5, Maven |
| [bug-reports](bug-reports/) | Reportes de defectos con pasos, esperado/obtenido, severidad y evidencias | Jira-style |

## Enfoque de trabajo

1. **Resultado esperado desde el requisito**, nunca desde lo que la aplicación hace hoy.
2. Ante un fallo: comprobar el esperado -> reproducir a mano -> medir el alcance -> reportar.
3. Verificar en la fuente de datos (SQL, logs) y no solo en pantalla.
4. Sin datos reales: todos los datos de este repositorio son **ficticios**.

## Próximos pasos

- [ ] Consulta de detección de defectos (retirada aprobada sin dispensar y sin reversal)
- [ ] Ejecutar y documentar el proyecto Selenium
- [ ] Escenarios en Gherkin (BDD) para los casos de SauceDemo
- [ ] Pipeline de CI (GitHub Actions) para Playwright

## Contacto

LinkedIn: _(añadir enlace)_
