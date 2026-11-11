# SauceDemo - Selenium WebDriver + Java

Los mismos casos que el proyecto Playwright, con Selenium 4, JUnit 5 y Maven.

## Ejecutar

```bash
mvn test
```

Requisitos: JDK 17 o superior, Maven y Chrome (Selenium Manager descarga el driver).
Las capturas se guardan en `target/evidencias/`.

## Qué demuestra

- Ciclo de vida con `@BeforeEach` (crear el navegador) y `@AfterEach` (`driver.quit()`).
- Localizadores `By.id`, `By.className`, `By.cssSelector`.
- Esperas explícitas con `WebDriverWait` y `ExpectedConditions`.
- Desplegables con `Select`, aserciones con `assertEquals`.

Estado: pendiente de ejecutar y documentar resultados.
