# Análisis de logs de cajeros (EJ, aplicación e ISO 8583)

Práctica de investigación de incidencias en cajeros automáticos a partir de sus logs. Todo es **ficticio**: tres cajeros genéricos (ATM00101–ATM00103) durante un día completo.

## Qué demuestra

- Leer y **correlacionar tres fuentes** de una misma operación: Electronic Journal (EJ), log de aplicación y mensajes ISO 8583 del host.
- Usar la llave correcta (**cajero + STAN**), porque el STAN se repite entre cajeros.
- Distinguir **bug** de **comportamiento correcto ante un fallo** (timeout, atasco) usando los requisitos como oráculo.
- Detectar un **dato sensible** (PAN sin enmascarar) en un log.
- Comprobar el **cierre del día**: total del EJ frente al neto del host.
- Escribir **bug reports** con evidencias de log.

## Contenido

| Archivo / carpeta | Qué es |
| --- | --- |
| [ENUNCIADO.md](ENUNCIADO.md) | Requisitos y ejercicios (4 partes) |
| [GUIA_LECTURA_LOGS.md](GUIA_LECTURA_LOGS.md) | Cómo es cada log, cómo usar klogg y un ejemplo completo paso a paso |
| [logs/](logs/) | 3 EJ, 3 logs de aplicación y 1 log de host ISO 8583 |
| [generador/generar_logs.py](generador/generar_logs.py) | Script en Python que genera los logs (con semilla fija: siempre el mismo resultado) |

## Herramientas

- [klogg](https://github.com/variar/klogg): visor de logs gratuito con búsqueda por expresiones regulares (regex).
- VS Code / Notepad++ como alternativa.
- Python 3 (opcional), solo para regenerar los logs o crear escenarios nuevos.

## Regenerar los logs

```
cd generador
python generar_logs.py
```

## Estado

- [x] Logs y enunciado
- [x] Guía de lectura
- [ ] Respuestas y bug reports propios
- [ ] Nuevos escenarios (ingreso de efectivo, tarjeta retenida correcta, doble reversal)
