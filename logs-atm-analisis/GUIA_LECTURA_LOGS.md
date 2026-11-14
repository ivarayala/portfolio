# Guía: cómo leer logs de cajero con klogg

Guía paso a paso para los logs de esta práctica. Primero aprendes cómo es cada log, después cómo funciona klogg y por último sigues una operación de principio a fin por los tres logs.

---

## 1. Los 3 logs de la práctica

Analogía: una retirada es un partido y cada log es un periodista que lo cuenta desde su sitio. El **EJ** cuenta el resultado, el **log de aplicación** cuenta la jugada a jugada dentro del cajero y el **log del host** cuenta lo que se habló con el banco. Si las tres crónicas no coinciden, ahí hay algo que investigar.

### 1.1 EJ – Electronic Journal (diario electrónico): `EJ_ATM0010x_20261118.txt`

- **Uno por cajero.** Cuenta la operación en lenguaje de negocio.
- **Un bloque por operación**, separado por una línea `=====`.
- Tiene que leerse como una historia: tarjeta → PIN → importe → respuesta del banco → billetes → tarjeta devuelta.

```
========================================================
18/11/2026 08:47:00   ATM00101   OFICINA CENTRO     <- fecha, hora, cajero, oficina
TRX SEQ 0002                                        <- n.º de operación del día en ESTE cajero
CARD INSERTED       400012******0003   (CHIP)       <- tarjeta enmascarada y cómo se leyó
PIN ENTERED
WITHDRAWAL REQUEST  100.00 EUR                      <- lo que pidió el cliente
STAN 000102                                         <- la llave para buscar en los otros logs
HOST RESPONSE       00  AUTH 391369                 <- DE39 y código de autorización
NOTES PRESENTED     2 x 50                          <- lo que salió por la boca
NOTES TAKEN                                         <- el cliente lo cogió
RECEIPT PRINTED
CARD RETURNED
CARD TAKEN
TRANSACTION END
```

Además de operaciones, el EJ tiene **bloques de supervisor**: la carga de casetes al empezar el día, los resets de piezas y los `TERMINAL TOTALS` del cierre.

### 1.2 Application log (log de aplicación): `APP_ATM0010x_20261118.log`

- **Uno por cajero.** Cuenta lo técnico, **una línea por evento**.
- Cada línea tiene 4 partes:

```
2026-11-18 08:47:10.728 [INFO ] [HOST] Received 0210 STAN=000102 DE39=00
|------ timestamp -----| |nivel| |comp| |------------ mensaje ------------|
```

| Componente | Qué es |
| --- | --- |
| IDC | Lector de tarjetas (Identification Card unit) |
| PIN | Teclado cifrador (Encrypting PIN Pad) |
| CDM | Dispensador de billetes (Cash Dispenser Module) |
| PTR | Impresora (Printer) |
| HOST | Comunicación con el banco |
| TRX | Lógica de la transacción: decide qué hacer |
| UI | Pantallas |
| SUP | Modo supervisor |
| SYS / XFS / SIU | Sistema, capa XFS, sensores |

| Nivel | Qué significa | ¿Lo miro? |
| --- | --- | --- |
| DEBUG | Detalle para desarrolladores | Casi nunca: es ruido, salvo para buscar datos sensibles mal escritos |
| INFO | Funcionamiento normal | Para seguir una operación |
| WARN | Algo raro, pero el cajero sigue | **Siempre** |
| ERROR | Algo falló | **Siempre** |
| FATAL | Falla grave: la pieza o el cajero se para | **Siempre** |

### 1.3 Log del host (ISO 8583): `HOST_ISO8583_20261118.log`

- **Uno para los 3 cajeros mezclados**, en orden de hora.
- **Cada mensaje ocupa varias líneas**: una cabecera y debajo sus campos.

```
2026-11-18 08:47:10.000 >>> SEND ATM00101 MTI=0200    <- >>> SEND = sale del cajero hacia el banco
    [002] 400012******0003                            <- DE2  PAN enmascarado
    [003] 011000                                      <- DE3  01 = retirada
    [004] 000000010000                                <- DE4  100,00 EUR (en céntimos)
    [007] 1118074710                                  <- DE7  en GMT (07:47 = 08:47 en Madrid)
    [011] 000102                                      <- DE11 STAN
    [041] ATM00101                                    <- DE41 cajero
    ...
2026-11-18 08:47:10.728 <<< RECV ATM00101 MTI=0210    <- <<< RECV = la respuesta del banco
    [011] 000102
    [038] 391369                                      <- autorización
    [039] 00                                          <- aprobada
```

Muy importante:
- **La cabecera dice el cajero; los campos de abajo, no siempre.** Si buscas `[011] 000111`, mira la cabecera de encima para saber de qué cajero es.
- **El mismo STAN se repite en cajeros distintos.** La llave siempre es **cajero + STAN**.
- `NETWORK MTI=0800/0810` cada 30 min = echo test (latido). Es ruido.

---

## 2. Cómo funciona klogg (versión 22.06)

### 2.1 Las partes de la ventana

```
+-----------------------------------------------------------------------------------+
| File  Edit  View  Tools  Highlighters  Encoding  Favorites  Help    <- MENÚ        |
| C:\...\APP_ATM00101_20261118.log      14,38 KiB ... ISO-8859-1  Line 16/210        |  <- ruta y estado
+-----------------------------------------------------------------------------------+
| . 2026-11-18 07:55:20.000 [INFO ] [SYS ] Application started ...                  |
| . 2026-11-18 07:55:22.000 [INFO ] [XFS ] Devices opened ...      <- PANEL PRINCIPAL |
|   ...                                                              (todo el log)    |
+-----------------------------------------------------------------------------------+
| [Marks and matches v] [Aa] [.*] [..] [..] [lupa] [Predefined filters v] [_______]  |  <- BARRA DE BÚSQUEDA
+-----------------------------------------------------------------------------------+
|                                                                                   |  <- PANEL DE RESULTADOS
|   (aquí salen solo las líneas que coinciden con la búsqueda)                       |     (filtered view)
+-----------------------------------------------------------------------------------+
```

| Parte | Para qué sirve |
| --- | --- |
| Barra de ruta y estado | Qué archivo tienes abierto, su tamaño, la codificación detectada y en qué línea estás (`Line 16/210` = línea 16 de 210) |
| Panel principal | El log completo. Al hacer clic en un resultado de abajo, salta aquí a esa línea |
| Margen izquierdo (los puntitos) | Haz clic en el margen de una línea para **marcarla** (mark) como importante |
| Desplegable `Marks and matches` | Qué enseña el panel de abajo: solo marcas, solo coincidencias, o las dos cosas |
| `Aa` | Distinguir mayúsculas y minúsculas (match case). Si está activado, `warn` no encuentra `WARN` |
| `.*` | **Expresiones regulares (regex).** Actívalo para usar `\|`, `\d`, `[ ]`... |
| Los otros iconos | Pasa el ratón por encima de cada uno para ver su nombre (por ejemplo, búsqueda inversa: mostrar las líneas que NO coinciden) |
| Lupa | Lanza la búsqueda (o pulsa Enter en la caja de texto) |
| Caja de texto | Lo que buscas |
| Panel de resultados | Solo las líneas que coinciden, con su número de línea |

### 2.2 Lo básico, paso a paso

1. **Abrir un log:** `File → Open...` → elige el archivo. Si no ves los `.log`, en el tipo de archivo pon *All files*.
2. **Abrir varios:** repite `File → Open...`. Cada archivo queda en una pestaña arriba.
3. **Buscar:** haz clic en la caja de texto de abajo a la derecha → escribe → **Enter**.
4. **Ir a un resultado:** haz clic en una línea del panel de resultados y el panel principal salta a ella. Lee siempre unas líneas **antes y después**.
5. **Marcar una línea importante:** clic en el margen izquierdo de esa línea en el panel principal. Con `Marks and matches` seleccionado, las marcas también aparecen abajo: así te quedan juntas tus pruebas.
6. **Colores (highlighters):** menú `Highlighters` → abre la configuración → crea un conjunto → añade el patrón `ERROR` con fondo rojo, `WARN` con amarillo y `FATAL` con morado → acepta. Las líneas se colorean en todo el log.
7. **Ir a una línea concreta:** `Edit → Go to line...` (útil cuando un compañero te dice "mira la línea 137").
8. **Seguir un log en vivo:** `View → Follow file`. Se va mostrando lo nuevo mientras el cajero escribe. Lo usarás cuando pruebes en un cajero real del entorno de test.

### 2.3 Regex útiles para esta práctica (con `.*` activado)

| Quiero encontrar | Escribo |
| --- | --- |
| Todo lo que no es normal | `WARN\|ERROR\|FATAL` |
| Una operación por STAN en el log de aplicación | `STAN=000102` |
| Las cabeceras de mensajes de un cajero en el host | `ATM00103 MTI` |
| Solo los reversals | `MTI=04[23]0` |
| Respuestas del banco que no son 00 | `\[039\] (0[1-9]\|[1-9][0-9])` |
| Un STAN en el host (luego miro la cabecera) | `\[011\] 000102` |
| Números de tarjeta sin enmascarar | `4000\d{12}` o `PAN=\d{16}` |

Pistas de regex:
- `\|` significa "o".
- `\d` es cualquier dígito y `{12}` significa "12 veces".
- `[ ]` es un carácter de los que hay dentro.
- `\[` busca un corchete de verdad: sin la barra, el corchete tiene significado especial.

---

## 3. Ejemplo completo: seguir una operación por los 3 logs

Operación normal: **ATM00101, 08:47, STAN 000102**. Sigue los pasos en klogg tú mismo.

**Paso 1 – EJ (qué pasó):** abre `EJ_ATM00101_20261118.txt` y busca `STAN 000102`.
Resultado: retirada de 100,00 aprobada (00, AUTH 391369), salieron 2 x 50, el cliente los cogió y se imprimió el ticket.

**Paso 2 – Log de aplicación (cómo pasó):** abre `APP_ATM00101_20261118.log` y busca `08:47`.

```
08:47:00.000 [INFO ] [IDC ] Card inserted, chip read OK, PAN=400012******0003
08:47:06.000 [INFO ] [PIN ] PIN block captured by EPP
08:47:10.000 [INFO ] [HOST] Sending 0200 STAN=000102 amount=10000
08:47:10.728 [INFO ] [HOST] Received 0210 STAN=000102 DE39=00      <- el banco tardó 728 ms
08:47:10.758 [INFO ] [CDM ] Dispense command: 2x50 0x20             <- orden al dispensador
08:47:15.728 [INFO ] [CDM ] Notes presented: 2 x 50
08:47:18.728 [INFO ] [CDM ] Notes taken by customer
08:47:20.728 [INFO ] [TRX ] Transaction completed STAN=000102
```

Ningún WARN ni ERROR, y la orden (2x50) coincide con lo entregado (2 x 50).

**Paso 3 – Host (qué se dijo con el banco):** abre `HOST_ISO8583_20261118.log` y busca `\[011\] 000102` con regex.
Salen varias coincidencias. Haz clic en cada una y mira la cabecera de encima hasta encontrar la de `ATM00101`:
- `>>> SEND ATM00101 MTI=0200` con DE3 `011000` (retirada) y DE4 `000000010000` (100,00).
- `<<< RECV ATM00101 MTI=0210` con DE38 `391369` y DE39 `00`.

**Paso 4 – Conclusión:**

| Pregunta | EJ | APP | HOST | ¿Coincide? |
| --- | --- | --- | --- | --- |
| Importe pedido | 100.00 | amount=10000 | DE4 000000010000 | Sí |
| Respuesta | 00 AUTH 391369 | DE39=00 | DE39 00, DE38 391369 | Sí |
| Billetes | 2 x 50 | 2x50 / 2 x 50 | No aplica | Sí |
| ¿Hace falta reversal? | No | No | No hay 0420 | Correcto |

Veredicto: **operación correcta según RQ-01**. Así se investiga cada una de las 6 situaciones del enunciado: el mismo método, pero allí algo no coincidirá.

---

## 4. Método en 6 pasos (resumen para tener a mano)

1. **Filtra** `WARN|ERROR|FATAL` en el log de aplicación.
2. **Apunta** la hora y el STAN de cada línea sospechosa.
3. **EJ:** busca ese STAN y lee el bloque completo.
4. **Host:** busca cajero + STAN y comprueba la secuencia de MTI (0200 → 0210 → ¿0420 → 0430?).
5. **Compara** con el requisito: ¿es lo que debía pasar?
6. **Evidencia:** archivo, hora, STAN y las líneas clave, con el PAN enmascarado.
