-- =====================================================================
-- Base de práctica: logística de mensajería y paquetería
-- Motor: SQL Server 2016+ (T-SQL)  |  Datos 100% sintéticos, solo para práctica
-- Ejecutar el script completo en una base de datos de pruebas (SSMS / Azure Data Studio).
-- Los datos "aleatorios" son deterministas (basados en CHECKSUM), por lo que son reproducibles.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 0. LIMPIEZA
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS logistica.facturas;
DROP TABLE IF EXISTS logistica.novedades;
DROP TABLE IF EXISTS logistica.seguimiento_envios;
DROP TABLE IF EXISTS logistica.envios;
DROP TABLE IF EXISTS logistica.mensajeros;
DROP TABLE IF EXISTS logistica.clientes;
DROP TABLE IF EXISTS logistica.sucursales;
DROP TABLE IF EXISTS logistica.servicios;
DROP TABLE IF EXISTS logistica.ciudades;
DROP SCHEMA IF EXISTS logistica;
GO
CREATE SCHEMA logistica;
GO

-- ---------------------------------------------------------------------
-- 1. ESQUEMA
-- ---------------------------------------------------------------------
CREATE TABLE logistica.ciudades (
    id_ciudad     INT PRIMARY KEY,
    nombre        NVARCHAR(60) NOT NULL,
    departamento  NVARCHAR(60) NOT NULL,
    region        NVARCHAR(30) NOT NULL
);

CREATE TABLE logistica.sucursales (
    id_sucursal INT PRIMARY KEY,
    nombre      NVARCHAR(80) NOT NULL,
    id_ciudad   INT NOT NULL REFERENCES logistica.ciudades(id_ciudad)
);

CREATE TABLE logistica.clientes (
    id_cliente     INT PRIMARY KEY,
    razon_social   NVARCHAR(100) NOT NULL,
    tipo_cliente   NVARCHAR(20) NOT NULL CHECK (tipo_cliente IN (N'Empresarial', N'Persona')),
    segmento       NVARCHAR(20) NOT NULL CHECK (segmento IN (N'Ecommerce', N'Retail', N'Industrial', N'Servicios', N'Personal')),
    id_ciudad      INT NOT NULL REFERENCES logistica.ciudades(id_ciudad),
    fecha_registro DATE NOT NULL
);

CREATE TABLE logistica.mensajeros (
    id_mensajero  INT PRIMARY KEY,
    nombre        NVARCHAR(80) NOT NULL,
    id_sucursal   INT NOT NULL REFERENCES logistica.sucursales(id_sucursal),
    fecha_ingreso DATE NOT NULL,
    activo        BIT NOT NULL DEFAULT 1
);

CREATE TABLE logistica.servicios (
    id_servicio  INT PRIMARY KEY,
    nombre       NVARCHAR(40) NOT NULL,
    tarifa_base  DECIMAL(12,2) NOT NULL,
    dias_promesa INT NOT NULL            -- SLA: días máximos de entrega
);

CREATE TABLE logistica.envios (
    id_envio          BIGINT IDENTITY(1,1) PRIMARY KEY,
    guia              VARCHAR(15) NOT NULL UNIQUE,
    id_cliente        INT NOT NULL REFERENCES logistica.clientes(id_cliente),
    id_servicio       INT NOT NULL REFERENCES logistica.servicios(id_servicio),
    id_ciudad_origen  INT NOT NULL REFERENCES logistica.ciudades(id_ciudad),
    id_ciudad_destino INT NOT NULL REFERENCES logistica.ciudades(id_ciudad),
    id_mensajero      INT NULL REFERENCES logistica.mensajeros(id_mensajero),
    fecha_creacion    DATETIME2(0) NOT NULL,
    fecha_entrega     DATETIME2(0) NULL,   -- NULL si no ha sido entregado
    peso_kg           DECIMAL(8,2) NOT NULL,
    valor_declarado   DECIMAL(14,2) NOT NULL,
    valor_flete       DECIMAL(12,2) NOT NULL,
    contra_entrega    BIT NOT NULL,
    estado            NVARCHAR(20) NOT NULL
        CHECK (estado IN (N'Entregado', N'En tránsito', N'Devuelto', N'Con novedad'))
);

CREATE TABLE logistica.seguimiento_envios (
    id_evento    BIGINT IDENTITY(1,1) PRIMARY KEY,
    id_envio     BIGINT NOT NULL REFERENCES logistica.envios(id_envio),
    estado       NVARCHAR(20) NOT NULL,
    fecha_evento DATETIME2(0) NOT NULL
);

CREATE TABLE logistica.novedades (
    id_novedad    BIGINT IDENTITY(1,1) PRIMARY KEY,
    id_envio      BIGINT NOT NULL REFERENCES logistica.envios(id_envio),
    tipo_novedad  NVARCHAR(40) NOT NULL,
    fecha_novedad DATETIME2(0) NOT NULL,
    resuelta      BIT NOT NULL
);

CREATE TABLE logistica.facturas (
    id_factura        BIGINT IDENTITY(1,1) PRIMARY KEY,
    id_cliente        INT NOT NULL REFERENCES logistica.clientes(id_cliente),
    fecha_emision     DATE NOT NULL,
    fecha_vencimiento DATE NOT NULL,
    valor_total       DECIMAL(14,2) NOT NULL,
    fecha_pago        DATE NULL              -- NULL si no ha sido pagada
);

CREATE INDEX idx_envios_cliente  ON logistica.envios(id_cliente);
CREATE INDEX idx_envios_fecha    ON logistica.envios(fecha_creacion);
CREATE INDEX idx_seguimiento_env ON logistica.seguimiento_envios(id_envio);
GO

-- ---------------------------------------------------------------------
-- 2. DATOS DE REFERENCIA
-- ---------------------------------------------------------------------
-- Tabla auxiliar de números (reemplaza generate_series)
DROP TABLE IF EXISTS #nums;
SELECT TOP (2000) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS g
INTO #nums
FROM sys.all_objects a CROSS JOIN sys.all_objects b;

INSERT INTO logistica.ciudades VALUES
(1,  N'Bogotá',        N'Cundinamarca',      N'Centro'),
(2,  N'Medellín',      N'Antioquia',         N'Occidente'),
(3,  N'Cali',          N'Valle del Cauca',   N'Pacífico'),
(4,  N'Barranquilla',  N'Atlántico',         N'Caribe'),
(5,  N'Cartagena',     N'Bolívar',           N'Caribe'),
(6,  N'Bucaramanga',   N'Santander',         N'Oriente'),
(7,  N'Pereira',       N'Risaralda',         N'Eje Cafetero'),
(8,  N'Manizales',     N'Caldas',            N'Eje Cafetero'),
(9,  N'Cúcuta',        N'Norte de Santander',N'Oriente'),
(10, N'Villavicencio', N'Meta',              N'Orinoquía');

INSERT INTO logistica.sucursales VALUES
(1, N'Bogotá Norte', 1), (2, N'Bogotá Sur', 1), (3, N'Medellín Centro', 2),
(4, N'Cali Principal', 3), (5, N'Barranquilla Principal', 4), (6, N'Cartagena Principal', 5),
(7, N'Bucaramanga Principal', 6), (8, N'Pereira Principal', 7), (9, N'Cúcuta Principal', 9),
(10, N'Villavicencio Principal', 10);

INSERT INTO logistica.servicios VALUES
(1, N'Normal', 8000, 5),
(2, N'Express', 15000, 2),
(3, N'Mercancía Pesada', 25000, 7);

INSERT INTO logistica.mensajeros (id_mensajero, nombre, id_sucursal, fecha_ingreso, activo)
SELECT g,
       CONCAT(N'Mensajero ', g),
       1 + (g % 10),
       DATEADD(DAY, (g * 97) % 1800, CAST('2020-01-01' AS DATE)),
       CASE WHEN g % 11 <> 0 THEN 1 ELSE 0 END
FROM #nums
WHERE g <= 12;

INSERT INTO logistica.clientes (id_cliente, razon_social, tipo_cliente, segmento, id_ciudad, fecha_registro)
SELECT g,
       CASE WHEN g <= 40 THEN CONCAT(N'Empresa ', g, N' SAS') ELSE CONCAT(N'Persona ', g) END,
       CASE WHEN g <= 40 THEN N'Empresarial' ELSE N'Persona' END,
       CASE WHEN g > 40 THEN N'Personal'
            ELSE CHOOSE(1 + (g % 4), N'Ecommerce', N'Retail', N'Industrial', N'Servicios') END,
       1 + (g % 10),
       DATEADD(DAY, (g * 53) % 900, CAST('2022-01-01' AS DATE))
FROM #nums
WHERE g <= 50;

-- ---------------------------------------------------------------------
-- 3. ENVÍOS (2.000 registros, ene-2025 a ago-2026)
-- ---------------------------------------------------------------------
;WITH base AS (
    SELECT n.g,
           1 + CAST(FLOOR(r.a * 50) AS INT)                          AS id_cliente,
           CHOOSE(1 + CAST(FLOOR(r.b * 6) AS INT), 1, 1, 1, 2, 2, 3) AS id_servicio,
           1 + CAST(FLOOR(r.c * 10) AS INT)                          AS origen,
           1 + CAST(FLOOR(r.d * 9) AS INT)                           AS salto,
           1 + CAST(FLOOR(r.e * 12) AS INT)                          AS id_mensajero,
           DATEADD(HOUR, 6 + CAST(FLOOR(r.g2 * 12) AS INT),
                   DATEADD(DAY, CAST(FLOOR(r.f * 600) AS INT),
                           CAST('2025-01-01' AS DATETIME2(0))))      AS f_creacion,
           CAST(0.5 + r.h * 30 AS DECIMAL(8,2))                      AS peso,
           ROUND(20000 + r.i * 2000000, -2)                          AS declarado,
           CASE WHEN r.j < 0.25 THEN 1 ELSE 0 END                    AS cod,
           r.k                                                       AS r1,
           r.l                                                       AS r2
    FROM #nums n
    CROSS APPLY (SELECT
        a  = ABS(CAST(CHECKSUM(CONCAT(n.g, 'a')) AS BIGINT)) % 1000000 / 1000000.0,
        b  = ABS(CAST(CHECKSUM(CONCAT(n.g, 'b')) AS BIGINT)) % 1000000 / 1000000.0,
        c  = ABS(CAST(CHECKSUM(CONCAT(n.g, 'c')) AS BIGINT)) % 1000000 / 1000000.0,
        d  = ABS(CAST(CHECKSUM(CONCAT(n.g, 'd')) AS BIGINT)) % 1000000 / 1000000.0,
        e  = ABS(CAST(CHECKSUM(CONCAT(n.g, 'e')) AS BIGINT)) % 1000000 / 1000000.0,
        f  = ABS(CAST(CHECKSUM(CONCAT(n.g, 'f')) AS BIGINT)) % 1000000 / 1000000.0,
        g2 = ABS(CAST(CHECKSUM(CONCAT(n.g, 'g')) AS BIGINT)) % 1000000 / 1000000.0,
        h  = ABS(CAST(CHECKSUM(CONCAT(n.g, 'h')) AS BIGINT)) % 1000000 / 1000000.0,
        i  = ABS(CAST(CHECKSUM(CONCAT(n.g, 'i')) AS BIGINT)) % 1000000 / 1000000.0,
        j  = ABS(CAST(CHECKSUM(CONCAT(n.g, 'j')) AS BIGINT)) % 1000000 / 1000000.0,
        k  = ABS(CAST(CHECKSUM(CONCAT(n.g, 'k')) AS BIGINT)) % 1000000 / 1000000.0,
        l  = ABS(CAST(CHECKSUM(CONCAT(n.g, 'l')) AS BIGINT)) % 1000000 / 1000000.0
    ) r
    WHERE n.g <= 2000
)
INSERT INTO logistica.envios
    (guia, id_cliente, id_servicio, id_ciudad_origen, id_ciudad_destino, id_mensajero,
     fecha_creacion, fecha_entrega, peso_kg, valor_declarado, valor_flete, contra_entrega, estado)
SELECT CONCAT('CM', RIGHT(CONCAT('000000000', b.g), 9)),
       b.id_cliente,
       b.id_servicio,
       b.origen,
       1 + ((b.origen - 1 + b.salto) % 10),            -- destino siempre distinto al origen
       b.id_mensajero,
       b.f_creacion,
       CASE WHEN b.r1 < 0.85
            THEN DATEADD(DAY, 1 + CAST(FLOOR(b.r2 * 6) AS INT), b.f_creacion) END,
       b.peso,
       b.declarado,
       ROUND(s.tarifa_base + b.peso * 1200, -1),
       b.cod,
       CASE WHEN b.r1 < 0.85 THEN N'Entregado'
            WHEN b.r1 < 0.92 THEN N'En tránsito'
            WHEN b.r1 < 0.97 THEN N'Devuelto'
            ELSE N'Con novedad' END
FROM base b
JOIN logistica.servicios s ON s.id_servicio = b.id_servicio;

-- Seguimiento
INSERT INTO logistica.seguimiento_envios (id_envio, estado, fecha_evento)
SELECT id_envio, N'Creado', fecha_creacion FROM logistica.envios
UNION ALL
SELECT id_envio, N'En tránsito', DATEADD(DAY, 1, fecha_creacion) FROM logistica.envios
UNION ALL
SELECT id_envio, N'Entregado', fecha_entrega FROM logistica.envios WHERE fecha_entrega IS NOT NULL
UNION ALL
SELECT id_envio, N'Devuelto', DATEADD(DAY, 4, fecha_creacion) FROM logistica.envios WHERE estado = N'Devuelto';

-- Novedades (~10% de los envíos)
INSERT INTO logistica.novedades (id_envio, tipo_novedad, fecha_novedad, resuelta)
SELECT e.id_envio,
       CHOOSE(1 + CAST(h.x % 5 AS INT), N'Dirección incorrecta', N'Destinatario ausente',
              N'Rechazado', N'Zona de difícil acceso', N'Mercancía averiada'),
       DATEADD(DAY, 2, e.fecha_creacion),
       CASE WHEN h.y < 0.6 THEN 1 ELSE 0 END
FROM logistica.envios e
CROSS APPLY (SELECT
    p = ABS(CAST(CHECKSUM(CONCAT(e.id_envio, 'p')) AS BIGINT)) % 1000000 / 1000000.0,
    x = ABS(CAST(CHECKSUM(CONCAT(e.id_envio, 'q')) AS BIGINT)),
    y = ABS(CAST(CHECKSUM(CONCAT(e.id_envio, 'r')) AS BIGINT)) % 1000000 / 1000000.0
) h
WHERE h.p < 0.10;

-- Facturas
INSERT INTO logistica.facturas (id_cliente, fecha_emision, fecha_vencimiento, valor_total, fecha_pago)
SELECT t.c,
       t.f,
       DATEADD(DAY, 30, t.f),
       ROUND(500000 + t.v * 20000000, -3),
       CASE WHEN t.p < 0.8 THEN DATEADD(DAY, CAST(FLOOR(t.q * 45) AS INT), t.f) END
FROM (
    SELECT 1 + CAST(FLOOR(h.a * 40) AS INT) AS c,
           DATEADD(DAY, CAST(FLOOR(h.b * 600) AS INT), CAST('2025-01-01' AS DATE)) AS f,
           h.v, h.p, h.q
    FROM #nums n
    CROSS APPLY (SELECT
        a = ABS(CAST(CHECKSUM(CONCAT(n.g, 'fa')) AS BIGINT)) % 1000000 / 1000000.0,
        b = ABS(CAST(CHECKSUM(CONCAT(n.g, 'fb')) AS BIGINT)) % 1000000 / 1000000.0,
        v = ABS(CAST(CHECKSUM(CONCAT(n.g, 'fv')) AS BIGINT)) % 1000000 / 1000000.0,
        p = ABS(CAST(CHECKSUM(CONCAT(n.g, 'fp')) AS BIGINT)) % 1000000 / 1000000.0,
        q = ABS(CAST(CHECKSUM(CONCAT(n.g, 'fq')) AS BIGINT)) % 1000000 / 1000000.0
    ) h
    WHERE n.g <= 300
) t;

DROP TABLE #nums;
GO

-- Verificación rápida
SELECT 'envios' AS tabla, COUNT(*) AS filas FROM logistica.envios
UNION ALL SELECT 'seguimiento', COUNT(*) FROM logistica.seguimiento_envios
UNION ALL SELECT 'novedades',   COUNT(*) FROM logistica.novedades
UNION ALL SELECT 'facturas',    COUNT(*) FROM logistica.facturas;
GO


-- =====================================================================
-- 4. PREGUNTAS DE PRÁCTICA CON SOLUCIÓN
-- =====================================================================

-- ---------- NIVEL BÁSICO ----------

-- P1. ¿Cuántos envíos hay por estado y qué porcentaje representa cada uno?
SELECT estado,
       COUNT(*) AS total,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS porcentaje
FROM logistica.envios
GROUP BY estado
ORDER BY total DESC;

-- P2. Ingresos por flete por mes (solo envíos no devueltos).
SELECT m.mes,
       COUNT(*)         AS envios,
       SUM(e.valor_flete) AS ingreso_flete
FROM logistica.envios e
CROSS APPLY (SELECT DATEFROMPARTS(YEAR(e.fecha_creacion), MONTH(e.fecha_creacion), 1) AS mes) m
WHERE e.estado <> N'Devuelto'
GROUP BY m.mes
ORDER BY m.mes;

-- Opcion 2
WITH EnviosFiltrados AS (
    SELECT 
        valor_flete,
        DATEFROMPARTS(YEAR(fecha_creacion), MONTH(fecha_creacion), 1) AS mes
    FROM logistica.envios
    WHERE estado <> N'Devuelto'
)
SELECT 
    mes,
    COUNT(*) AS envios,
    SUM(valor_flete) AS ingreso_flete
FROM EnviosFiltrados
GROUP BY mes
ORDER BY mes;

-- P3. Top 10 clientes por ingreso de flete, con su ciudad.
SELECT TOP (10)
       c.razon_social, ci.nombre AS ciudad,
       COUNT(*) AS envios, SUM(e.valor_flete) AS ingreso
FROM logistica.envios e
JOIN logistica.clientes c  ON c.id_cliente = e.id_cliente
JOIN logistica.ciudades ci ON ci.id_ciudad = c.id_ciudad
GROUP BY c.razon_social, ci.nombre
ORDER BY ingreso DESC;

-- P4. Peso promedio y flete promedio por tipo de servicio.
SELECT s.nombre,
       ROUND(AVG(e.peso_kg), 2)     AS peso_prom,
       ROUND(AVG(e.valor_flete), 0) AS flete_prom
FROM logistica.envios e
JOIN logistica.servicios s ON s.id_servicio = e.id_servicio
GROUP BY s.nombre;

-- ---------- NIVEL INTERMEDIO ----------

-- P5. Cumplimiento del SLA (% de entregas dentro de los días prometidos) por servicio.
SELECT s.nombre AS servicio,
       COUNT(*) AS entregados,
       ROUND(100.0 * SUM(CASE WHEN DATEDIFF(DAY, e.fecha_creacion, e.fecha_entrega) <= s.dias_promesa
                              THEN 1 ELSE 0 END) / COUNT(*), 2) AS pct_cumplimiento
FROM logistica.envios e
JOIN logistica.servicios s ON s.id_servicio = e.id_servicio
WHERE e.estado = N'Entregado'
GROUP BY s.nombre
ORDER BY pct_cumplimiento DESC;

-- P6. Tiempo promedio de entrega (días) por ruta origen-destino; solo rutas con >= 20 envíos entregados.
--     Nota: AVG sobre enteros trunca en SQL Server, por eso se convierte a DECIMAL.
SELECT TOP (10)
       co.nombre AS origen, cd.nombre AS destino,
       COUNT(*) AS envios,
       ROUND(AVG(CAST(DATEDIFF(DAY, e.fecha_creacion, e.fecha_entrega) AS DECIMAL(10,2))), 2) AS dias_prom
FROM logistica.envios e
JOIN logistica.ciudades co ON co.id_ciudad = e.id_ciudad_origen
JOIN logistica.ciudades cd ON cd.id_ciudad = e.id_ciudad_destino
WHERE e.estado = N'Entregado'
GROUP BY co.nombre, cd.nombre
HAVING COUNT(*) >= 20
ORDER BY dias_prom DESC;

-- P7. Clientes registrados que NO tienen envíos (anti-join).
SELECT c.id_cliente, c.razon_social
FROM logistica.clientes c
LEFT JOIN logistica.envios e ON e.id_cliente = c.id_cliente
WHERE e.id_envio IS NULL;

-- P8. Tasa de novedades por tipo y % de resolución.
SELECT tipo_novedad,
       COUNT(*) AS total,
       ROUND(100.0 * SUM(CAST(resuelta AS INT)) / COUNT(*), 1) AS pct_resueltas
FROM logistica.novedades
GROUP BY tipo_novedad
ORDER BY total DESC;

-- P9. Cartera vencida: facturas sin pago con fecha de vencimiento anterior a hoy, por cliente.
SELECT c.razon_social,
       COUNT(*) AS facturas_vencidas,
       SUM(f.valor_total) AS valor_vencido,
       MAX(DATEDIFF(DAY, f.fecha_vencimiento, CAST(GETDATE() AS DATE))) AS max_dias_mora
FROM logistica.facturas f
JOIN logistica.clientes c ON c.id_cliente = f.id_cliente
WHERE f.fecha_pago IS NULL
  AND f.fecha_vencimiento < CAST(GETDATE() AS DATE)
GROUP BY c.razon_social
ORDER BY valor_vencido DESC;

-- P10. Envíos contra entrega vs. no contra entrega: volumen, % devueltos y flete promedio.
SELECT contra_entrega,
       COUNT(*) AS envios,
       ROUND(100.0 * SUM(CASE WHEN estado = N'Devuelto' THEN 1 ELSE 0 END) / COUNT(*), 2) AS pct_devueltos,
       ROUND(AVG(valor_flete), 0) AS flete_prom
FROM logistica.envios
GROUP BY contra_entrega;

-- ---------- NIVEL AVANZADO ----------

-- P11. Ranking de mensajeros por entregas dentro de cada sucursal (window function).
SELECT *
FROM (
    SELECT su.nombre AS sucursal, m.nombre AS mensajero,
           COUNT(*) AS entregas,
           RANK() OVER (PARTITION BY su.id_sucursal ORDER BY COUNT(*) DESC) AS posicion
    FROM logistica.envios e
    JOIN logistica.mensajeros m  ON m.id_mensajero = e.id_mensajero
    JOIN logistica.sucursales su ON su.id_sucursal = m.id_sucursal
    WHERE e.estado = N'Entregado'
    GROUP BY su.id_sucursal, su.nombre, m.nombre
) t
WHERE posicion <= 3
ORDER BY sucursal, posicion;

-- OPCION 2
WITH RankingMensajeros AS (
    SELECT
        su.nombre AS sucursal,
        m.nombre AS mensajero,
        COUNT(*) AS entregas,
        ROW_NUMBER() OVER (
            PARTITION BY su.id_sucursal
            ORDER BY COUNT(*) DESC
        ) AS posicion
    FROM logistica.envios e
    JOIN logistica.mensajeros m
        ON m.id_mensajero = e.id_mensajero
    JOIN logistica.sucursales su
        ON su.id_sucursal = m.id_sucursal
    WHERE e.estado = N'Entregado'
    GROUP BY
        su.id_sucursal,
        su.nombre,
        m.nombre
)
SELECT
    sucursal,
    mensajero,
    entregas,
    posicion
FROM RankingMensajeros
WHERE posicion <= 3
ORDER BY sucursal, posicion;

-- P12. Crecimiento mensual de envíos (variación % vs. mes anterior) con LAG
WITH mensual AS (
    SELECT DATEFROMPARTS(YEAR(fecha_creacion), MONTH(fecha_creacion), 1) AS mes,
           COUNT(*) AS envios
    FROM logistica.envios
    GROUP BY DATEFROMPARTS(YEAR(fecha_creacion), MONTH(fecha_creacion), 1)
)
SELECT mes, envios,
       LAG(envios) OVER (ORDER BY mes) AS mes_anterior,
       ROUND(100.0 * (envios - LAG(envios) OVER (ORDER BY mes))
             / NULLIF(LAG(envios) OVER (ORDER BY mes), 0), 2) AS var_pct
FROM mensual
ORDER BY mes;

-- OPCION 2
WITH mensual AS (
    SELECT DATEFROMPARTS(YEAR(fecha_creacion), MONTH(fecha_creacion), 1) AS mes,
           COUNT(*) AS envios
    FROM logistica.envios
    GROUP BY DATEFROMPARTS(YEAR(fecha_creacion), MONTH(fecha_creacion), 1)
),
con_anterior AS (
    SELECT mes,
           envios,
           LAG(envios) OVER (ORDER BY mes) AS mes_anterior
    FROM mensual
)
SELECT mes,
       envios,
       mes_anterior,
       ROUND(100.0 * (envios - mes_anterior) / NULLIF(mes_anterior, 0), 2) AS var_pct
FROM con_anterior
ORDER BY mes;

-- P13. Promedio móvil de 3 meses del ingreso por flete.
WITH mensual AS (
    SELECT DATEFROMPARTS(YEAR(fecha_creacion), MONTH(fecha_creacion), 1) AS mes,
           SUM(valor_flete) AS ingreso
    FROM logistica.envios
    GROUP BY DATEFROMPARTS(YEAR(fecha_creacion), MONTH(fecha_creacion), 1)
)
SELECT mes, ingreso,
       ROUND(AVG(ingreso) OVER (ORDER BY mes ROWS BETWEEN 2 PRECEDING AND CURRENT ROW), 0) AS prom_movil_3m
FROM mensual
ORDER BY mes;

-- P14. Clasificación ABC (Pareto) de clientes por ingreso acumulado.
WITH ingreso AS (
    SELECT id_cliente, SUM(valor_flete) AS total
    FROM logistica.envios
    GROUP BY id_cliente
), acum AS (
    SELECT id_cliente, total,
           CAST(SUM(total) OVER (ORDER BY total DESC) AS FLOAT) / SUM(total) OVER () AS pct_acum
    FROM ingreso
)
SELECT id_cliente, total,
       ROUND(pct_acum * 100, 2) AS pct_acumulado,
       CASE WHEN pct_acum <= 0.80 THEN 'A'
            WHEN pct_acum <= 0.95 THEN 'B'
            ELSE 'C' END AS clase
FROM acum
ORDER BY total DESC;

-- P15. Retención: clientes que enviaron en un mes y también en el siguiente.
WITH actividad AS (
    SELECT DISTINCT id_cliente,
           DATEFROMPARTS(YEAR(fecha_creacion), MONTH(fecha_creacion), 1) AS mes
    FROM logistica.envios
)
SELECT a.mes,
       COUNT(DISTINCT a.id_cliente) AS clientes_activos,
       COUNT(DISTINCT b.id_cliente) AS retenidos_mes_siguiente,
       ROUND(100.0 * COUNT(DISTINCT b.id_cliente) / COUNT(DISTINCT a.id_cliente), 1) AS pct_retencion
FROM actividad a
LEFT JOIN actividad b
       ON b.id_cliente = a.id_cliente AND b.mes = DATEADD(MONTH, 1, a.mes)
GROUP BY a.mes
ORDER BY a.mes;

-- P16. Envíos entregados fuera de SLA con su retraso en días (CTE + filtro).
WITH retrasos AS (
    SELECT e.guia, s.nombre AS servicio,
           DATEDIFF(DAY, e.fecha_creacion, e.fecha_entrega) - s.dias_promesa AS dias_retraso
    FROM logistica.envios e
    JOIN logistica.servicios s ON s.id_servicio = e.id_servicio
    WHERE e.estado = N'Entregado'
)
SELECT TOP (20) *
FROM retrasos
WHERE dias_retraso > 0
ORDER BY dias_retraso DESC;

-- P17. Detección de duplicados: guías repetidas (debería devolver 0 filas).
SELECT guia, COUNT(*) AS repeticiones
FROM logistica.envios
GROUP BY guia
HAVING COUNT(*) > 1;

-- P18. Pivot: envíos por región de destino y estado.
SELECT ci.region,
       SUM(CASE WHEN e.estado = N'Entregado'   THEN 1 ELSE 0 END) AS entregados,
       SUM(CASE WHEN e.estado = N'En tránsito' THEN 1 ELSE 0 END) AS en_transito,
       SUM(CASE WHEN e.estado = N'Devuelto'    THEN 1 ELSE 0 END) AS devueltos,
       SUM(CASE WHEN e.estado = N'Con novedad' THEN 1 ELSE 0 END) AS con_novedad
FROM logistica.envios e
JOIN logistica.ciudades ci ON ci.id_ciudad = e.id_ciudad_destino
GROUP BY ci.region
ORDER BY ci.region;

-- =====================================================================
-- ======================== WINDOW FUNCTIONS ===========================

-- P19. Top 3 clientes por ingreso de flete en cada mes.
--      Concepto: ROW_NUMBER() con PARTITION BY para "top N por grupo".
WITH mensual AS (
    SELECT m.mes, e.id_cliente, SUM(e.valor_flete) AS ingreso
    FROM logistica.envios e
    CROSS APPLY (SELECT DATEFROMPARTS(YEAR(e.fecha_creacion), MONTH(e.fecha_creacion), 1) AS mes) m
    GROUP BY m.mes, e.id_cliente
), ranking AS (
    SELECT mes, id_cliente, ingreso,
           ROW_NUMBER() OVER (PARTITION BY mes ORDER BY ingreso DESC) AS posicion
    FROM mensual
)
SELECT mes, posicion, id_cliente, ingreso
FROM ranking
WHERE posicion <= 3
ORDER BY mes, posicion;

-- OPCION 2
WITH base_envios AS (
    SELECT 
        id_cliente,
        valor_flete,
        DATEFROMPARTS(YEAR(fecha_creacion), MONTH(fecha_creacion), 1) AS mes
    FROM logistica.envios
),
mensual AS (
    SELECT 
        mes, 
        id_cliente, 
        SUM(valor_flete) AS ingreso
    FROM base_envios
    GROUP BY mes, id_cliente
),
ranking AS (
    SELECT 
        mes, 
        id_cliente, 
        ingreso,
        ROW_NUMBER() OVER (PARTITION BY mes ORDER BY ingreso DESC) AS posicion
    FROM mensual
)
SELECT 
    mes, 
    posicion, 
    id_cliente, 
    ingreso
FROM ranking
WHERE posicion <= 3
ORDER BY mes, posicion;

-- P20. Ingreso mensual, acumulado del año (YTD) y % que representa del total anual.
--      Concepto: SUM() OVER con PARTITION BY año y ventana acumulada.
WITH mensual AS (
    SELECT DATEFROMPARTS(YEAR(fecha_creacion), MONTH(fecha_creacion), 1) AS mes,
           SUM(valor_flete) AS ingreso
    FROM logistica.envios
    GROUP BY DATEFROMPARTS(YEAR(fecha_creacion), MONTH(fecha_creacion), 1)
)
SELECT mes, ingreso,
       SUM(ingreso) OVER (PARTITION BY YEAR(mes) ORDER BY mes
                          ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS acumulado_anual,
       ROUND(100.0 * SUM(ingreso) OVER (PARTITION BY YEAR(mes) ORDER BY mes
                          ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)
                   / SUM(ingreso) OVER (PARTITION BY YEAR(mes)), 2) AS pct_del_total_anual
FROM mensual
ORDER BY mes;

-- OPCION 2
WITH mensual AS (
    SELECT DATEFROMPARTS(YEAR(fecha_creacion), MONTH(fecha_creacion), 1) AS mes,
           SUM(valor_flete) AS ingreso
    FROM logistica.envios
    GROUP BY DATEFROMPARTS(YEAR(fecha_creacion), MONTH(fecha_creacion), 1)
),
acumulados AS (
    SELECT mes,
           ingreso,
           SUM(ingreso) OVER (PARTITION BY YEAR(mes) ORDER BY mes
                              ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS acumulado_anual,
           SUM(ingreso) OVER (PARTITION BY YEAR(mes)) AS total_anual
    FROM mensual
)
SELECT mes,
       ingreso,
       acumulado_anual,
       ROUND(100.0 * acumulado_anual / NULLIF(total_anual, 0), 2) AS pct_del_total_anual
FROM acumulados
ORDER BY mes;

-- P21. Dividir a los clientes en cuartiles por ingreso y ver cuánto aporta cada cuartil.
--      Concepto: NTILE() y SUM(SUM()) OVER () para porcentaje sobre el total.
WITH ingreso AS (
    SELECT id_cliente, SUM(valor_flete) AS total
    FROM logistica.envios
    GROUP BY id_cliente
), cuartiles AS (
    SELECT id_cliente, total, NTILE(4) OVER (ORDER BY total DESC) AS cuartil
    FROM ingreso
)
SELECT cuartil,
       COUNT(*)   AS clientes,
       SUM(total) AS ingreso,
       ROUND(100.0 * SUM(total) / SUM(SUM(total)) OVER (), 2) AS pct_ingreso
FROM cuartiles
GROUP BY cuartil
ORDER BY cuartil;

-- P22. Clientes con mayor tiempo promedio entre envíos consecutivos (posible riesgo de fuga).
--      Concepto: LAG() para comparar cada fila con la anterior del mismo cliente.
WITH intervalos AS (
    SELECT id_cliente,
           DATEDIFF(DAY,
                    LAG(fecha_creacion) OVER (PARTITION BY id_cliente ORDER BY fecha_creacion),
                    fecha_creacion) AS dias_desde_anterior
    FROM logistica.envios
)
SELECT TOP (10)
       id_cliente,
       COUNT(dias_desde_anterior) AS intervalos,
       ROUND(AVG(CAST(dias_desde_anterior AS DECIMAL(10,2))), 2) AS prom_dias_entre_envios
FROM intervalos
WHERE dias_desde_anterior IS NOT NULL
GROUP BY id_cliente
ORDER BY prom_dias_entre_envios DESC;

-- P23. Primer y último envío de cada cliente, con la guía del último.
--      Concepto: ROW_NUMBER() ascendente y descendente sobre la misma partición.
WITH numerado AS (
    SELECT id_cliente, guia, fecha_creacion,
           ROW_NUMBER() OVER (PARTITION BY id_cliente ORDER BY fecha_creacion ASC)  AS rn_asc,
           ROW_NUMBER() OVER (PARTITION BY id_cliente ORDER BY fecha_creacion DESC) AS rn_desc
    FROM logistica.envios
)
SELECT id_cliente,
       MAX(CASE WHEN rn_asc  = 1 THEN fecha_creacion END) AS primer_envio,
       MAX(CASE WHEN rn_desc = 1 THEN fecha_creacion END) AS ultimo_envio,
       MAX(CASE WHEN rn_desc = 1 THEN guia END)           AS ultima_guia
FROM numerado
WHERE rn_asc = 1 OR rn_desc = 1
GROUP BY id_cliente
ORDER BY id_cliente;

-- P24. Mediana y percentil 90 del tiempo de entrega (días) por servicio.
--      Concepto: PERCENTILE_CONT() OVER. La media puede engañar; la mediana es más robusta.
WITH entregas AS (
    SELECT s.nombre AS servicio,
           DATEDIFF(DAY, e.fecha_creacion, e.fecha_entrega) AS dias
    FROM logistica.envios e
    JOIN logistica.servicios s ON s.id_servicio = e.id_servicio
    WHERE e.estado = N'Entregado'
)
SELECT DISTINCT servicio,
       PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY dias) OVER (PARTITION BY servicio) AS mediana_dias,
       PERCENTILE_CONT(0.9) WITHIN GROUP (ORDER BY dias) OVER (PARTITION BY servicio) AS p90_dias
FROM entregas;

-- P25. Mensajeros vs. el promedio de su sucursal, con ranking global.
--      Concepto: AVG() OVER (PARTITION BY ...) y DENSE_RANK().
WITH entregas AS (
    SELECT m.id_sucursal, m.nombre AS mensajero, COUNT(*) AS entregas
    FROM logistica.envios e
    JOIN logistica.mensajeros m ON m.id_mensajero = e.id_mensajero
    WHERE e.estado = N'Entregado'
    GROUP BY m.id_sucursal, m.nombre
)
SELECT su.nombre AS sucursal, x.mensajero, x.entregas,
       ROUND(AVG(CAST(x.entregas AS DECIMAL(10,2))) OVER (PARTITION BY x.id_sucursal), 1) AS prom_sucursal,
       x.entregas - AVG(x.entregas) OVER (PARTITION BY x.id_sucursal) AS dif_vs_promedio,
       DENSE_RANK() OVER (ORDER BY x.entregas DESC) AS ranking_global
FROM entregas x
JOIN logistica.sucursales su ON su.id_sucursal = x.id_sucursal
ORDER BY ranking_global;

-- P26. Participación de cada servicio dentro del total de envíos de cada mes.
--      Concepto: SUM() OVER (PARTITION BY mes) como denominador.
WITH conteo AS (
    SELECT m.mes, s.nombre AS servicio, COUNT(*) AS envios
    FROM logistica.envios e
    JOIN logistica.servicios s ON s.id_servicio = e.id_servicio
    CROSS APPLY (SELECT DATEFROMPARTS(YEAR(e.fecha_creacion), MONTH(e.fecha_creacion), 1) AS mes) m
    GROUP BY m.mes, s.nombre
)
SELECT mes, servicio, envios,
       ROUND(100.0 * envios / SUM(envios) OVER (PARTITION BY mes), 2) AS pct_del_mes
FROM conteo
ORDER BY mes, servicio;

-- P27. Envíos atípicos: flete a más de 1.5 desviaciones estándar sobre el promedio de su servicio.
--      Concepto: AVG() y STDEV() como window functions para calcular un z-score.
WITH estadisticas AS (
    SELECT guia, id_servicio, valor_flete,
           AVG(valor_flete)   OVER (PARTITION BY id_servicio) AS prom,
           STDEV(valor_flete) OVER (PARTITION BY id_servicio) AS desv
    FROM logistica.envios
)
SELECT TOP (15)
       guia, id_servicio, valor_flete,
       ROUND(prom, 0) AS prom_servicio,
       ROUND((valor_flete - prom) / NULLIF(desv, 0), 2) AS z_score
FROM estadisticas
WHERE valor_flete > prom + 1.5 * desv
ORDER BY z_score DESC;

-- P28. Tiempo promedio (horas) entre estados consecutivos del seguimiento.
--      Concepto: LEAD() para mirar el siguiente evento del mismo envío.
WITH eventos AS (
    SELECT id_envio, estado, fecha_evento,
           LEAD(estado)       OVER (PARTITION BY id_envio ORDER BY fecha_evento) AS siguiente_estado,
           LEAD(fecha_evento) OVER (PARTITION BY id_envio ORDER BY fecha_evento) AS fecha_siguiente
    FROM logistica.seguimiento_envios
)
SELECT estado, siguiente_estado,
       COUNT(*) AS transiciones,
       ROUND(AVG(CAST(DATEDIFF(HOUR, fecha_evento, fecha_siguiente) AS DECIMAL(10,2))), 1) AS horas_prom
FROM eventos
WHERE siguiente_estado IS NOT NULL
GROUP BY estado, siguiente_estado
ORDER BY transiciones DESC;

-- ============================ CTE AVANZADOS ==========================

-- P29. Clientes nuevos vs. recurrentes por mes.
--      Concepto: CTE encadenados; "nuevo" = mes del primer envío del cliente.
WITH actividad AS (
    SELECT DISTINCT id_cliente,
           DATEFROMPARTS(YEAR(fecha_creacion), MONTH(fecha_creacion), 1) AS mes
    FROM logistica.envios
), primer AS (
    SELECT id_cliente, MIN(mes) AS primer_mes
    FROM actividad
    GROUP BY id_cliente
)
SELECT a.mes,
       SUM(CASE WHEN a.mes = p.primer_mes THEN 1 ELSE 0 END) AS nuevos,
       SUM(CASE WHEN a.mes > p.primer_mes THEN 1 ELSE 0 END) AS recurrentes
FROM actividad a
JOIN primer p ON p.id_cliente = a.id_cliente
GROUP BY a.mes
ORDER BY a.mes;

-- P30. Retención por cohorte: de los clientes cuyo primer envío fue en el mes X,
--      ¿qué % sigue activo N meses después?
--      Concepto: cohortes + FIRST_VALUE() como base (100%) de cada cohorte.
WITH actividad AS (
    SELECT DISTINCT id_cliente,
           DATEFROMPARTS(YEAR(fecha_creacion), MONTH(fecha_creacion), 1) AS mes
    FROM logistica.envios
), primer AS (
    SELECT id_cliente, MIN(mes) AS cohorte
    FROM actividad
    GROUP BY id_cliente
), cohorte AS (
    SELECT p.cohorte,
           DATEDIFF(MONTH, p.cohorte, a.mes) AS mes_n,
           COUNT(DISTINCT a.id_cliente)      AS clientes
    FROM actividad a
    JOIN primer p ON p.id_cliente = a.id_cliente
    GROUP BY p.cohorte, DATEDIFF(MONTH, p.cohorte, a.mes)
)
SELECT cohorte, mes_n, clientes,
       ROUND(100.0 * clientes / FIRST_VALUE(clientes) OVER (PARTITION BY cohorte ORDER BY mes_n), 1) AS pct_retencion
FROM cohorte
ORDER BY cohorte, mes_n;

-- P31. Racha más larga de meses consecutivos con envíos por cliente ("gaps and islands").
--      Concepto: mes_indice - ROW_NUMBER() es constante dentro de cada racha consecutiva.
WITH actividad AS (
    SELECT DISTINCT id_cliente,
           DATEFROMPARTS(YEAR(fecha_creacion), MONTH(fecha_creacion), 1) AS mes
    FROM logistica.envios
), grupos AS (
    SELECT id_cliente, mes,
           DATEDIFF(MONTH, CAST('2025-01-01' AS DATE), mes)
             - ROW_NUMBER() OVER (PARTITION BY id_cliente ORDER BY mes) AS grp
    FROM actividad
), rachas AS (
    SELECT id_cliente, MIN(mes) AS inicio, MAX(mes) AS fin, COUNT(*) AS meses_consecutivos
    FROM grupos
    GROUP BY id_cliente, grp
)
SELECT TOP (10) *
FROM rachas
ORDER BY meses_consecutivos DESC, id_cliente;

-- P32. Rutas con tasa de problemas (devueltos + con novedad) superior al promedio general.
--      Concepto: un CTE con el promedio global que se cruza contra cada ruta.
WITH rutas AS (
    SELECT id_ciudad_origen, id_ciudad_destino,
           COUNT(*) AS envios,
           SUM(CASE WHEN estado IN (N'Devuelto', N'Con novedad') THEN 1 ELSE 0 END) AS problemas
    FROM logistica.envios
    GROUP BY id_ciudad_origen, id_ciudad_destino
), promedio AS (
    SELECT 1.0 * SUM(problemas) / SUM(envios) AS tasa_general
    FROM rutas
)
SELECT TOP (10)
       co.nombre AS origen, cd.nombre AS destino, r.envios,
       ROUND(100.0 * r.problemas / r.envios, 2) AS pct_ruta,
       ROUND(100.0 * p.tasa_general, 2)         AS pct_general
FROM rutas r
CROSS JOIN promedio p
JOIN logistica.ciudades co ON co.id_ciudad = r.id_ciudad_origen
JOIN logistica.ciudades cd ON cd.id_ciudad = r.id_ciudad_destino
WHERE r.envios >= 15
  AND 1.0 * r.problemas / r.envios > p.tasa_general
ORDER BY pct_ruta DESC;

-- P33. Envíos por ciudad de origen y mes, incluyendo meses con cero envíos.
--      Concepto: CTE recursivo para generar un calendario + CROSS JOIN + LEFT JOIN + COALESCE.
WITH calendario AS (
    SELECT CAST('2025-01-01' AS DATE) AS mes
    UNION ALL
    SELECT DATEADD(MONTH, 1, mes) FROM calendario WHERE mes < '2026-08-01'
), mensual AS (
    SELECT e.id_ciudad_origen, m.mes, COUNT(*) AS envios
    FROM logistica.envios e
    CROSS APPLY (SELECT DATEFROMPARTS(YEAR(e.fecha_creacion), MONTH(e.fecha_creacion), 1) AS mes) m
    GROUP BY e.id_ciudad_origen, m.mes
)
SELECT ci.nombre AS ciudad, c.mes, COALESCE(mn.envios, 0) AS envios
FROM logistica.ciudades ci
CROSS JOIN calendario c
LEFT JOIN mensual mn ON mn.id_ciudad_origen = ci.id_ciudad AND mn.mes = c.mes
ORDER BY ci.nombre, c.mes
OPTION (MAXRECURSION 100);

-- ====================== NEGOCIO / CASOS INTEGRADOS ===================

-- P34. Antigüedad de cartera (aging) por rangos de mora, con % sobre la cartera pendiente.
--      Concepto: CASE para bucketizar + SUM() OVER () para participación.
WITH pendientes AS (
    SELECT valor_total,
           DATEDIFF(DAY, fecha_vencimiento, CAST(GETDATE() AS DATE)) AS dias_mora
    FROM logistica.facturas
    WHERE fecha_pago IS NULL
), rangos AS (
    SELECT valor_total,
           CASE WHEN dias_mora <= 0  THEN 1
                WHEN dias_mora <= 30 THEN 2
                WHEN dias_mora <= 60 THEN 3
                WHEN dias_mora <= 90 THEN 4
                ELSE 5 END AS orden,
           CASE WHEN dias_mora <= 0  THEN N'Vigente'
                WHEN dias_mora <= 30 THEN N'1-30 días'
                WHEN dias_mora <= 60 THEN N'31-60 días'
                WHEN dias_mora <= 90 THEN N'61-90 días'
                ELSE N'Más de 90 días' END AS rango
    FROM pendientes
)
SELECT rango,
       COUNT(*)         AS facturas,
       SUM(valor_total) AS valor,
       ROUND(100.0 * SUM(valor_total) / SUM(SUM(valor_total)) OVER (), 2) AS pct_cartera
FROM rangos
GROUP BY orden, rango
ORDER BY orden;

-- P35. Envíos "En tránsito" fuera de SLA respecto a la fecha de corte (último dato cargado).
--      Concepto: CTE de parámetros (fecha de corte) en lugar de GETDATE(), para análisis reproducibles.
WITH corte AS (
    SELECT CAST(MAX(fecha_creacion) AS DATE) AS fecha_corte
    FROM logistica.envios
), pendientes AS (
    SELECT s.nombre AS servicio, s.dias_promesa,
           DATEDIFF(DAY, e.fecha_creacion, c.fecha_corte) AS dias_transito
    FROM logistica.envios e
    JOIN logistica.servicios s ON s.id_servicio = e.id_servicio
    CROSS JOIN corte c
    WHERE e.estado = N'En tránsito'
)
SELECT servicio,
       COUNT(*) AS en_transito,
       SUM(CASE WHEN dias_transito > dias_promesa THEN 1 ELSE 0 END) AS fuera_sla,
       ROUND(100.0 * SUM(CASE WHEN dias_transito > dias_promesa THEN 1 ELSE 0 END) / COUNT(*), 1) AS pct_fuera_sla
FROM pendientes
GROUP BY servicio
ORDER BY pct_fuera_sla DESC;

-- P36. Segmentación RFM de clientes (Recencia, Frecuencia, Monetario).
--      Concepto: NTILE() por cada dimensión y reglas de negocio con CASE.
WITH corte AS (
    SELECT CAST(MAX(fecha_creacion) AS DATE) AS fecha_corte
    FROM logistica.envios
), rfm AS (
    SELECT e.id_cliente,
           DATEDIFF(DAY, MAX(e.fecha_creacion), c.fecha_corte) AS recencia_dias,
           COUNT(*)            AS frecuencia,
           SUM(e.valor_flete)  AS monetario
    FROM logistica.envios e
    CROSS JOIN corte c
    GROUP BY e.id_cliente, c.fecha_corte
), puntajes AS (
    SELECT id_cliente, recencia_dias, frecuencia, monetario,
           NTILE(4) OVER (ORDER BY recencia_dias DESC) AS r,   -- 4 = compró más recientemente
           NTILE(4) OVER (ORDER BY frecuencia ASC)     AS f,   -- 4 = más frecuente
           NTILE(4) OVER (ORDER BY monetario ASC)      AS m    -- 4 = mayor valor
    FROM rfm
)
SELECT id_cliente, recencia_dias, frecuencia, monetario, r, f, m,
       CASE WHEN r >= 3 AND f >= 3 AND m >= 3 THEN N'Campeón'
            WHEN r <= 2 AND f >= 3             THEN N'En riesgo (era frecuente)'
            WHEN r >= 3 AND f <= 2             THEN N'Nuevo / ocasional'
            ELSE N'Regular' END AS segmento
FROM puntajes
ORDER BY m DESC, f DESC, r DESC;

-- =====================================================================
-- PRÁCTICA DE OBJETOS T-SQL: VISTAS, TABLAS TEMPORALES Y PROCEDIMIENTOS ALMACENADOS
-- Motor: SQL Server 2016 SP1+ (usa CREATE OR ALTER)
-- Requisito: haber ejecutado coordinadora_practica_sqlserver.sql (esquema [logistica] con datos).
-- Ejecuta el archivo por bloques (separados por GO) para ver el resultado de cada ejemplo de uso.
-- =====================================================================

/* ---------------------------------------------------------------------
   PREGUNTAS CONCEPTUALES FRECUENTES (con respuesta corta)
   ---------------------------------------------------------------------
   * Vista vs. tabla temporal vs. CTE vs. variable de tabla:
       - Vista: consulta guardada en la BD; no almacena datos (salvo vista indexada); se reutiliza entre sesiones.
       - Tabla temporal (#t): almacena datos en tempdb, vive durante la sesión, admite índices y estadísticas.
         Útil cuando el resultado intermedio se reutiliza varias veces o es grande.
       - CTE: resultado con nombre válido solo para UNA sentencia; no se materializa necesariamente.
       - Variable de tabla (@t): vive solo en el lote; sin estadísticas; útil para pocos registros.
   * Procedimiento almacenado vs. función: el SP puede modificar datos, usar transacciones y devolver
     varios resultados; la función (escalar o de tabla) se usa dentro de un SELECT y no debe tener efectos secundarios.
   * ORDER BY en una vista: no está permitido salvo con TOP/OFFSET; el orden se define al consultar la vista.
   * Parameter sniffing: el plan se compila con los valores del primer llamado y puede ser malo para otros.
     Mitigaciones: OPTION (RECOMPILE), OPTIMIZE FOR, o separar la lógica según el parámetro.
   * SET NOCOUNT ON: evita enviar el mensaje "N filas afectadas" y reduce tráfico.
   --------------------------------------------------------------------- */


-- =====================================================================
-- A. VISTAS
-- =====================================================================

-- P37. Crea una vista con el detalle de cada envío: datos del cliente, servicio, ciudades,
--      días de entrega y si cumplió el SLA. Debe servir de base para los reportes.
CREATE OR ALTER VIEW logistica.vw_envios_detalle
AS
SELECT e.id_envio,
       e.guia,
       e.fecha_creacion,
       CAST(e.fecha_creacion AS DATE) AS fecha,
       DATEFROMPARTS(YEAR(e.fecha_creacion), MONTH(e.fecha_creacion), 1) AS mes,
       e.fecha_entrega,
       e.estado,
       e.contra_entrega,
       e.peso_kg,
       e.valor_declarado,
       e.valor_flete,
       c.id_cliente,
       c.razon_social,
       c.segmento,
       s.id_servicio,
       s.nombre       AS servicio,
       s.dias_promesa,
       co.nombre      AS ciudad_origen,
       cd.nombre      AS ciudad_destino,
       cd.region      AS region_destino,
       CASE WHEN e.fecha_entrega IS NULL THEN NULL
            ELSE DATEDIFF(DAY, e.fecha_creacion, e.fecha_entrega) END AS dias_entrega,
       CASE WHEN e.fecha_entrega IS NULL THEN NULL
            WHEN DATEDIFF(DAY, e.fecha_creacion, e.fecha_entrega) <= s.dias_promesa THEN 1
            ELSE 0 END AS cumple_sla
FROM logistica.envios e
JOIN logistica.clientes  c  ON c.id_cliente  = e.id_cliente
JOIN logistica.servicios s  ON s.id_servicio = e.id_servicio
JOIN logistica.ciudades  co ON co.id_ciudad  = e.id_ciudad_origen
JOIN logistica.ciudades  cd ON cd.id_ciudad  = e.id_ciudad_destino;
GO

-- Uso: envíos entregados fuera de SLA de clientes del segmento Ecommerce.
SELECT TOP (10) guia, razon_social, servicio, ciudad_destino, dias_entrega, dias_promesa
FROM logistica.vw_envios_detalle
WHERE segmento = N'Ecommerce' AND cumple_sla = 0
ORDER BY dias_entrega DESC;
GO

-- P38. Crea una vista de KPIs mensuales (envíos, entregados, ingreso, % cumplimiento SLA y % devoluciones)
--      construida sobre la vista anterior. Luego calcula la variación del ingreso vs. el mes anterior.
CREATE OR ALTER VIEW logistica.vw_kpi_mensual
AS
SELECT mes,
       COUNT(*) AS envios,
       SUM(CASE WHEN estado = N'Entregado' THEN 1 ELSE 0 END) AS entregados,
       SUM(valor_flete) AS ingreso_flete,
       ROUND(100.0 * SUM(CASE WHEN cumple_sla = 1 THEN 1 ELSE 0 END)
             / NULLIF(SUM(CASE WHEN cumple_sla IS NOT NULL THEN 1 ELSE 0 END), 0), 2) AS pct_sla,
       ROUND(100.0 * SUM(CASE WHEN estado = N'Devuelto' THEN 1 ELSE 0 END) / COUNT(*), 2) AS pct_devolucion
FROM logistica.vw_envios_detalle
GROUP BY mes;
GO

-- Uso: el ORDER BY y la variación se definen al consultar la vista, no dentro de ella.
SELECT mes, envios, ingreso_flete, pct_sla, pct_devolucion,
       ROUND(100.0 * (ingreso_flete - LAG(ingreso_flete) OVER (ORDER BY mes))
             / NULLIF(LAG(ingreso_flete) OVER (ORDER BY mes), 0), 2) AS var_ingreso_pct
FROM logistica.vw_kpi_mensual
ORDER BY mes;
GO

-- P39. Crea una vista de cartera pendiente por cliente (facturas sin pago): cantidad, valor pendiente,
--      valor vencido y máximo de días de mora. Luego lista los 5 clientes con mayor valor vencido.
CREATE OR ALTER VIEW logistica.vw_cartera_cliente
AS
SELECT c.id_cliente,
       c.razon_social,
       COUNT(*)             AS facturas_pendientes,
       SUM(f.valor_total)   AS valor_pendiente,
       SUM(CASE WHEN f.fecha_vencimiento < CAST(GETDATE() AS DATE) THEN f.valor_total ELSE 0 END) AS valor_vencido,
       MAX(CASE WHEN f.fecha_vencimiento < CAST(GETDATE() AS DATE)
                THEN DATEDIFF(DAY, f.fecha_vencimiento, CAST(GETDATE() AS DATE)) END) AS max_dias_mora
FROM logistica.facturas f
JOIN logistica.clientes c ON c.id_cliente = f.id_cliente
WHERE f.fecha_pago IS NULL
GROUP BY c.id_cliente, c.razon_social;
GO

-- Uso
SELECT TOP (5) * FROM logistica.vw_cartera_cliente ORDER BY valor_vencido DESC;
GO


-- =====================================================================
-- B. TABLAS TEMPORALES Y VARIABLES DE TABLA
-- =====================================================================

-- P40. Crea una tabla temporal con el ingreso y los envíos por cliente y mes, indexada por cliente.
--      Úsala para encontrar clientes cuyo último mes de actividad cayó más de 30% frente al
--      promedio de sus 3 meses anteriores.
DROP TABLE IF EXISTS #ventas_cliente_mes;

SELECT id_cliente, mes, COUNT(*) AS envios, SUM(valor_flete) AS ingreso
INTO #ventas_cliente_mes
FROM logistica.vw_envios_detalle
GROUP BY id_cliente, mes;

CREATE CLUSTERED INDEX ix_vcm ON #ventas_cliente_mes (id_cliente, mes);

WITH historia AS (
    SELECT id_cliente, mes, ingreso,
           AVG(ingreso) OVER (PARTITION BY id_cliente ORDER BY mes
                              ROWS BETWEEN 3 PRECEDING AND 1 PRECEDING) AS prom_3m_previos,
           ROW_NUMBER() OVER (PARTITION BY id_cliente ORDER BY mes DESC) AS rn
    FROM #ventas_cliente_mes
)
SELECT TOP (10)
       id_cliente, mes AS ultimo_mes, ingreso,
       ROUND(prom_3m_previos, 0) AS prom_3m_previos,
       ROUND(100.0 * (ingreso - prom_3m_previos) / prom_3m_previos, 1) AS variacion_pct
FROM historia
WHERE rn = 1
  AND prom_3m_previos IS NOT NULL
  AND ingreso < 0.7 * prom_3m_previos
ORDER BY variacion_pct;

DROP TABLE IF EXISTS #ventas_cliente_mes;
GO

-- P41. Usa una variable de tabla para guardar el ingreso por ruta (origen-destino) y muestra
--      las 5 rutas con más ingreso con los nombres de las ciudades.
DECLARE @rutas TABLE (
    id_ciudad_origen  INT,
    id_ciudad_destino INT,
    envios            INT,
    ingreso           DECIMAL(14,2)
);

INSERT INTO @rutas (id_ciudad_origen, id_ciudad_destino, envios, ingreso)
SELECT id_ciudad_origen, id_ciudad_destino, COUNT(*), SUM(valor_flete)
FROM logistica.envios
GROUP BY id_ciudad_origen, id_ciudad_destino;

SELECT TOP (5) co.nombre AS origen, cd.nombre AS destino, r.envios, r.ingreso
FROM @rutas r
JOIN logistica.ciudades co ON co.id_ciudad = r.id_ciudad_origen
JOIN logistica.ciudades cd ON cd.id_ciudad = r.id_ciudad_destino
ORDER BY r.ingreso DESC;
GO

-- P42. Análisis por pasos con tablas temporales: identifica clientes con historial (>= 10 envíos) que llevan
--      al menos @dias_inactivo días sin enviar respecto a la fecha de corte (último dato cargado), y cruza
--      con la cartera vencida para priorizar la gestión comercial.
DECLARE @dias_inactivo INT  = 15;
DECLARE @corte         DATE = (SELECT CAST(MAX(fecha_creacion) AS DATE) FROM logistica.envios);

DROP TABLE IF EXISTS #ultimo_envio;
DROP TABLE IF EXISTS #riesgo;

-- Paso 1: actividad por cliente
SELECT id_cliente, MAX(fecha) AS ultimo_envio, COUNT(*) AS envios_historicos, SUM(valor_flete) AS ingreso_total
INTO #ultimo_envio
FROM logistica.vw_envios_detalle
GROUP BY id_cliente;

-- Paso 2: clientes en riesgo
SELECT u.id_cliente, u.ultimo_envio, u.envios_historicos, u.ingreso_total,
       DATEDIFF(DAY, u.ultimo_envio, @corte) AS dias_inactivo
INTO #riesgo
FROM #ultimo_envio u
WHERE u.envios_historicos >= 10
  AND DATEDIFF(DAY, u.ultimo_envio, @corte) >= @dias_inactivo;

-- Paso 3: priorización con la vista de cartera
SELECT r.id_cliente, c.razon_social, r.ultimo_envio, r.dias_inactivo, r.envios_historicos, r.ingreso_total,
       COALESCE(v.valor_vencido, 0) AS valor_vencido,
       CASE WHEN COALESCE(v.valor_vencido, 0) > 0 THEN N'Alta (inactivo y con mora)'
            ELSE N'Media (inactivo)' END AS prioridad
FROM #riesgo r
JOIN logistica.clientes c ON c.id_cliente = r.id_cliente
LEFT JOIN logistica.vw_cartera_cliente v ON v.id_cliente = r.id_cliente
ORDER BY CASE WHEN COALESCE(v.valor_vencido, 0) > 0 THEN 1 ELSE 2 END, r.ingreso_total DESC;

DROP TABLE IF EXISTS #ultimo_envio;
DROP TABLE IF EXISTS #riesgo;
GO


-- =====================================================================
-- C. PROCEDIMIENTOS ALMACENADOS CON PARÁMETROS
-- =====================================================================

-- P43. Crea un SP que reciba un rango de fechas y devuelva, por servicio: envíos, ingreso de flete
--      y % de cumplimiento del SLA. Debe validar que la fecha inicial no sea mayor que la final.
CREATE OR ALTER PROCEDURE logistica.sp_kpi_servicio
    @fecha_inicio DATE,
    @fecha_fin    DATE
AS
BEGIN
    SET NOCOUNT ON;

    IF @fecha_inicio > @fecha_fin
    BEGIN
        THROW 50001, N'La fecha inicial no puede ser mayor que la fecha final.', 1;
    END;

    SELECT servicio,
           COUNT(*)         AS envios,
           SUM(valor_flete) AS ingreso_flete,
           ROUND(100.0 * SUM(CASE WHEN cumple_sla = 1 THEN 1 ELSE 0 END)
                 / NULLIF(SUM(CASE WHEN cumple_sla IS NOT NULL THEN 1 ELSE 0 END), 0), 2) AS pct_sla
    FROM logistica.vw_envios_detalle
    WHERE fecha BETWEEN @fecha_inicio AND @fecha_fin
    GROUP BY servicio
    ORDER BY envios DESC;
END;
GO

-- Uso (parámetros por nombre) y prueba de la validación
EXEC logistica.sp_kpi_servicio @fecha_inicio = '2025-06-01', @fecha_fin = '2025-06-30';

BEGIN TRY
    EXEC logistica.sp_kpi_servicio @fecha_inicio = '2025-07-01', @fecha_fin = '2025-06-01';
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS numero_error, ERROR_MESSAGE() AS mensaje;
END CATCH;
GO

-- P44. Crea un SP que devuelva los envíos de un cliente con filtros OPCIONALES por estado y fecha desde,
--      y un máximo de filas (por defecto 50). Debe validar que el cliente exista.
CREATE OR ALTER PROCEDURE logistica.sp_envios_cliente
    @id_cliente  INT,
    @estado      NVARCHAR(20) = NULL,
    @fecha_desde DATE         = NULL,
    @top         INT          = 50
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM logistica.clientes WHERE id_cliente = @id_cliente)
    BEGIN
        THROW 50002, N'El cliente indicado no existe.', 1;
    END;

    SELECT TOP (@top)
           guia, fecha_creacion, servicio, ciudad_origen, ciudad_destino,
           estado, valor_flete, dias_entrega, cumple_sla
    FROM logistica.vw_envios_detalle
    WHERE id_cliente = @id_cliente
      AND (@estado      IS NULL OR estado = @estado)
      AND (@fecha_desde IS NULL OR fecha >= @fecha_desde)
    ORDER BY fecha_creacion DESC
    OPTION (RECOMPILE);   -- evita un plan malo por el patrón de filtros opcionales
END;
GO

-- Uso: solo el cliente / cliente + estado / cliente + estado + fecha
EXEC logistica.sp_envios_cliente @id_cliente = 5;
EXEC logistica.sp_envios_cliente @id_cliente = 5, @estado = N'Devuelto';
EXEC logistica.sp_envios_cliente 5, N'Entregado', '2026-01-01', 10;
GO

-- P45. Crea un SP que devuelva los N clientes con mayor ingreso en un año y, opcionalmente, en un mes.
--      Parámetros: @anio (obligatorio), @mes (opcional, 1-12), @n (por defecto 10).
CREATE OR ALTER PROCEDURE logistica.sp_top_clientes
    @anio INT,
    @mes  INT = NULL,
    @n    INT = 10
AS
BEGIN
    SET NOCOUNT ON;

    IF @mes IS NOT NULL AND @mes NOT BETWEEN 1 AND 12
    BEGIN
        THROW 50003, N'El mes debe estar entre 1 y 12.', 1;
    END;

    SELECT TOP (@n)
           id_cliente, razon_social, segmento,
           COUNT(*)         AS envios,
           SUM(valor_flete) AS ingreso,
           RANK() OVER (ORDER BY SUM(valor_flete) DESC) AS posicion
    FROM logistica.vw_envios_detalle
    WHERE YEAR(fecha) = @anio
      AND (@mes IS NULL OR MONTH(fecha) = @mes)
    GROUP BY id_cliente, razon_social, segmento
    ORDER BY ingreso DESC;
END;
GO

-- Uso
EXEC logistica.sp_top_clientes @anio = 2025;
EXEC logistica.sp_top_clientes @anio = 2026, @mes = 3, @n = 5;
GO

-- P46. Crea un SP con parámetros de SALIDA (OUTPUT) que, dado un servicio y un rango de fechas, devuelva
--      el total de envíos entregados y el % de cumplimiento del SLA. Luego llámalo y muestra los valores.
CREATE OR ALTER PROCEDURE logistica.sp_cumplimiento_sla
    @id_servicio      INT,
    @fecha_inicio     DATE,
    @fecha_fin        DATE,
    @total_entregados INT          OUTPUT,
    @pct_sla          DECIMAL(5,2) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT @total_entregados = COUNT(*),
           @pct_sla = ROUND(100.0 * SUM(CASE WHEN cumple_sla = 1 THEN 1 ELSE 0 END)
                            / NULLIF(COUNT(*), 0), 2)
    FROM logistica.vw_envios_detalle
    WHERE id_servicio = @id_servicio
      AND estado = N'Entregado'
      AND fecha BETWEEN @fecha_inicio AND @fecha_fin;
END;
GO

-- Uso
DECLARE @total INT, @pct DECIMAL(5,2);

EXEC logistica.sp_cumplimiento_sla
     @id_servicio      = 2,
     @fecha_inicio     = '2025-01-01',
     @fecha_fin        = '2025-12-31',
     @total_entregados = @total OUTPUT,
     @pct_sla          = @pct   OUTPUT;

SELECT @total AS total_entregados, @pct AS pct_sla;
GO

-- P47. Crea un SP transaccional para registrar una novedad sobre una guía: valida que la guía exista y que
--      no esté entregada; inserta la novedad, actualiza el estado del envío a 'Con novedad' y registra el
--      evento en el seguimiento. Todo debe ser atómico (TRY/CATCH + transacción) y devolver el id de la novedad.
--      OJO: este SP MODIFICA datos. Para restaurar la base de práctica, vuelve a ejecutar el script de carga.
CREATE OR ALTER PROCEDURE logistica.sp_registrar_novedad
    @guia         VARCHAR(15),
    @tipo_novedad NVARCHAR(40),
    @id_novedad   BIGINT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @id_envio BIGINT, @estado NVARCHAR(20);

    BEGIN TRY
        SELECT @id_envio = id_envio, @estado = estado
        FROM logistica.envios
        WHERE guia = @guia;

        IF @id_envio IS NULL
        BEGIN
            THROW 50010, N'La guía no existe.', 1;
        END;

        IF @estado = N'Entregado'
        BEGIN
            THROW 50011, N'No se puede registrar una novedad en un envío ya entregado.', 1;
        END;

        BEGIN TRANSACTION;

            INSERT INTO logistica.novedades (id_envio, tipo_novedad, fecha_novedad, resuelta)
            VALUES (@id_envio, @tipo_novedad, SYSDATETIME(), 0);

            SET @id_novedad = SCOPE_IDENTITY();

            UPDATE logistica.envios
            SET estado = N'Con novedad'
            WHERE id_envio = @id_envio;

            INSERT INTO logistica.seguimiento_envios (id_envio, estado, fecha_evento)
            VALUES (@id_envio, N'Con novedad', SYSDATETIME());

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;   -- relanza el error original al llamador
    END CATCH;
END;
GO

-- Uso: caso exitoso y caso con error
DECLARE @guia VARCHAR(15) = (SELECT TOP (1) guia FROM logistica.envios WHERE estado = N'En tránsito' ORDER BY id_envio);
DECLARE @id BIGINT;

EXEC logistica.sp_registrar_novedad @guia = @guia, @tipo_novedad = N'Destinatario ausente', @id_novedad = @id OUTPUT;
SELECT @id AS id_novedad_creada, @guia AS guia;

BEGIN TRY
    EXEC logistica.sp_registrar_novedad @guia = 'NO_EXISTE', @tipo_novedad = N'Rechazado', @id_novedad = @id OUTPUT;
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS numero_error, ERROR_MESSAGE() AS mensaje;
END CATCH;
GO

-- P48. Crea un SP de reporte integrado que use una tabla temporal y la vista de cartera: clientes con
--      al menos @min_envios envíos históricos y @dias_inactividad días sin enviar respecto a una fecha
--      de corte (por defecto, el último dato cargado), con su cartera vencida y una prioridad.
CREATE OR ALTER PROCEDURE logistica.sp_reporte_clientes_riesgo
    @dias_inactividad INT  = 15,
    @min_envios       INT  = 10,
    @fecha_corte      DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF @fecha_corte IS NULL
        SELECT @fecha_corte = CAST(MAX(fecha_creacion) AS DATE) FROM logistica.envios;

    -- La tabla temporal se elimina sola al terminar el SP; el DROP explícito es solo buena práctica.
    DROP TABLE IF EXISTS #actividad;

    SELECT id_cliente,
           MAX(fecha)       AS ultimo_envio,
           COUNT(*)         AS envios,
           SUM(valor_flete) AS ingreso
    INTO #actividad
    FROM logistica.vw_envios_detalle
    WHERE fecha <= @fecha_corte
    GROUP BY id_cliente;

    SELECT a.id_cliente, c.razon_social, a.ultimo_envio, d.dias_inactivo,
           a.envios, a.ingreso,
           COALESCE(v.valor_vencido, 0) AS valor_vencido,
           CASE WHEN COALESCE(v.valor_vencido, 0) > 0 THEN N'Alta' ELSE N'Media' END AS prioridad
    FROM #actividad a
    JOIN logistica.clientes c ON c.id_cliente = a.id_cliente
    CROSS APPLY (SELECT DATEDIFF(DAY, a.ultimo_envio, @fecha_corte) AS dias_inactivo) d
    LEFT JOIN logistica.vw_cartera_cliente v ON v.id_cliente = a.id_cliente
    WHERE a.envios >= @min_envios
      AND d.dias_inactivo >= @dias_inactividad
    ORDER BY CASE WHEN COALESCE(v.valor_vencido, 0) > 0 THEN 1 ELSE 2 END, a.ingreso DESC;
END;
GO

-- Uso: valores por defecto / parámetros personalizados
EXEC logistica.sp_reporte_clientes_riesgo;
EXEC logistica.sp_reporte_clientes_riesgo @dias_inactividad = 7, @min_envios = 20;
GO

-- P49. (Avanzada) Crea un SP que agrupe el ingreso y los envíos según una dimensión elegida por el usuario
--      (servicio, región, segmento o mes), con rango de fechas opcional. Debe usar SQL dinámico de forma
--      segura: lista blanca de valores, QUOTENAME y parámetros con sp_executesql (evita inyección SQL).
CREATE OR ALTER PROCEDURE logistica.sp_reporte_dinamico
    @agrupar_por  NVARCHAR(20),
    @fecha_inicio DATE = NULL,
    @fecha_fin    DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;

    -- Lista blanca: solo se acepta un valor conocido, nunca texto libre.
    DECLARE @col SYSNAME =
        CASE @agrupar_por
            WHEN N'servicio' THEN N'servicio'
            WHEN N'region'   THEN N'region_destino'
            WHEN N'segmento' THEN N'segmento'
            WHEN N'mes'      THEN N'mes'
        END;

    IF @col IS NULL
    BEGIN
        THROW 50020, N'Valor de @agrupar_por no válido. Use: servicio, region, segmento o mes.', 1;
    END;

    DECLARE @sql NVARCHAR(MAX) =
          N'SELECT ' + QUOTENAME(@col) + N' AS grupo, COUNT(*) AS envios, SUM(valor_flete) AS ingreso '
        + N'FROM logistica.vw_envios_detalle '
        + N'WHERE (@fi IS NULL OR fecha >= @fi) AND (@ff IS NULL OR fecha <= @ff) '
        + N'GROUP BY ' + QUOTENAME(@col) + N' '
        + N'ORDER BY ' + QUOTENAME(@col) + N';';

    EXEC sys.sp_executesql @sql, N'@fi DATE, @ff DATE', @fi = @fecha_inicio, @ff = @fecha_fin;
END;
GO

-- Uso
EXEC logistica.sp_reporte_dinamico @agrupar_por = N'region';
EXEC logistica.sp_reporte_dinamico @agrupar_por = N'mes', @fecha_inicio = '2026-01-01', @fecha_fin = '2026-06-30';

BEGIN TRY
    EXEC logistica.sp_reporte_dinamico @agrupar_por = N'servicio; DROP TABLE logistica.envios;--';
END TRY
BEGIN CATCH
    SELECT ERROR_MESSAGE() AS mensaje;   -- el intento de inyección es rechazado por la lista blanca
END CATCH;
GO


-- =====================================================================
-- LIMPIEZA (opcional): elimina los objetos creados en este archivo
-- =====================================================================
/*
DROP PROCEDURE IF EXISTS logistica.sp_reporte_dinamico;
DROP PROCEDURE IF EXISTS logistica.sp_reporte_clientes_riesgo;
DROP PROCEDURE IF EXISTS logistica.sp_registrar_novedad;
DROP PROCEDURE IF EXISTS logistica.sp_cumplimiento_sla;
DROP PROCEDURE IF EXISTS logistica.sp_top_clientes;
DROP PROCEDURE IF EXISTS logistica.sp_envios_cliente;
DROP PROCEDURE IF EXISTS logistica.sp_kpi_servicio;
DROP VIEW IF EXISTS logistica.vw_cartera_cliente;
DROP VIEW IF EXISTS logistica.vw_kpi_mensual;
DROP VIEW IF EXISTS logistica.vw_envios_detalle;
*/