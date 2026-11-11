package com.ivar.qa;

import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.openqa.selenium.By;
import org.openqa.selenium.OutputType;
import org.openqa.selenium.TakesScreenshot;
import org.openqa.selenium.WebDriver;
import org.openqa.selenium.WebElement;
import org.openqa.selenium.chrome.ChromeDriver;
import org.openqa.selenium.chrome.ChromeOptions;
import org.openqa.selenium.support.ui.ExpectedConditions;
import org.openqa.selenium.support.ui.Select;
import org.openqa.selenium.support.ui.WebDriverWait;

import java.io.File;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.nio.file.StandardCopyOption;
import java.time.Duration;
import java.util.HashMap;
import java.util.Map;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

/**
 * Tres casos de prueba sobre https://www.saucedemo.com (tienda de demostracion publica).
 * TC-01 y TC-02 deberian pasar. TC-03 usa el usuario "problem_user", que tiene
 * errores puestos a proposito por la web, asi que deberia FALLAR.
 */
class SauceDemoTest {

    WebDriver driver;      // el "robot" que maneja Chrome
    WebDriverWait wait;    // espera explicita: aguanta hasta 10 s a que algo aparezca

    // Se ejecuta ANTES de cada @Test: precondicion = navegador abierto en la web
    @BeforeEach
    void abrirNavegador() {
        ChromeOptions opciones = new ChromeOptions();
        // Desactiva los avisos de contrasenas de Chrome, que pueden tapar la pagina
        Map<String, Object> prefs = new HashMap<>();
        prefs.put("credentials_enable_service", false);
        prefs.put("profile.password_manager_enabled", false);
        prefs.put("profile.password_manager_leak_detection", false);
        opciones.setExperimentalOption("prefs", prefs);

        driver = new ChromeDriver(opciones);   // Selenium Manager descarga el driver solo
        driver.manage().window().maximize();
        wait = new WebDriverWait(driver, Duration.ofSeconds(10));
        driver.get("https://www.saucedemo.com/");
    }

    // Paso reutilizable: hacer login con un usuario
    void login(String usuario) {
        driver.findElement(By.id("user-name")).sendKeys(usuario);
        driver.findElement(By.id("password")).sendKeys("secret_sauce");
        driver.findElement(By.id("login-button")).click();
    }

    @Test
    @DisplayName("TC-01 Login correcto con standard_user")
    void loginCorrecto() throws Exception {
        login("standard_user");
        WebElement titulo = wait.until(
                ExpectedConditions.visibilityOfElementLocated(By.className("title")));
        capturar("TC-01_login_correcto");
        // Resultado esperado: se ve la pagina de productos
        assertEquals("Products", titulo.getText());
    }

    @Test
    @DisplayName("TC-02 Usuario bloqueado ve mensaje de error")
    void usuarioBloqueado() throws Exception {
        login("locked_out_user");
        WebElement error = wait.until(
                ExpectedConditions.visibilityOfElementLocated(By.cssSelector("[data-test='error']")));
        capturar("TC-02_usuario_bloqueado");
        // Resultado esperado: el sistema NO deja entrar y avisa
        assertTrue(error.getText().contains("locked out"),
                "Deberia avisar de que el usuario esta bloqueado. Texto real: " + error.getText());
    }

    @Test
    @DisplayName("TC-03 Ordenar productos por precio de menor a mayor")
    void ordenarPorPrecio() throws Exception {
        login("problem_user");
        wait.until(ExpectedConditions.visibilityOfElementLocated(By.className("inventory_list")));

        // Elegir "Price (low to high)" en el desplegable de ordenar
        new Select(driver.findElement(By.className("product_sort_container"))).selectByValue("lohi");

        // Leer el precio del PRIMER producto de la lista
        String primerPrecio = driver.findElement(By.className("inventory_item_price")).getText();
        capturar("TC-03_ordenar_precio");

        // Resultado esperado: el primero es el mas barato de la tienda ($7.99)
        assertEquals("$7.99", primerPrecio,
                "Tras ordenar de menor a mayor, el primer producto deberia ser el mas barato");
    }

    // Guarda una captura de pantalla en target/evidencias/<nombre>.png
    void capturar(String nombre) throws Exception {
        Path destino = Paths.get("target", "evidencias", nombre + ".png");
        Files.createDirectories(destino.getParent());
        File foto = ((TakesScreenshot) driver).getScreenshotAs(OutputType.FILE);
        Files.copy(foto.toPath(), destino, StandardCopyOption.REPLACE_EXISTING);
    }

    // Se ejecuta DESPUES de cada @Test, pase o falle: cierra el navegador
    @AfterEach
    void cerrarNavegador() {
        if (driver != null) {
            driver.quit();
        }
    }
}
