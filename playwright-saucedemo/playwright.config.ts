import { defineConfig, devices } from '@playwright/test';

// Configuracion general: donde estan las pruebas, que informes generar y que evidencias guardar
export default defineConfig({
  testDir: './tests',          // carpeta donde Playwright busca los *.spec.ts
  timeout: 30_000,             // tiempo maximo por prueba: 30 s
  retries: 0,                  // 0 = si falla, no reintenta (asi ves el fallo real)
  reporter: [
    ['list'],                                  // resultado en la terminal
    ['html', { open: 'never' }],               // informe web en playwright-report/
  ],
  use: {
    headless: false,           // false = ves el navegador; true = trabaja oculto
    launchOptions: { slowMo: 500 },   // 0,5 s entre acciones para que puedas seguirlo
    screenshot: 'on',          // captura de pantalla al final de cada prueba
    trace: 'on',               // grabacion paso a paso de cada prueba
  },
  projects: [
    { name: 'chromium', use: { ...devices['Desktop Chrome'] } },
  ],
});
