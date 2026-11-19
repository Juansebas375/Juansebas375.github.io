/* =============================================================================
   LABORATORIO 1: ORACLE SQL AVANZADO
   (DDL, DML, DQL, Optimización y Concurrencia)

   AUTOR:        Juan Diaz
   CURSO:        Base de Datos 2
   FECHA:        17/11/2026
   HERRAMIENTA:  Oracle SQL Developer

   Los comandos están en el mismo orden en que se ejecutaron y que aparece en
   las capturas del informe. Cada bloque indica el número de captura.

   CÓMO EJECUTAR:
     - Bloques con varias sentencias: seleccionar el bloque (Ctrl+A en una hoja
       limpia) y pulsar F5 (Run Script).
     - Consultas sueltas: cursor dentro de la consulta y F9, o F5 si se quiere
       ver el resultado en "Salida de Script" como en las capturas.
     - La PARTE 7 (concurrencia) necesita DOS conexiones: "lab" (sesión 1) y
       "lab2" (sesión 2). No se ejecuta como archivo único: cada comando se
       pega en la hoja que se indica.
   ============================================================================= */


/* -----------------------------------------------------------------------------
   (OPCIONAL) LIMPIEZA - SOLO SI SE NECESITA REPETIR EL LABORATORIO DESDE CERO
   No ejecutar en la primera corrida: daría errores ORA-00942 / ORA-02289.
   -----------------------------------------------------------------------------
DROP VIEW VW_INVENTARIO_VALORIZADO;
DROP TABLE AUDITORIA_PRECIOS PURGE;
DROP TABLE LOG_ERRORES PURGE;
DROP TABLE PEDIDO PURGE;
DROP TABLE CLIENTE PURGE;
DROP TABLE PRODUCTO PURGE;
DROP TABLE CATEGORIA PURGE;
DROP SEQUENCE seq_categoria;
DROP SEQUENCE seq_producto;
DROP SEQUENCE seq_cliente;
DROP SEQUENCE seq_pedido;
DROP SEQUENCE seq_log;
----------------------------------------------------------------------------- */


-- =============================================================================
-- PARTE 1: DDL - SECUENCIAS, TABLAS E ÍNDICES (3FN)         [Capturas 1, 2 y 3]
-- Hoja "lab", Ctrl+A y F5. La salida es larga: se capturó en tres partes.
-- =============================================================================
CREATE SEQUENCE seq_categoria START WITH 1 INCREMENT BY 1;
CREATE SEQUENCE seq_producto  START WITH 101 INCREMENT BY 1;
CREATE SEQUENCE seq_cliente   START WITH 501 INCREMENT BY 1;
CREATE SEQUENCE seq_pedido    START WITH 1001 INCREMENT BY 1;
CREATE SEQUENCE seq_log       START WITH 1 INCREMENT BY 1;

CREATE TABLE CATEGORIA (
    id_categoria NUMBER PRIMARY KEY,
    nombre       VARCHAR2(50) NOT NULL UNIQUE
);

CREATE TABLE PRODUCTO (
    id_producto     NUMBER PRIMARY KEY,
    codigo          VARCHAR2(20) NOT NULL UNIQUE,
    nombre          VARCHAR2(100) NOT NULL,
    id_categoria    NUMBER NOT NULL,
    precio_unitario NUMBER(12, 2) NOT NULL CHECK (precio_unitario > 0),
    costo_unitario  NUMBER(12, 2) NOT NULL CHECK (costo_unitario > 0),
    stock_actual    NUMBER(8) DEFAULT 0 NOT NULL CHECK (stock_actual >= 0),
    stock_minimo    NUMBER(8) DEFAULT 5 NOT NULL,
    activo          CHAR(1) DEFAULT 'S' CHECK (activo IN ('S', 'N')),
    CONSTRAINT fk_prod_categoria FOREIGN KEY (id_categoria) REFERENCES CATEGORIA(id_categoria)
);

CREATE TABLE CLIENTE (
    id_cliente    NUMBER PRIMARY KEY,
    nombre        VARCHAR2(100) NOT NULL,
    email         VARCHAR2(100) UNIQUE,
    cupo_credito  NUMBER(12, 2) DEFAULT 1000000 NOT NULL,
    fecha_ingreso DATE DEFAULT SYSDATE NOT NULL
);

CREATE TABLE PEDIDO (
    id_pedido    NUMBER PRIMARY KEY,
    id_cliente   NUMBER NOT NULL,
    fecha_pedido DATE DEFAULT SYSDATE NOT NULL,
    estado       VARCHAR2(20) DEFAULT 'BORRADOR' CHECK (estado IN ('BORRADOR', 'COMPLETADO', 'CANCELADO')),
    total        NUMBER(12, 2) DEFAULT 0 NOT NULL,
    CONSTRAINT fk_ped_cliente FOREIGN KEY (id_cliente) REFERENCES CLIENTE(id_cliente)
);

CREATE TABLE AUDITORIA_PRECIOS (
    id_auditoria    NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_producto     NUMBER NOT NULL,
    accion          VARCHAR2(20) NOT NULL,
    precio_anterior NUMBER(12, 2),
    precio_nuevo    NUMBER(12, 2),
    usuario_bd      VARCHAR2(50) NOT NULL,
    fecha_registro  DATE DEFAULT SYSDATE NOT NULL
);

CREATE TABLE LOG_ERRORES (
    id_log       NUMBER PRIMARY KEY,
    origen       VARCHAR2(100),
    codigo_error NUMBER,
    mensaje      VARCHAR2(500),
    detalle      VARCHAR2(500),
    usuario_bd   VARCHAR2(40),
    fecha_log    TIMESTAMP
);

-- Índices (convención ix_...): evitan bloqueos TM sobre la tabla hija y aceleran filtros
CREATE INDEX ix_prod_categoria ON PRODUCTO(id_categoria);
CREATE INDEX ix_ped_cliente_fecha ON PEDIDO(id_cliente, fecha_pedido);


-- =============================================================================
-- PARTE 2: VERIFICACIÓN DE ESTRUCTURAS                      [Capturas 4 y 5]
-- Hoja "lab~1", Ctrl+A y F5. Resultado esperado: 16 filas seleccionadas
-- (6 tablas, 6 secuencias [una ISEQ$$ la crea Oracle por el IDENTITY],
--  2 índices y 2 llaves foráneas).
-- =============================================================================
SELECT 'TABLA' AS tipo, table_name AS nombre, CAST(NULL AS VARCHAR2(30)) AS detalle
FROM user_tables
WHERE table_name IN ('CATEGORIA','PRODUCTO','CLIENTE','PEDIDO','AUDITORIA_PRECIOS','LOG_ERRORES')
UNION ALL
SELECT 'SECUENCIA', sequence_name, NULL FROM user_sequences
UNION ALL
SELECT 'INDICE', index_name, table_name FROM user_indexes WHERE index_name LIKE 'IX_%'
UNION ALL
SELECT 'FK', constraint_name, table_name FROM user_constraints WHERE constraint_type = 'R'
ORDER BY 1, 2;


-- =============================================================================
-- PARTE 3: DML - CARGA DE DATOS Y COMMIT                     [Capturas 6 y 7]
-- Hoja "lab~2", Ctrl+A y F5. Salen 13 líneas "1 fila insertadas" y al final
-- "Confirmación terminada".
-- =============================================================================
INSERT INTO CATEGORIA VALUES (seq_categoria.NEXTVAL, 'Servidores');
INSERT INTO CATEGORIA VALUES (seq_categoria.NEXTVAL, 'Periféricos');
INSERT INTO CATEGORIA VALUES (seq_categoria.NEXTVAL, 'Almacenamiento');

INSERT INTO PRODUCTO VALUES (seq_producto.NEXTVAL, 'SRV-01', 'Servidor Rack PowerEdge', 1, 18500000, 14000000, 10, 3, 'S');
INSERT INTO PRODUCTO VALUES (seq_producto.NEXTVAL, 'PER-01', 'Monitor 27 4K IPS', 2, 1200000, 850000, 15, 5, 'S');
INSERT INTO PRODUCTO VALUES (seq_producto.NEXTVAL, 'PER-02', 'Teclado Mecánico Industrial', 2, 450000, 280000, 4, 5, 'S');
INSERT INTO PRODUCTO VALUES (seq_producto.NEXTVAL, 'ALM-01', 'Unidad SSD NVMe 2TB', 3, 780000, 520000, 25, 8, 'S');

INSERT INTO CLIENTE VALUES (seq_cliente.NEXTVAL, 'Ana Ruiz', 'ana.ruiz@empresa.co', 25000000, TO_DATE('2025-02-10', 'YYYY-MM-DD'));
INSERT INTO CLIENTE VALUES (seq_cliente.NEXTVAL, 'Carlos Mendoza', 'c.mendoza@tech.co', 5000000, TO_DATE('2025-06-15', 'YYYY-MM-DD'));
INSERT INTO CLIENTE VALUES (seq_cliente.NEXTVAL, 'Logística Global SAS', NULL, 40000000, TO_DATE('2026-01-20', 'YYYY-MM-DD'));

INSERT INTO PEDIDO VALUES (seq_pedido.NEXTVAL, 501, TO_DATE('2026-10-05', 'YYYY-MM-DD'), 'COMPLETADO', 19700000);
INSERT INTO PEDIDO VALUES (seq_pedido.NEXTVAL, 501, TO_DATE('2026-11-01', 'YYYY-MM-DD'), 'COMPLETADO', 1200000);
INSERT INTO PEDIDO VALUES (seq_pedido.NEXTVAL, 502, TO_DATE('2026-11-10', 'YYYY-MM-DD'), 'BORRADOR', 450000);

COMMIT;


-- =============================================================================
-- PARTE 3b: REVISIÓN DE LOS DATOS CARGADOS                  [Capturas 8 y 9]
-- Hoja "lab~3", Ctrl+A y F5. La salida es ancha: se capturó en dos partes
-- (columnas de la izquierda y columnas de la derecha).
-- =============================================================================
SELECT * FROM CATEGORIA;
SELECT * FROM PRODUCTO;
SELECT * FROM CLIENTE;
SELECT * FROM PEDIDO;


-- =============================================================================
-- PARTE 4: CONSULTAS AVANZADAS (JOINs, GROUP BY, HAVING, CTE, NULOS)
-- Cada consulta en su propia hoja, ejecutada con F5.
-- =============================================================================

-- 3.1 INNER JOIN, WHERE, GROUP BY, HAVING y manejo de nulos (NVL/COALESCE)
-- Hoja "lab~4"                                                    [Captura 10]
-- Resultado: solo ANA RUIZ (501), 2 pedidos, 20900000, ticket 10450000.
SELECT
    c.id_cliente,
    UPPER(c.nombre) AS cliente,
    NVL(c.email, 'SIN CORREO REGISTRADO') AS contacto,
    COUNT(p.id_pedido) AS total_pedidos,
    COALESCE(SUM(p.total), 0) AS monto_acumulado,
    ROUND(AVG(p.total), 2) AS ticket_promedio
FROM CLIENTE c
INNER JOIN PEDIDO p ON c.id_cliente = p.id_cliente
WHERE p.estado = 'COMPLETADO'
  AND p.fecha_pedido >= TO_DATE('2026-01-01', 'YYYY-MM-DD')
GROUP BY c.id_cliente, c.nombre, c.email
HAVING SUM(p.total) > 1000000
ORDER BY monto_acumulado DESC;


-- 3.2a CTE (WITH): productos con precio superior al promedio de su categoría
-- Hoja "lab~5"                                           [Capturas 11 y 12]
-- Resultado: PER-01, Monitor 27 4K IPS, Periféricos, 1200000, promedio 825000.
WITH promedio_categoria AS (
    SELECT id_categoria, ROUND(AVG(precio_unitario), 2) AS avg_precio
    FROM PRODUCTO
    GROUP BY id_categoria
)
SELECT
    pr.codigo,
    pr.nombre,
    cat.nombre AS categoria,
    pr.precio_unitario,
    pc.avg_precio AS promedio_de_su_categoria
FROM PRODUCTO pr
INNER JOIN CATEGORIA cat ON pr.id_categoria = cat.id_categoria
INNER JOIN promedio_categoria pc ON pr.id_categoria = pc.id_categoria
WHERE pr.precio_unitario > pc.avg_precio;


-- 3.2b Subconsulta correlacionada: misma pregunta, sin CTE
-- Hoja "lab~6"                                                    [Captura 13]
-- Resultado: PER-01, Monitor 27 4K IPS, 1200000.
SELECT pr.codigo, pr.nombre, pr.precio_unitario
FROM PRODUCTO pr
WHERE pr.precio_unitario > (
    SELECT AVG(p2.precio_unitario)
    FROM PRODUCTO p2
    WHERE p2.id_categoria = pr.id_categoria
);


-- 3.3 NOT EXISTS (evita el problema de nulos de NOT IN): clientes sin pedidos completados
-- Hoja "lab~7"                                                    [Captura 14]
-- Resultado: 502 Carlos Mendoza (5000000) y 503 Logística Global SAS (40000000).
SELECT c.id_cliente, c.nombre, c.cupo_credito
FROM CLIENTE c
WHERE NOT EXISTS (
    SELECT 1
    FROM PEDIDO p
    WHERE p.id_cliente = c.id_cliente
      AND p.estado = 'COMPLETADO'
);


-- =============================================================================
-- PARTE 5: VISTA VW_INVENTARIO_VALORIZADO
-- =============================================================================

-- Creación de la vista. Hoja "lab~8"                              [Captura 15]
CREATE OR REPLACE VIEW VW_INVENTARIO_VALORIZADO AS
SELECT
    cat.nombre AS categoria,
    p.codigo,
    p.nombre AS producto,
    p.stock_actual,
    p.precio_unitario,
    (p.stock_actual * p.precio_unitario) AS valor_inventario,
    CASE
        WHEN p.stock_actual < p.stock_minimo THEN 'ALERTA REABASTECER'
        ELSE 'STOCK OK'
    END AS estado_alerta
FROM PRODUCTO p
INNER JOIN CATEGORIA cat ON p.id_categoria = cat.id_categoria;

-- Consulta a la vista. Hoja "lab~9"                       [Capturas 16 y 17]
-- 4 filas; valores 185000000, 18000000, 1800000 y 19500000; solo PER-02 en ALERTA.
SELECT * FROM VW_INVENTARIO_VALORIZADO;


-- =============================================================================
-- PARTE 6: OPTIMIZACIÓN Y TRANSACCIONES
-- =============================================================================

-- Plan de ejecución. Hoja "lab~10", Ctrl+A y F5                   [Captura 18]
-- Resultado: INDEX RANGE SCAN sobre IX_PED_CLIENTE_FECHA, Cost 2, Rows 2.
EXEC DBMS_STATS.GATHER_TABLE_STATS(USER, 'PEDIDO');

EXPLAIN PLAN FOR
SELECT * FROM PEDIDO WHERE id_cliente = 501 AND fecha_pedido >= SYSDATE - 60;

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY);


-- Plan forzando el índice (hint). Hoja "lab~11", Ctrl+A y F5
-- NOTA: este plan se ejecutó, pero NO aparece en el informe en PDF.
-- Resultado: mismo plan hash (1587903345); Oracle ya elegía ese índice por sí solo.
EXPLAIN PLAN FOR
SELECT /*+ INDEX(PEDIDO ix_ped_cliente_fecha) */ *
FROM PEDIDO WHERE id_cliente = 501 AND fecha_pedido >= SYSDATE - 60;

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY);


-- SAVEPOINT y ROLLBACK. Hoja "lab~12", Ctrl+A y F5                [Captura 19]
-- 1er SELECT: PER-01 precio 1320000, stock 15 (el ROLLBACK TO deshizo solo el stock).
-- 2do SELECT: PER-01 precio 1200000, stock 15 (el ROLLBACK final deshizo todo).
UPDATE PRODUCTO SET precio_unitario = precio_unitario * 1.10 WHERE codigo = 'PER-01';
SAVEPOINT sp_precio;
UPDATE PRODUCTO SET stock_actual = 0 WHERE codigo = 'PER-01';
ROLLBACK TO sp_precio;
SELECT codigo, precio_unitario, stock_actual FROM PRODUCTO WHERE codigo = 'PER-01';
ROLLBACK;
SELECT codigo, precio_unitario, stock_actual FROM PRODUCTO WHERE codigo = 'PER-01';


-- =============================================================================
-- PARTE 7: CONCURRENCIA - BLOQUEO DE FILAS CON DOS SESIONES
--
--   Sesión 1 = hoja de la conexión "lab"
--   Sesión 2 = hoja de la conexión "lab2" (conexión nueva, mismo usuario)
--
-- Cada comando va en la hoja indicada, en este orden. No hacer COMMIT en la
-- sesión 1 hasta el paso 7.6.
-- =============================================================================

-- 7.1 Verificar que son dos sesiones distintas (SID diferentes)
-- Hoja "lab~13" (sesión 1), resultado 11476                       [Captura 20]
-- Hoja "lab2"   (sesión 2), resultado 31073                       [Captura 21]
SELECT SYS_CONTEXT('USERENV','SID') AS sid FROM dual;

-- 7.2 SESIÓN 1 (lab): tomar el bloqueo, sin COMMIT                [Captura 22]
UPDATE PRODUCTO SET stock_actual = stock_actual - 1 WHERE codigo = 'SRV-01';

-- 7.3 SESIÓN 2 (lab2): lectura normal. Sigue viendo 10            [Captura 23]
SELECT codigo, stock_actual FROM PRODUCTO WHERE codigo = 'SRV-01';

-- 7.4 SESIÓN 2 (lab2): error inmediato con NOWAIT                 [Captura 24]
-- Resultado: ORA-00054: recurso ocupado y adquisición con NOWAIT especificado
SELECT * FROM PRODUCTO WHERE codigo = 'SRV-01' FOR UPDATE NOWAIT;

-- 7.5 SESIÓN 2 (lab2): UPDATE que queda esperando, sin resultado  [Captura 25]
UPDATE PRODUCTO SET stock_actual = stock_actual - 2 WHERE codigo = 'SRV-01';

-- 7.6 SESIÓN 1 (lab): liberar el bloqueo                          [Captura 26]
-- Al ejecutarlo, el UPDATE de la sesión 2 termina solo         [Captura 27]
-- ("1 fila actualizadas", tras 55,457 segundos de espera).
ROLLBACK;

-- 7.7 SESIÓN 2 (lab2): dejar los datos como estaban               [Captura 28]
-- Resultado: SRV-01 con stock 10.
ROLLBACK;
SELECT codigo, stock_actual FROM PRODUCTO WHERE codigo = 'SRV-01';
