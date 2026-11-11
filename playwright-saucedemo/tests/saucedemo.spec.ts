import { test, expect, Page } from '@playwright/test';

/*
 * Tres casos de prueba sobre https://www.saucedemo.com (tienda de demostracion publica).
 * TC-01 y TC-02 deberian pasar. TC-03 usa "problem_user", un usuario con errores
 * puestos a proposito por la web, asi que deberia FALLAR.
 */

// Paso reutilizable: hacer login con un usuario
async function login(page: Page, usuario: string) {
  await page.locator('#user-name').fill(usuario);
  await page.locator('#password').fill('secret_sauce');
  await page.locator('#login-button').click();
}

// ANTES de cada prueba: precondicion = estar en la pagina de login
test.beforeEach(async ({ page }) => {
  await page.goto('https://www.saucedemo.com/');
});

test('TC-01 Login correcto con standard_user', async ({ page }) => {
  await login(page, 'standard_user');
  // Resultado esperado: se ve la pagina de productos
  await expect(page.locator('.title')).toHaveText('Products');
});

test('TC-02 Usuario bloqueado ve mensaje de error', async ({ page }) => {
  await login(page, 'locked_out_user');
  // Resultado esperado: el sistema NO deja entrar y avisa
  await expect(page.locator('[data-test="error"]')).toContainText('locked out');
});

test('TC-03 Ordenar productos por precio de menor a mayor', async ({ page }) => {
  await login(page, 'problem_user');
  // Elegir "Price (low to high)" en el desplegable de ordenar
  await page.locator('.product_sort_container').selectOption('lohi');
  // Resultado esperado: el PRIMER precio de la lista es el mas barato ($7.99)
  await expect(page.locator('.inventory_item_price').first()).toHaveText('$7.99');
});
