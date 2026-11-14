# Práctica: investigar logs de cajeros

**Datos 100 % ficticios.** Cajeros genéricos ATM00101, ATM00102 y ATM00103 de un banco inventado, el día 18/11/2026. Las tarjetas son de test (BIN 400012).

## Qué hay en la carpeta `logs`

| Archivo | Qué es | Cómo está ordenado |
| --- | --- | --- |
| `EJ_ATM0010x_20261118.txt` | Electronic Journal (diario electrónico), uno por cajero | Un bloque por operación, separado por `=====` |
| `APP_ATM0010x_20261118.log` | Application log (log de aplicación), uno por cajero | Una línea por evento: `fecha hora [NIVEL] [COMPONENTE] mensaje` |
| `HOST_ISO8583_20261118.log` | Log del host con los mensajes ISO 8583 de los 3 cajeros mezclados | Un mensaje por bloque: `>>> SEND` sale del cajero, `<<< RECV` llega al cajero |

Notas:
- La hora de cada línea es la hora local (Madrid). El campo `[007]` va en GMT, una hora menos.
- `NETWORK MTI=0800/0810` son echo tests (latidos) cada 30 minutos: es ruido, no son operaciones.
- Cada cajero tiene su propio contador de STAN, así que **el mismo STAN puede aparecer en dos cajeros**.

## Requisitos (tu oráculo)

| ID | Requisito |
| --- | --- |
| RQ-01 | Retirada aprobada: 0200 → 0210 con DE39 00, se entregan los billetes y se imprime el ticket. |
| RQ-02 | Si el host no responde en 30 s: no se dispensa y se envía un 0420 por el importe total. |
| RQ-03 | Si el host aprueba (00) pero el dispensador no entrega todo, se envía un 0420. En el DE95 va el importe realmente entregado. |
| RQ-04 | Si el cliente no retira los billetes en 30 s, el cajero los retrae (retract) y envía un 0420 por el importe total. |
| RQ-05 | Si el host responde 75 (intentos de PIN agotados), el cajero retiene la tarjeta (CARD CAPTURED). |
| RQ-06 | El PAN aparece siempre enmascarado (`400012******NNNN`) en todos los logs. |

## Parte 1 – Calentamiento (para aprender a moverte)

1. ¿Cuántas operaciones (`TRX SEQ`) hay en el EJ de ATM00102?
2. En el log del host busca `000111`. ¿Cuántas operaciones distintas encuentras? ¿Por qué hay más de una?
3. Encuentra la consulta de saldo. ¿En qué cajero y a qué hora fue? ¿Cuál es el saldo disponible y cuál el contable? Pista: DE3 y DE54.
4. Encuentra una operación rechazada con 51 y otra con 61. ¿Qué significa cada código? ¿El cajero hizo lo correcto?

## Parte 2 – Las 6 situaciones escondidas

En el día hay **6 situaciones especiales**. Algunas son bugs y otras son comportamiento correcto ante un fallo. Para cada una apunta:

| Cajero | Hora | STAN | Qué pasó | Secuencia de MTI que viste | ¿Bug o correcto? | Requisito |
| --- | --- | --- | --- | --- | --- | --- |
| | | | | | | |

Cómo empezar (método del doc):
1. Abre los 3 `APP_*.log` y filtra `WARN|ERROR|FATAL` (activa Regex).
2. Por cada línea sospechosa, apunta la hora y el STAN.
3. Ve al EJ de ese cajero a esa hora.
4. Ve al log del host y busca **cajero + STAN** (no solo el STAN).
5. Compara con la tabla de requisitos.

Una de las 6 situaciones no sale filtrando WARN/ERROR: tendrás que buscarla de otra forma. Mira el RQ-06.

## Parte 3 – El cierre del día

Al final de cada EJ está `TERMINAL TOTALS` con el total dispensado.

1. Para cada cajero, calcula el **neto del host**: suma de las retiradas aprobadas (0210 con 00), menos lo devuelto por reversals de operaciones que el host había aprobado (DE4 menos DE95 si viene).
2. Compáralo con `TOTAL DISPENSED` del EJ.
3. ¿Qué cajeros cuadran y cuáles descuadran? ¿Por cuánto? ¿Qué situación de la Parte 2 lo explica?

## Parte 4 – Escribe los bugs

Por cada bug, un reporte con esta plantilla:

```
Título: [Cajero] [Funcionalidad] - qué falla, en pocas palabras
Entorno: ATM00xxx, 18/11/2026, versión app 4.2.7
Precondiciones:
Pasos para reproducir:
Resultado esperado: (cita el requisito y la secuencia de MTI esperada)
Resultado obtenido: (las líneas clave del log)
Evidencia: archivo + hora + STAN (PAN siempre enmascarado)
Severidad / Prioridad:
```

Cuando termines, compara con las soluciones (te las paso cuando me envíes tus respuestas).
