-- ============================================================
-- LABORATORIO 2 - PL/SQL EN ORACLE
-- Caso de estudio: sistema de ventas de una drogueria
-- Estudiante: Juan Diaz
-- Curso:      Base de Datos 2
-- Herramienta: Oracle SQL Developer
-- ============================================================
-- Ejecutar el script por partes (cada parte termina con "/" o ";").
-- Los objetos usan el prefijo DG_ para no chocar con el laboratorio anterior.
-- ============================================================

-- ============================================================
-- Parte 0. Tablas, secuencia y datos de prueba
-- ============================================================
SET SERVEROUTPUT ON SIZE UNLIMITED;

CREATE TABLE DG_CATEGORIA (
    id_categoria NUMBER PRIMARY KEY,
    nombre       VARCHAR2(60) NOT NULL
);

CREATE TABLE DG_MEDICAMENTO (
    id_medicamento      NUMBER PRIMARY KEY,
    codigo              VARCHAR2(20) UNIQUE NOT NULL,
    nombre              VARCHAR2(80) NOT NULL,
    id_categoria        NUMBER REFERENCES DG_CATEGORIA(id_categoria),
    precio_venta        NUMBER(12,2) NOT NULL,
    costo_compra        NUMBER(12,2) NOT NULL,
    existencias         NUMBER DEFAULT 0 NOT NULL,
    existencias_minimas NUMBER DEFAULT 0 NOT NULL,
    estado              CHAR(1) DEFAULT 'A' CHECK (estado IN ('A','I'))
);

CREATE TABLE DG_CLIENTE (
    id_cliente      NUMBER PRIMARY KEY,
    nombre          VARCHAR2(80) NOT NULL,
    limite_credito  NUMBER(12,2) DEFAULT 0
);

CREATE TABLE DG_FACTURA (
    id_factura NUMBER PRIMARY KEY,
    id_cliente NUMBER REFERENCES DG_CLIENTE(id_cliente),
    total      NUMBER(12,2) DEFAULT 0,
    estado     VARCHAR2(15) DEFAULT 'PENDIENTE'
);

CREATE SEQUENCE seq_dg_log START WITH 1 INCREMENT BY 1 NOCACHE;

CREATE TABLE DG_LOG_ERRORES (
    id_log       NUMBER PRIMARY KEY,
    origen       VARCHAR2(100),
    codigo_error NUMBER,
    mensaje      VARCHAR2(500),
    detalle      VARCHAR2(500),
    usuario_bd   VARCHAR2(40),
    fecha_log    TIMESTAMP
);

CREATE TABLE DG_AUDITORIA_PRECIOS (
    id_aud          NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_medicamento  NUMBER,
    accion          VARCHAR2(20),
    precio_anterior NUMBER(12,2),
    precio_nuevo    NUMBER(12,2),
    usuario_bd      VARCHAR2(40),
    fecha_registro  DATE
);

INSERT INTO DG_CATEGORIA (id_categoria, nombre) VALUES (1, 'Analgésicos');
INSERT INTO DG_CATEGORIA (id_categoria, nombre) VALUES (2, 'Antibióticos');
INSERT INTO DG_CATEGORIA (id_categoria, nombre) VALUES (3, 'Cuidado personal');

INSERT INTO DG_MEDICAMENTO (id_medicamento, codigo, nombre, id_categoria, precio_venta, costo_compra, existencias, existencias_minimas, estado)
VALUES (201, 'ANA-01', 'Acetaminofén 500 mg x100', 1, 18000, 12000, 40, 10, 'A');
INSERT INTO DG_MEDICAMENTO (id_medicamento, codigo, nombre, id_categoria, precio_venta, costo_compra, existencias, existencias_minimas, estado)
VALUES (202, 'ANT-01', 'Amoxicilina 500 mg x21', 2, 32000, 22000, 6, 10, 'A');
INSERT INTO DG_MEDICAMENTO (id_medicamento, codigo, nombre, id_categoria, precio_venta, costo_compra, existencias, existencias_minimas, estado)
VALUES (203, 'ANT-02', 'Azitromicina 500 mg x3', 2, 45000, 31000, 25, 8, 'A');
INSERT INTO DG_MEDICAMENTO (id_medicamento, codigo, nombre, id_categoria, precio_venta, costo_compra, existencias, existencias_minimas, estado)
VALUES (204, 'CUI-01', 'Protector solar FPS 50', 3, 52000, 38000, 3, 5, 'A');

INSERT INTO DG_CLIENTE (id_cliente, nombre, limite_credito) VALUES (701, 'Clínica San Rafael', 8000000);
INSERT INTO DG_CLIENTE (id_cliente, nombre, limite_credito) VALUES (702, 'Droguería El Remedio', 3000000);

INSERT INTO DG_FACTURA (id_factura, id_cliente, total, estado) VALUES (1, 701, 1500000, 'PENDIENTE');
INSERT INTO DG_FACTURA (id_factura, id_cliente, total, estado) VALUES (2, 701,  800000, 'PENDIENTE');
INSERT INTO DG_FACTURA (id_factura, id_cliente, total, estado) VALUES (3, 702,  400000, 'PAGADA');

COMMIT;

SELECT * FROM DG_MEDICAMENTO;
SELECT * FROM DG_CLIENTE;
SELECT * FROM DG_FACTURA;

-- ============================================================
-- Parte 1. Procedimiento de auditoría autónoma
-- ============================================================

CREATE OR REPLACE PROCEDURE SP_DG_REGISTRAR_ERROR (
    p_origen  IN VARCHAR2,
    p_codigo  IN NUMBER,
    p_mensaje IN VARCHAR2,
    p_detalle IN VARCHAR2 DEFAULT NULL
) IS
    PRAGMA AUTONOMOUS_TRANSACTION;
    v_id_log   DG_LOG_ERRORES.id_log%TYPE;
    vv_usuario VARCHAR2(40) := USER;
BEGIN
    SELECT seq_dg_log.NEXTVAL INTO v_id_log FROM DUAL;

    INSERT INTO DG_LOG_ERRORES (id_log, origen, codigo_error, mensaje, detalle, usuario_bd, fecha_log)
    VALUES (v_id_log, p_origen, p_codigo, SUBSTR(p_mensaje, 1, 500),
            SUBSTR(p_detalle, 1, 500), vv_usuario, SYSTIMESTAMP);

    COMMIT;
END SP_DG_REGISTRAR_ERROR;
/

-- ============================================================
-- 2.1 Creación de los triggers
-- ============================================================
-- Trigger 1: el precio de venta debe superar el costo en al menos 10%
CREATE OR REPLACE TRIGGER TGR_DG_BIU_margen
BEFORE INSERT OR UPDATE OF precio_venta, costo_compra ON DG_MEDICAMENTO
FOR EACH ROW
BEGIN
    IF :NEW.precio_venta < (:NEW.costo_compra * 1.10) THEN
        RAISE_APPLICATION_ERROR(
            -20010,
            'Regla violada: el precio de venta ($' || :NEW.precio_venta ||
            ') debe superar al menos en 10% al costo de compra ($' || :NEW.costo_compra || ').'
        );
    END IF;
END TGR_DG_BIU_margen;
/

-- Trigger 2: guarda en auditoría cada cambio de precio y cada borrado
CREATE OR REPLACE TRIGGER TGR_DG_AUD_precio
AFTER UPDATE OF precio_venta OR DELETE ON DG_MEDICAMENTO
FOR EACH ROW
DECLARE
    vv_accion VARCHAR2(20);
    vd_fecha  DATE := SYSDATE;
BEGIN
    IF UPDATING THEN
        vv_accion := 'UPDATE';
    ELSE
        vv_accion := 'DELETE';
    END IF;

    INSERT INTO DG_AUDITORIA_PRECIOS (
        id_medicamento, accion, precio_anterior, precio_nuevo, usuario_bd, fecha_registro
    ) VALUES (
        :OLD.id_medicamento, vv_accion, :OLD.precio_venta, :NEW.precio_venta, USER, vd_fecha
    );
END TGR_DG_AUD_precio;
/

-- ============================================================
-- 2.2 Prueba de la regla de margen
-- ============================================================
-- El costo es 12000, el mínimo permitido es 13200. Esto debe fallar:
UPDATE DG_MEDICAMENTO SET precio_venta = 13000 WHERE codigo = 'ANA-01';

-- ============================================================
-- 2.3 Prueba de la auditoría y del ROLLBACK
-- ============================================================
-- Un cambio de precio válido y un borrado
UPDATE DG_MEDICAMENTO SET precio_venta = 20000 WHERE codigo = 'ANA-01';
DELETE FROM DG_MEDICAMENTO WHERE codigo = 'CUI-01';

-- La auditoría debe tener 2 filas (UPDATE y DELETE)
SELECT id_medicamento, accion, precio_anterior, precio_nuevo, usuario_bd
FROM DG_AUDITORIA_PRECIOS
ORDER BY id_aud;

-- Deshacemos todo
ROLLBACK;

-- Después del ROLLBACK la auditoría queda vacía y el medicamento vuelve
SELECT COUNT(*) AS filas_auditoria FROM DG_AUDITORIA_PRECIOS;
SELECT codigo, precio_venta FROM DG_MEDICAMENTO WHERE codigo IN ('ANA-01','CUI-01');

-- ============================================================
-- 3.1 Función fn_dg_credito_disponible
-- ============================================================
CREATE OR REPLACE FUNCTION fn_dg_credito_disponible (
    p_id_cliente IN DG_CLIENTE.id_cliente%TYPE
) RETURN NUMBER IS
    v_limite      DG_CLIENTE.limite_credito%TYPE;
    v_pendiente   NUMBER(12,2) := 0;
BEGIN
    SELECT limite_credito INTO v_limite
    FROM DG_CLIENTE
    WHERE id_cliente = p_id_cliente;

    SELECT NVL(SUM(total), 0) INTO v_pendiente
    FROM DG_FACTURA
    WHERE id_cliente = p_id_cliente
      AND estado = 'PENDIENTE';

    RETURN v_limite - v_pendiente;
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RETURN -1;
END fn_dg_credito_disponible;
/

-- ============================================================
-- 3.2 Prueba de la función
-- ============================================================
SELECT fn_dg_credito_disponible(701) AS credito_clinica,
       fn_dg_credito_disponible(702) AS credito_drogueria,
       fn_dg_credito_disponible(999) AS cliente_inexistente
FROM DUAL;

-- ============================================================
-- 3.3 Procedimiento SP_DG_AJUSTAR_EXISTENCIAS
-- ============================================================
CREATE OR REPLACE PROCEDURE SP_DG_AJUSTAR_EXISTENCIAS (
    p_id_medicamento IN  DG_MEDICAMENTO.id_medicamento%TYPE,
    p_tipo_mov       IN  VARCHAR2,
    p_cantidad       IN  NUMBER,
    p_saldo_final    OUT DG_MEDICAMENTO.existencias%TYPE
) IS
    v_existencias         DG_MEDICAMENTO.existencias%TYPE;
    vc_estado             DG_MEDICAMENTO.estado%TYPE;
    e_cantidad_invalida   EXCEPTION;
    e_stock_insuficiente  EXCEPTION;
    e_medicamento_inactivo EXCEPTION;
    e_tipo_invalido       EXCEPTION;
BEGIN
    IF p_cantidad <= 0 THEN
        RAISE e_cantidad_invalida;
    END IF;

    -- Bloquea la fila para que nadie más la modifique mientras se ajusta
    SELECT existencias, estado INTO v_existencias, vc_estado
    FROM DG_MEDICAMENTO
    WHERE id_medicamento = p_id_medicamento
    FOR UPDATE;

    IF vc_estado = 'I' THEN
        RAISE e_medicamento_inactivo;
    END IF;

    IF UPPER(p_tipo_mov) = 'ENTRADA' THEN
        p_saldo_final := v_existencias + p_cantidad;
    ELSIF UPPER(p_tipo_mov) = 'SALIDA' THEN
        IF v_existencias < p_cantidad THEN
            RAISE e_stock_insuficiente;
        END IF;
        p_saldo_final := v_existencias - p_cantidad;
    ELSE
        RAISE e_tipo_invalido;
    END IF;

    UPDATE DG_MEDICAMENTO
    SET existencias = p_saldo_final
    WHERE id_medicamento = p_id_medicamento;

EXCEPTION
    WHEN e_cantidad_invalida THEN
        SP_DG_REGISTRAR_ERROR('SP_DG_AJUSTAR_EXISTENCIAS', -20021, 'Cantidad menor o igual a cero', 'Medicamento ID: ' || p_id_medicamento);
        RAISE_APPLICATION_ERROR(-20021, 'Error: la cantidad a ajustar debe ser mayor a cero.');
    WHEN e_medicamento_inactivo THEN
        SP_DG_REGISTRAR_ERROR('SP_DG_AJUSTAR_EXISTENCIAS', -20022, 'Movimiento sobre medicamento inactivo', 'Medicamento ID: ' || p_id_medicamento);
        RAISE_APPLICATION_ERROR(-20022, 'Error: el medicamento está inactivo.');
    WHEN e_stock_insuficiente THEN
        SP_DG_REGISTRAR_ERROR('SP_DG_AJUSTAR_EXISTENCIAS', -20023, 'Existencias insuficientes para la salida', 'Existencias: ' || v_existencias || ', Solicitado: ' || p_cantidad);
        RAISE_APPLICATION_ERROR(-20023, 'Error: existencias insuficientes para realizar la salida.');
    WHEN e_tipo_invalido THEN
        SP_DG_REGISTRAR_ERROR('SP_DG_AJUSTAR_EXISTENCIAS', -20025, 'Tipo de movimiento inválido', 'Tipo recibido: ' || p_tipo_mov);
        RAISE_APPLICATION_ERROR(-20025, 'Error: tipo de movimiento inválido. Use ENTRADA o SALIDA.');
    WHEN NO_DATA_FOUND THEN
        SP_DG_REGISTRAR_ERROR('SP_DG_AJUSTAR_EXISTENCIAS', -20024, 'Medicamento no existe', 'Medicamento ID: ' || p_id_medicamento);
        RAISE_APPLICATION_ERROR(-20024, 'Error: el medicamento especificado no existe.');
END SP_DG_AJUSTAR_EXISTENCIAS;
/

-- ============================================================
-- 3.4 Prueba con ajustes exitosos
-- ============================================================
SET SERVEROUTPUT ON SIZE UNLIMITED;

DECLARE
    v_saldo DG_MEDICAMENTO.existencias%TYPE;
BEGIN
    SP_DG_AJUSTAR_EXISTENCIAS(202, 'ENTRADA', 20, v_saldo);
    DBMS_OUTPUT.PUT_LINE('Entrada de 20 unidades a ANT-01 -> saldo: ' || v_saldo);

    SP_DG_AJUSTAR_EXISTENCIAS(202, 'SALIDA', 4, v_saldo);
    DBMS_OUTPUT.PUT_LINE('Salida de 4 unidades a ANT-01 -> saldo: ' || v_saldo);
END;
/

SELECT codigo, nombre, existencias FROM DG_MEDICAMENTO WHERE id_medicamento = 202;

ROLLBACK;

SELECT codigo, nombre, existencias FROM DG_MEDICAMENTO WHERE id_medicamento = 202;

-- ============================================================
-- 4.1 Especificación del paquete
-- ============================================================
CREATE OR REPLACE PACKAGE PCK_DG_VENTAS AS
    FUNCTION fn_dg_calcular_descuento (p_monto IN NUMBER) RETURN NUMBER;
    PROCEDURE SP_DG_REPORTE_BAJO_MINIMO (p_id_categoria IN NUMBER);
    PROCEDURE SP_DG_ACTUALIZAR_PRECIOS_CAT (p_id_categoria IN NUMBER, p_porcentaje IN NUMBER);
END PCK_DG_VENTAS;
/

-- ============================================================
-- 4.2 Cuerpo del paquete
-- ============================================================

CREATE OR REPLACE PACKAGE BODY PCK_DG_VENTAS AS

    -- Descuento escalonado según el monto de la compra
    FUNCTION fn_dg_calcular_descuento (p_monto IN NUMBER) RETURN NUMBER IS
        v_descuento NUMBER(12,2) := 0;
    BEGIN
        IF p_monto >= 10000000 THEN
            v_descuento := p_monto * 0.12;
        ELSIF p_monto >= 2000000 THEN
            v_descuento := p_monto * 0.05;
        ELSE
            v_descuento := 0;
        END IF;
        RETURN ROUND(v_descuento, 2);
    END fn_dg_calcular_descuento;

    -- Cursor explícito con parámetro: OPEN - FETCH - CLOSE
    PROCEDURE SP_DG_REPORTE_BAJO_MINIMO (p_id_categoria IN NUMBER) IS
        CURSOR c_bajo_minimo (p_cat NUMBER) IS
            SELECT codigo, nombre, existencias, existencias_minimas
            FROM DG_MEDICAMENTO
            WHERE id_categoria = p_cat
              AND existencias < existencias_minimas
            ORDER BY codigo;
        r_med  c_bajo_minimo%ROWTYPE;
        v_cont NUMBER := 0;
    BEGIN
        DBMS_OUTPUT.PUT_LINE('--- MEDICAMENTOS BAJO EL MÍNIMO (Categoría: ' || p_id_categoria || ') ---');
        OPEN c_bajo_minimo(p_id_categoria);
        LOOP
            FETCH c_bajo_minimo INTO r_med;
            EXIT WHEN c_bajo_minimo%NOTFOUND;
            v_cont := v_cont + 1;
            DBMS_OUTPUT.PUT_LINE('Código: ' || r_med.codigo || ' | ' || r_med.nombre ||
                                 ' | Actual: ' || r_med.existencias ||
                                 ' | Mínimo: ' || r_med.existencias_minimas);
        END LOOP;
        CLOSE c_bajo_minimo;

        IF v_cont = 0 THEN
            DBMS_OUTPUT.PUT_LINE('Todos los medicamentos de la categoría cumplen el mínimo.');
        END IF;
    END SP_DG_REPORTE_BAJO_MINIMO;

    -- Cursor FOR LOOP: ajuste masivo de precios por categoría
    PROCEDURE SP_DG_ACTUALIZAR_PRECIOS_CAT (p_id_categoria IN NUMBER, p_porcentaje IN NUMBER) IS
        CURSOR c_medicamentos IS
            SELECT id_medicamento, nombre, precio_venta
            FROM DG_MEDICAMENTO
            WHERE id_categoria = p_id_categoria
            ORDER BY id_medicamento;
        v_nuevo_precio DG_MEDICAMENTO.precio_venta%TYPE;
    BEGIN
        FOR r_fila IN c_medicamentos LOOP
            v_nuevo_precio := ROUND(r_fila.precio_venta * (1 + (p_porcentaje / 100)), 2);

            UPDATE DG_MEDICAMENTO
            SET precio_venta = v_nuevo_precio
            WHERE id_medicamento = r_fila.id_medicamento;

            DBMS_OUTPUT.PUT_LINE('Actualizado: ' || r_fila.nombre ||
                                 ' | Antes: $' || r_fila.precio_venta ||
                                 ' -> Nuevo: $' || v_nuevo_precio);
        END LOOP;
    EXCEPTION
        WHEN OTHERS THEN
            SP_DG_REGISTRAR_ERROR('PCK_DG_VENTAS.SP_DG_ACTUALIZAR_PRECIOS_CAT', SQLCODE, SQLERRM,
                                  'Categoría: ' || p_id_categoria || ', Porcentaje: ' || p_porcentaje);
            RAISE;
    END SP_DG_ACTUALIZAR_PRECIOS_CAT;

END PCK_DG_VENTAS;
/

-- ============================================================
-- 4.3 Prueba de la función de descuento y del cursor explícito
-- ============================================================
SET SERVEROUTPUT ON SIZE UNLIMITED;

BEGIN
    DBMS_OUTPUT.PUT_LINE('Descuento sobre $12.000.000: ' || PCK_DG_VENTAS.fn_dg_calcular_descuento(12000000));
    DBMS_OUTPUT.PUT_LINE('Descuento sobre  $3.000.000: ' || PCK_DG_VENTAS.fn_dg_calcular_descuento(3000000));
    DBMS_OUTPUT.PUT_LINE('Descuento sobre    $500.000: ' || PCK_DG_VENTAS.fn_dg_calcular_descuento(500000));
    DBMS_OUTPUT.PUT_LINE(' ');
    PCK_DG_VENTAS.SP_DG_REPORTE_BAJO_MINIMO(2);
    PCK_DG_VENTAS.SP_DG_REPORTE_BAJO_MINIMO(3);
    PCK_DG_VENTAS.SP_DG_REPORTE_BAJO_MINIMO(1);
END;
/

-- ============================================================
-- 4.4 Prueba del cursor FOR LOOP junto con la auditoría
-- ============================================================
SET SERVEROUTPUT ON SIZE UNLIMITED;

BEGIN
    PCK_DG_VENTAS.SP_DG_ACTUALIZAR_PRECIOS_CAT(2, 10);
END;
/

SELECT id_medicamento, accion, precio_anterior, precio_nuevo
FROM DG_AUDITORIA_PRECIOS
ORDER BY id_aud;

ROLLBACK;

SELECT codigo, precio_venta FROM DG_MEDICAMENTO WHERE id_categoria = 2 ORDER BY codigo;

-- ============================================================
-- 5.1 Log vacío antes de empezar
-- ============================================================
SELECT COUNT(*) AS filas_en_log FROM DG_LOG_ERRORES;

-- ============================================================
-- 5.2 Bloque de pruebas
-- ============================================================
SET SERVEROUTPUT ON SIZE UNLIMITED;

DECLARE
    v_saldo DG_MEDICAMENTO.existencias%TYPE;
BEGIN
    DBMS_OUTPUT.PUT_LINE('============================================================');
    DBMS_OUTPUT.PUT_LINE('   PRUEBAS INTEGRALES - LABORATORIO 2 PL/SQL (DROGUERÍA)');
    DBMS_OUTPUT.PUT_LINE('============================================================');

    -- [1] Ajuste exitoso
    SP_DG_AJUSTAR_EXISTENCIAS(201, 'ENTRADA', 10, v_saldo);
    DBMS_OUTPUT.PUT_LINE('[1] Entrada de 10 unidades a ANA-01 -> saldo: ' || v_saldo);

    -- [2] Salida mayor a las existencias
    BEGIN
        SP_DG_AJUSTAR_EXISTENCIAS(202, 'SALIDA', 9999, v_saldo);
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('[2] Salida excesiva: ' || SQLERRM);
    END;

    -- [3] Cantidad inválida
    BEGIN
        SP_DG_AJUSTAR_EXISTENCIAS(201, 'ENTRADA', 0, v_saldo);
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('[3] Cantidad inválida: ' || SQLERRM);
    END;

    -- [4] Medicamento inexistente
    BEGIN
        SP_DG_AJUSTAR_EXISTENCIAS(999, 'ENTRADA', 5, v_saldo);
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('[4] Medicamento inexistente: ' || SQLERRM);
    END;

    -- [5] Tipo de movimiento inválido
    BEGIN
        SP_DG_AJUSTAR_EXISTENCIAS(201, 'TRASLADO', 5, v_saldo);
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('[5] Tipo inválido: ' || SQLERRM);
    END;

    -- [6] Medicamento inactivo
    BEGIN
        UPDATE DG_MEDICAMENTO SET estado = 'I' WHERE id_medicamento = 203;
        SP_DG_AJUSTAR_EXISTENCIAS(203, 'SALIDA', 1, v_saldo);
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('[6] Medicamento inactivo: ' || SQLERRM);
    END;

    -- [7] Un -30% hace que el trigger de margen bloquee el paquete
    BEGIN
        PCK_DG_VENTAS.SP_DG_ACTUALIZAR_PRECIOS_CAT(2, -30);
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('[7] Trigger de margen vía paquete: ' || SQLERRM);
    END;

    DBMS_OUTPUT.PUT_LINE('============================================================');
    ROLLBACK; -- deshace los cambios de datos, pero el log autónomo se conserva
END;
/

-- ============================================================
-- 5.3 Comprobación de que el log sobrevivió al ROLLBACK
-- ============================================================
SELECT id_log, origen, codigo_error, SUBSTR(mensaje, 1, 55) AS mensaje, detalle
FROM DG_LOG_ERRORES
ORDER BY id_log;

SELECT codigo, existencias, estado, precio_venta
FROM DG_MEDICAMENTO
ORDER BY codigo;

SELECT COUNT(*) AS filas_auditoria FROM DG_AUDITORIA_PRECIOS;
