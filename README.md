# Ejercicios de SQL Server

Colección de consultas para practicar análisis de datos con T-SQL. El archivo principal crea una base de práctica de mensajería y paquetería con datos sintéticos y después presenta 49 ejercicios resueltos, desde consultas básicas hasta vistas y procedimientos almacenados.

## Requisitos

- SQL Server **2016 SP1 o posterior**. El script utiliza `CREATE OR ALTER`, disponible desde SQL Server 2016 SP1.
- SQL Server Management Studio (SSMS) o Azure Data Studio para ejecutar el archivo. El script utiliza `GO`, un separador de lotes que reconocen estas herramientas y no forma parte del lenguaje T-SQL que se envía directamente desde una aplicación.
- Permisos para crear tablas, vistas, índices y procedimientos almacenados en la base de datos seleccionada.

## Cómo ejecutar los ejercicios

1. Crea o selecciona una **base de datos de práctica** en SQL Server. El archivo no crea la base de datos; debes seleccionarla antes de ejecutar el script.
2. Abre [`SQL ejercicios.sql`](./SQL%20ejercicios.sql) en SSMS o Azure Data Studio y conéctate al servidor.
3. Confirma que la base de datos seleccionada es la correcta y ejecuta el archivo completo.
4. Revisa los resultados en las cuadrículas de resultados. Las consultas y ejemplos de uso están incluidos debajo de cada enunciado `P1` a `P49`.

Ejecuta el archivo completo en una base de datos nueva para crear el esquema, cargar los datos y definir todos los objetos que necesitan los ejercicios. Para probar una consulta concreta más adelante, puedes seleccionar su bloque y ejecutarlo de nuevo, siempre que la preparación previa correspondiente ya se haya ejecutado en esa sesión/base de datos.

> **Atención:** la sección inicial de limpieza elimina las tablas del esquema `logistica` y luego intenta eliminar ese esquema. Usa una base de datos dedicada a esta práctica y no una base con datos u objetos que quieras conservar. Para una repetición desde cero, crea una base de datos de práctica nueva.

## Qué incluye el conjunto de datos

El script crea el esquema `logistica` y genera datos sintéticos reproducibles para una empresa ficticia:

- Ciudades, sucursales, clientes, mensajeros y servicios.
- 2.000 envíos con fechas de creación entre enero de 2025 y agosto de 2026.
- Eventos de seguimiento, novedades y facturas para practicar análisis operativo y de cartera.

Los valores generados se basan en `CHECKSUM`, por lo que los datos de origen se mantienen deterministas entre ejecuciones. Algunos resultados que comparan fechas con la fecha actual —por ejemplo, cartera vencida— pueden cambiar con el paso del tiempo.

## Mapa de ejercicios

| Bloque | Temas |
| --- | --- |
| P1–P4 · Básico | Conteos y porcentajes, ingresos mensuales, clientes principales y promedios por servicio. |
| P5–P10 · Intermedio | SLA, rutas y tiempos de entrega, anti-joins, novedades, cartera, y comparación de envíos contra entrega. |
| P11–P36 · Avanzado | Funciones de ventana, tendencias y promedios móviles, Pareto, retención y cohortes, percentiles, valores atípicos, cartera por antigüedad, y segmentación RFM. |
| P37–P42 · Vistas y tablas temporales | Vistas de detalle, KPIs y cartera; tablas temporales y variables de tabla para análisis. |
| P43–P49 · Procedimientos almacenados | Reportes parametrizados, filtros opcionales, parámetros `OUTPUT`, transacciones y agrupación dinámica con validación de opciones. |

Cada ejercicio está identificado en el archivo SQL mediante un comentario `P#` inmediatamente antes de su solución. Algunos incluyen variantes o bloques `Uso` para mostrar cómo llamar al procedimiento o consultar la vista.

## Objetos creados

Las tablas y objetos se agrupan bajo el esquema `logistica`. Entre los objetos que se definen en los últimos bloques están:

- Vistas: `vw_envios_detalle`, `vw_kpi_mensual` y `vw_cartera_cliente`.
- Procedimientos: `sp_kpi_servicio`, `sp_envios_cliente`, `sp_top_clientes`, `sp_cumplimiento_sla`, `sp_registrar_novedad`, `sp_reporte_clientes_riesgo` y `sp_reporte_dinamico`.

El bloque final de limpieza opcional del archivo está comentado; descoméntalo solo si quieres eliminar los objetos que enumera.
