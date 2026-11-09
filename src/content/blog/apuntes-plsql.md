---
title: "Apuntes Maestros de PL/SQL: Bloques, Cursores, Excepciones, Paquetes y Rendimiento"
description: "Guía práctica de PL/SQL en Oracle: estructura de bloques, variables, control de flujo, cursores, excepciones, procedimientos, funciones, paquetes, triggers, colecciones, BULK COLLECT, FORALL y SQL dinámico."
excerpt: "Guía práctica de PL/SQL en Oracle: bloques, cursores, excepciones, paquetes, triggers y optimización con BULK COLLECT."
publishDate: "Nov 09 2026"
tags: ["plsql", "oracle", "databases", "procedimientos", "triggers", "cursores", "bulk-collect"]
---

# 🧩 Guía Completa de PL/SQL: De tu Primer Bloque a Código de Producción

---

## 1. ¿Qué es PL/SQL y Cómo se Organiza?

**PL/SQL** (*Procedural Language / SQL*) es la extensión procedural de Oracle sobre SQL. Permite escribir lógica (variables, condiciones, bucles, manejo de errores) **dentro de la base de datos**, junto a los datos, reduciendo viajes de red entre la aplicación y el motor.

**¿Por qué usarlo?**

* **Menos tráfico de red:** un bloque completo viaja en una sola llamada en lugar de muchas sentencias sueltas.
* **Lógica centralizada:** las reglas de negocio viven en un solo lugar, sin importar qué aplicación se conecte.
* **Seguridad:** se puede dar permiso para ejecutar un procedimiento sin dar acceso directo a las tablas.
* **Integración nativa con SQL:** las sentencias SQL se escriben directamente dentro del código.

### Estructura de un Bloque

Todo programa PL/SQL se construye con **bloques** de cuatro secciones:

| Sección | ¿Obligatoria? | Propósito |
| :--- | :--- | :--- |
| `DECLARE` | No | Declara variables, constantes, cursores y excepciones propias. |
| `BEGIN` | **Sí** | Contiene las instrucciones ejecutables. |
| `EXCEPTION` | No | Captura y trata los errores ocurridos en `BEGIN`. |
| `END;` | **Sí** | Cierra el bloque. |

```sql
SET SERVEROUTPUT ON;

DECLARE
    v_nombre   VARCHAR2(50) := 'Ana';
    v_edad     NUMBER(3)    := 25;
BEGIN
    DBMS_OUTPUT.PUT_LINE('Hola ' || v_nombre || ', tienes ' || v_edad || ' años');
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Error: ' || SQLERRM);
END;
/
```

> **Detalle clave:** la barra `/` en una línea sola le dice a SQL*Plus, SQL Developer o SQLcl que ejecute el bloque. Sin ella, el bloque no corre. `SET SERVEROUTPUT ON` activa la salida de `DBMS_OUTPUT.PUT_LINE`.

### Tipos de Bloques y Unidades

* **Bloque anónimo:** no tiene nombre, no se guarda en la base de datos, se ejecuta una vez (como el ejemplo anterior).
* **Procedimiento (`PROCEDURE`):** unidad con nombre almacenada en la BD. Ejecuta acciones; no está obligado a devolver valor.
* **Función (`FUNCTION`):** unidad con nombre que **siempre retorna un valor** y puede usarse dentro de un `SELECT`.
* **Paquete (`PACKAGE`):** contenedor que agrupa procedimientos, funciones, variables y tipos relacionados.
* **Trigger:** bloque que se dispara automáticamente ante un evento (DML, DDL o de sistema).

---

## 2. Variables, Constantes y Tipos de Datos

### Declaración Básica

```sql
DECLARE
    v_total      NUMBER(10,2)  := 0;                    -- variable con valor inicial
    v_activo     BOOLEAN       := TRUE;                 -- BOOLEAN existe en PL/SQL, no en columnas SQL
    c_iva        CONSTANT NUMBER(4,2) := 0.19;          -- constante: no se puede modificar
    v_fecha      DATE          := SYSDATE;
    v_texto      VARCHAR2(100) NOT NULL := 'valor';     -- NOT NULL exige inicializar
BEGIN
    v_total := 1000 * (1 + c_iva);
    DBMS_OUTPUT.PUT_LINE('Total con IVA: ' || v_total);
END;
/
```

### Tipos de Datos Más Usados

| Tipo | Uso |
| :--- | :--- |
| `VARCHAR2(n)` | Texto de longitud variable. |
| `NUMBER(p,s)` | Números con precisión `p` y escala `s`. |
| `PLS_INTEGER` | Entero binario rápido, ideal para contadores e índices de bucle. |
| `DATE` / `TIMESTAMP` | Fecha (con hora) y fecha con fracciones de segundo. |
| `BOOLEAN` | `TRUE`, `FALSE`, `NULL`. Solo existe dentro de PL/SQL. |
| `CLOB` / `BLOB` | Texto y binarios de gran tamaño. |

### Anclaje de Tipos: `%TYPE` y `%ROWTYPE`

Evitan que el código se rompa si cambia la definición de una columna:

* **`%TYPE`:** hereda el tipo de **una** columna o variable.
* **`%ROWTYPE`:** hereda la estructura de **toda una fila** (tabla o cursor).

```sql
DECLARE
    v_salario  empleado.salario%TYPE;       -- mismo tipo que la columna salario
    r_emp      empleado%ROWTYPE;            -- registro con todas las columnas de empleado
BEGIN
    SELECT *
      INTO r_emp
      FROM empleado
     WHERE id_empleado = 100;

    v_salario := r_emp.salario;
    DBMS_OUTPUT.PUT_LINE(r_emp.nombre || ' gana ' || v_salario);
END;
/
```

### Registros Definidos por el Usuario

```sql
DECLARE
    TYPE t_persona IS RECORD (
        nombre   VARCHAR2(50),
        edad     NUMBER(3)
    );
    v_p t_persona;
BEGIN
    v_p.nombre := 'Luis';
    v_p.edad   := 30;
    DBMS_OUTPUT.PUT_LINE(v_p.nombre || ' - ' || v_p.edad);
END;
/
```

### Ámbito y Bloques Anidados

Una variable declarada en un bloque es visible en sus bloques internos, pero no al revés. Si un bloque interno declara una variable con el mismo nombre, esta **oculta** a la externa. Para acceder a la externa se usa una etiqueta: `<<externo>>` y luego `externo.variable`.

---

## 3. Control de Flujo

### IF / ELSIF / ELSE

```sql
DECLARE
    v_nota NUMBER := 4.2;
BEGIN
    IF v_nota >= 4.5 THEN
        DBMS_OUTPUT.PUT_LINE('Excelente');
    ELSIF v_nota >= 3.0 THEN
        DBMS_OUTPUT.PUT_LINE('Aprobado');
    ELSE
        DBMS_OUTPUT.PUT_LINE('Reprobado');
    END IF;
END;
/
```

> **Ojo:** se escribe `ELSIF` (sin la segunda E), y toda condición con `NULL` se evalúa como `UNKNOWN`, que cuenta como falso en el `IF`.

### CASE

```sql
DECLARE
    v_dia   NUMBER := 3;
    v_texto VARCHAR2(20);
BEGIN
    -- CASE simple (compara contra un valor)
    v_texto := CASE v_dia
                   WHEN 1 THEN 'Lunes'
                   WHEN 2 THEN 'Martes'
                   WHEN 3 THEN 'Miércoles'
                   ELSE 'Otro'
               END;

    -- CASE buscado (evalúa condiciones)
    CASE
        WHEN v_dia BETWEEN 1 AND 5 THEN DBMS_OUTPUT.PUT_LINE('Día hábil');
        ELSE DBMS_OUTPUT.PUT_LINE('Fin de semana');
    END CASE;

    DBMS_OUTPUT.PUT_LINE(v_texto);
END;
/
```

> Una **sentencia** `CASE` sin `ELSE` y sin coincidencia lanza `CASE_NOT_FOUND` (ORA-06592). La **expresión** `CASE` devuelve `NULL` en ese caso.

### Bucles

| Bucle | Cuándo usarlo |
| :--- | :--- |
| `LOOP ... EXIT WHEN` | Cuando la condición de salida se decide dentro del cuerpo. |
| `WHILE ... LOOP` | Cuando se evalúa una condición **antes** de cada vuelta. |
| `FOR i IN a..b LOOP` | Cuando se conoce el rango de iteraciones. |

```sql
DECLARE
    v_i NUMBER := 1;
BEGIN
    -- LOOP básico
    LOOP
        EXIT WHEN v_i > 3;
        DBMS_OUTPUT.PUT_LINE('LOOP: ' || v_i);
        v_i := v_i + 1;
    END LOOP;

    -- WHILE
    v_i := 1;
    WHILE v_i <= 3 LOOP
        DBMS_OUTPUT.PUT_LINE('WHILE: ' || v_i);
        v_i := v_i + 1;
    END LOOP;

    -- FOR (la variable se declara sola y es de solo lectura)
    FOR i IN 1..3 LOOP
        CONTINUE WHEN i = 2;                   -- salta a la siguiente iteración
        DBMS_OUTPUT.PUT_LINE('FOR: ' || i);
    END LOOP;

    -- FOR en reversa
    FOR i IN REVERSE 1..3 LOOP
        DBMS_OUTPUT.PUT_LINE('REVERSE: ' || i);
    END LOOP;
END;
/
```

* **`EXIT`:** sale del bucle. **`CONTINUE`:** pasa a la siguiente vuelta.
* Los bucles pueden llevar **etiquetas** (`<<externo>>`) para salir de uno exterior con `EXIT externo;`.

---

## 4. SQL Dentro de PL/SQL

### SELECT ... INTO

Trae **exactamente una fila** a variables. Si no hay fila lanza `NO_DATA_FOUND`; si hay más de una lanza `TOO_MANY_ROWS`.

```sql
DECLARE
    v_nombre  empleado.nombre%TYPE;
    v_salario empleado.salario%TYPE;
BEGIN
    SELECT nombre, salario
      INTO v_nombre, v_salario
      FROM empleado
     WHERE id_empleado = 100;

    DBMS_OUTPUT.PUT_LINE(v_nombre || ': ' || v_salario);
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        DBMS_OUTPUT.PUT_LINE('No existe el empleado');
    WHEN TOO_MANY_ROWS THEN
        DBMS_OUTPUT.PUT_LINE('La consulta devolvió más de una fila');
END;
/
```

> **Truco:** un `SELECT COUNT(*) INTO ...` o con función agregada **nunca** lanza `NO_DATA_FOUND`, porque siempre devuelve una fila.

### DML y Atributos del Cursor Implícito

Oracle abre un **cursor implícito** para cada `INSERT`, `UPDATE`, `DELETE` y `SELECT INTO`. Se consulta con el prefijo `SQL%`:

| Atributo | Significado |
| :--- | :--- |
| `SQL%ROWCOUNT` | Número de filas afectadas por la última sentencia DML. |
| `SQL%FOUND` | `TRUE` si afectó al menos una fila. |
| `SQL%NOTFOUND` | `TRUE` si no afectó ninguna fila. |
| `SQL%ISOPEN` | Siempre `FALSE` en cursores implícitos (Oracle los cierra solo). |

```sql
BEGIN
    UPDATE empleado
       SET salario = salario * 1.10
     WHERE id_departamento = 10;

    DBMS_OUTPUT.PUT_LINE('Filas actualizadas: ' || SQL%ROWCOUNT);

    IF SQL%NOTFOUND THEN
        DBMS_OUTPUT.PUT_LINE('El departamento no tiene empleados');
    END IF;

    COMMIT;
END;
/
```

### Cláusula RETURNING INTO

Recupera valores de la fila afectada sin hacer un segundo `SELECT`:

```sql
DECLARE
    v_nuevo_id empleado.id_empleado%TYPE;
BEGIN
    INSERT INTO empleado (id_empleado, nombre, salario)
    VALUES (seq_empleado.NEXTVAL, 'Marta', 3000000)
    RETURNING id_empleado INTO v_nuevo_id;

    DBMS_OUTPUT.PUT_LINE('ID generado: ' || v_nuevo_id);
END;
/
```

---

## 5. Cursores

Un **cursor** es un puntero a la zona de memoria donde Oracle guarda el resultado de una consulta de varias filas, para procesarla **fila a fila**.

### Cursor Explícito (Ciclo Manual)

Cuatro pasos: **declarar → abrir → recuperar → cerrar**.

```sql
DECLARE
    CURSOR c_emp IS
        SELECT id_empleado, nombre, salario
          FROM empleado
         WHERE id_departamento = 10;

    v_id      empleado.id_empleado%TYPE;
    v_nombre  empleado.nombre%TYPE;
    v_salario empleado.salario%TYPE;
BEGIN
    OPEN c_emp;
    LOOP
        FETCH c_emp INTO v_id, v_nombre, v_salario;
        EXIT WHEN c_emp%NOTFOUND;
        DBMS_OUTPUT.PUT_LINE(v_id || ' - ' || v_nombre || ' - ' || v_salario);
    END LOOP;
    CLOSE c_emp;
END;
/
```

### Atributos de Cursores Explícitos

| Atributo | Significado |
| :--- | :--- |
| `%FOUND` | `TRUE` si el último `FETCH` devolvió una fila. |
| `%NOTFOUND` | `TRUE` si el último `FETCH` no devolvió fila (condición de salida típica). |
| `%ISOPEN` | `TRUE` si el cursor está abierto. |
| `%ROWCOUNT` | Número de filas recuperadas hasta el momento. |

### Cursor FOR LOOP (La Forma Recomendada)

Abre, recupera, cierra y declara el registro automáticamente. Menos código y menos errores:

```sql
BEGIN
    FOR r IN (SELECT nombre, salario FROM empleado WHERE id_departamento = 10) LOOP
        DBMS_OUTPUT.PUT_LINE(r.nombre || ': ' || r.salario);
    END LOOP;
END;
/
```

### Cursor con Parámetros

```sql
DECLARE
    CURSOR c_emp (p_depto NUMBER, p_min NUMBER) IS
        SELECT nombre, salario
          FROM empleado
         WHERE id_departamento = p_depto
           AND salario >= p_min;
BEGIN
    FOR r IN c_emp(10, 2000000) LOOP
        DBMS_OUTPUT.PUT_LINE(r.nombre);
    END LOOP;
END;
/
```

### FOR UPDATE y WHERE CURRENT OF

Bloquea las filas del cursor y permite modificar justo la fila actual:

```sql
DECLARE
    CURSOR c_emp IS
        SELECT id_empleado, salario
          FROM empleado
         WHERE id_departamento = 10
           FOR UPDATE OF salario NOWAIT;
BEGIN
    FOR r IN c_emp LOOP
        UPDATE empleado
           SET salario = r.salario * 1.05
         WHERE CURRENT OF c_emp;
    END LOOP;
    COMMIT;
END;
/
```

### REF CURSOR (Cursores Dinámicos)

Cursor cuya consulta se decide en tiempo de ejecución; muy usado para **devolver resultados a una aplicación**:

```sql
CREATE OR REPLACE PROCEDURE prc_listar_empleados (
    p_depto  IN  NUMBER,
    p_result OUT SYS_REFCURSOR
) AS
BEGIN
    OPEN p_result FOR
        SELECT id_empleado, nombre, salario
          FROM empleado
         WHERE id_departamento = p_depto;
END prc_listar_empleados;
/
```

---

## 6. Manejo de Excepciones

Las excepciones permiten reaccionar a errores sin que el programa se caiga. Se tratan en la sección `EXCEPTION` del bloque.

### Excepciones Predefinidas Más Comunes

| Excepción | Código ORA | Cuándo ocurre |
| :--- | :--- | :--- |
| `NO_DATA_FOUND` | ORA-01403 | `SELECT INTO` sin filas. |
| `TOO_MANY_ROWS` | ORA-01422 | `SELECT INTO` con más de una fila. |
| `ZERO_DIVIDE` | ORA-01476 | División por cero. |
| `DUP_VAL_ON_INDEX` | ORA-00001 | Violación de clave primaria o índice único. |
| `VALUE_ERROR` | ORA-06502 | Error de conversión o tamaño de variable. |
| `INVALID_NUMBER` | ORA-01722 | Conversión de texto a número inválida. |
| `CURSOR_ALREADY_OPEN` | ORA-06511 | Abrir un cursor ya abierto. |
| `OTHERS` | cualquiera | Captura **todo** lo que no se atrapó antes. |

### Estructura Típica

```sql
DECLARE
    v_res NUMBER;
BEGIN
    v_res := 10 / 0;
EXCEPTION
    WHEN ZERO_DIVIDE THEN
        DBMS_OUTPUT.PUT_LINE('No se puede dividir por cero');
    WHEN NO_DATA_FOUND OR TOO_MANY_ROWS THEN
        DBMS_OUTPUT.PUT_LINE('Problema con la cantidad de filas');
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Código: ' || SQLCODE || ' - Mensaje: ' || SQLERRM);
        RAISE;   -- vuelve a lanzar el error hacia el bloque llamador
END;
/
```

* **`SQLCODE`:** número del error (negativo, salvo `NO_DATA_FOUND` que es +100).
* **`SQLERRM`:** texto del mensaje de error.
* **`RAISE;`** sin nombre re-lanza la excepción actual. Útil para registrar el error y no esconderlo.

### Excepciones Definidas por el Usuario

```sql
DECLARE
    e_saldo_insuficiente EXCEPTION;
    v_saldo NUMBER := 500;
    v_monto NUMBER := 800;
BEGIN
    IF v_monto > v_saldo THEN
        RAISE e_saldo_insuficiente;
    END IF;
EXCEPTION
    WHEN e_saldo_insuficiente THEN
        DBMS_OUTPUT.PUT_LINE('Saldo insuficiente');
END;
/
```

### PRAGMA EXCEPTION_INIT

Asocia un nombre a un error ORA que no tiene excepción predefinida:

```sql
DECLARE
    e_fk_violada EXCEPTION;
    PRAGMA EXCEPTION_INIT(e_fk_violada, -2291);   -- ORA-02291: parent key not found
BEGIN
    INSERT INTO pedido (id_pedido, id_cliente) VALUES (1, 99999);
EXCEPTION
    WHEN e_fk_violada THEN
        DBMS_OUTPUT.PUT_LINE('El cliente no existe');
END;
/
```

### RAISE_APPLICATION_ERROR

Lanza un error personalizado **hacia la aplicación** con número entre **-20000 y -20999**:

```sql
BEGIN
    IF 1 = 1 THEN
        RAISE_APPLICATION_ERROR(-20001, 'El monto no puede ser negativo');
    END IF;
END;
/
```

### Propagación

* Si una excepción **no se atrapa** en el bloque actual, sube al bloque que lo contiene, y así hasta llegar al cliente.
* Una excepción lanzada **dentro de la sección `DECLARE`** (por ejemplo, al inicializar una variable) **no** la atrapa el `EXCEPTION` de ese mismo bloque, sino el del bloque externo.
* Una excepción lanzada **dentro de un handler** tampoco la atrapa el mismo bloque.

> **Regla de oro:** evita `WHEN OTHERS THEN NULL;`. Se traga el error y deja fallos silenciosos imposibles de depurar. Si usas `OTHERS`, registra el error o haz `RAISE`.

---

## 7. Procedimientos y Funciones Almacenadas

### Procedimiento

```sql
CREATE OR REPLACE PROCEDURE prc_subir_salario (
    p_id_empleado IN  empleado.id_empleado%TYPE,
    p_porcentaje  IN  NUMBER DEFAULT 5,
    p_nuevo_sal   OUT empleado.salario%TYPE
) AS
BEGIN
    UPDATE empleado
       SET salario = salario * (1 + p_porcentaje / 100)
     WHERE id_empleado = p_id_empleado
    RETURNING salario INTO p_nuevo_sal;

    IF SQL%NOTFOUND THEN
        RAISE_APPLICATION_ERROR(-20010, 'Empleado inexistente');
    END IF;
END prc_subir_salario;
/
```

Para ejecutarlo:

```sql
DECLARE
    v_sal empleado.salario%TYPE;
BEGIN
    prc_subir_salario(100, 10, v_sal);
    DBMS_OUTPUT.PUT_LINE('Nuevo salario: ' || v_sal);
    COMMIT;
END;
/
```

### Función

```sql
CREATE OR REPLACE FUNCTION fn_calcular_iva (
    p_valor IN NUMBER
) RETURN NUMBER
DETERMINISTIC
AS
BEGIN
    RETURN ROUND(p_valor * 0.19, 2);
END fn_calcular_iva;
/

-- Se puede usar directamente en SQL
SELECT id_pedido, total, fn_calcular_iva(total) AS iva
  FROM pedido;
```

### Modos de Parámetros

| Modo | Comportamiento |
| :--- | :--- |
| `IN` (por defecto) | Solo lectura dentro del subprograma. Recibe un valor. |
| `OUT` | Devuelve un valor al llamador. Inicia en `NULL`. |
| `IN OUT` | Recibe un valor y puede modificarlo para devolverlo. |

* **Notación posicional:** `prc_x(100, 10, v)`.
* **Notación nombrada:** `prc_x(p_id_empleado => 100, p_nuevo_sal => v)`; no importa el orden y permite saltar parámetros con `DEFAULT`.
* **`NOCOPY`:** sugerencia al motor para pasar `OUT` / `IN OUT` por referencia en lugar de copiar (útil con colecciones grandes).
* **`DETERMINISTIC`:** promete que, con los mismos argumentos, siempre devuelve lo mismo (permite usarla en índices basados en funciones).
* **`RESULT_CACHE`:** Oracle guarda en caché los resultados de la función para reutilizarlos.

### Procedimiento vs Función

| Característica | Procedimiento | Función |
| :--- | :--- | :--- |
| Retorna valor | Opcional (vía `OUT`) | **Obligatorio** (`RETURN`) |
| Se usa en un `SELECT` | No | Sí (si no hace DML) |
| Se invoca como | Sentencia independiente | Expresión |
| Uso típico | Ejecutar acciones y procesos | Calcular y devolver un resultado |

> **Buena práctica:** una función invocada desde un `SELECT` no debería modificar datos (DML). Si lo hace, Oracle lo prohíbe en la mayoría de los contextos (ORA-14551).

### Consultar y Depurar el Código Almacenado

```sql
SELECT object_name, object_type, status
  FROM user_objects
 WHERE object_type IN ('PROCEDURE', 'FUNCTION', 'PACKAGE', 'PACKAGE BODY', 'TRIGGER');

SELECT line, position, text
  FROM user_errors
 WHERE name = 'PRC_SUBIR_SALARIO'
 ORDER BY sequence;
```

En SQL*Plus, `SHOW ERRORS` muestra los errores de la última compilación.

---

## 8. Paquetes (Packages)

Un **paquete** agrupa elementos relacionados en dos partes:

* **Especificación (`PACKAGE`):** la "interfaz pública". Declara qué se puede usar desde fuera.
* **Cuerpo (`PACKAGE BODY`):** la implementación. Puede contener elementos **privados** que no se ven desde fuera.

```sql
-- Especificación
CREATE OR REPLACE PACKAGE pkg_empleados AS
    c_salario_minimo CONSTANT NUMBER := 1300000;

    PROCEDURE contratar (p_nombre IN VARCHAR2, p_salario IN NUMBER);
    FUNCTION  total_nomina (p_depto IN NUMBER) RETURN NUMBER;
END pkg_empleados;
/

-- Cuerpo
CREATE OR REPLACE PACKAGE BODY pkg_empleados AS

    -- Función privada: solo visible dentro del paquete
    FUNCTION validar_salario (p_salario NUMBER) RETURN BOOLEAN IS
    BEGIN
        RETURN p_salario >= c_salario_minimo;
    END validar_salario;

    PROCEDURE contratar (p_nombre IN VARCHAR2, p_salario IN NUMBER) IS
    BEGIN
        IF NOT validar_salario(p_salario) THEN
            RAISE_APPLICATION_ERROR(-20020, 'Salario por debajo del mínimo');
        END IF;

        INSERT INTO empleado (id_empleado, nombre, salario)
        VALUES (seq_empleado.NEXTVAL, p_nombre, p_salario);
    END contratar;

    FUNCTION total_nomina (p_depto IN NUMBER) RETURN NUMBER IS
        v_total NUMBER;
    BEGIN
        SELECT NVL(SUM(salario), 0)
          INTO v_total
          FROM empleado
         WHERE id_departamento = p_depto;
        RETURN v_total;
    END total_nomina;

END pkg_empleados;
/
```

Uso:

```sql
BEGIN
    pkg_empleados.contratar('Camila', 2500000);
    DBMS_OUTPUT.PUT_LINE(pkg_empleados.total_nomina(10));
END;
/
```

**Ventajas de los paquetes:**

* **Encapsulamiento:** se oculta lo privado y se expone solo lo necesario.
* **Rendimiento:** al llamar a un elemento, **todo** el paquete se carga en memoria una vez.
* **Estado persistente por sesión:** las variables del paquete conservan su valor mientras dure la sesión.
* **Menos invalidaciones:** si cambias solo el cuerpo, los objetos que dependen de la especificación no se invalidan.
* **Sobrecarga (*overloading*):** varios subprogramas con el mismo nombre y distintos parámetros.

---

## 9. Triggers (Disparadores)

Un **trigger** es un bloque PL/SQL que Oracle ejecuta **automáticamente** cuando ocurre un evento.

### Clasificación

| Criterio | Opciones |
| :--- | :--- |
| **Momento** | `BEFORE`, `AFTER`, `INSTEAD OF` (solo vistas) |
| **Evento** | `INSERT`, `UPDATE`, `DELETE` (combinables con `OR`) |
| **Nivel** | Sentencia (una vez por sentencia) o **fila** (`FOR EACH ROW`, una vez por fila) |

### Pseudo-registros `:NEW` y `:OLD`

Solo existen en triggers **de fila**:

| Evento | `:OLD` | `:NEW` |
| :--- | :--- | :--- |
| `INSERT` | No tiene valores (`NULL`) | Valores que se insertan |
| `UPDATE` | Valores antes del cambio | Valores después del cambio |
| `DELETE` | Valores de la fila borrada | No tiene valores (`NULL`) |

> Dentro del cuerpo se escriben con dos puntos (`:NEW.salario`), pero en la cláusula `WHEN` se escriben **sin** ellos (`WHEN (NEW.salario > 0)`).

### Ejemplo: Auditoría de Cambios de Salario

```sql
CREATE OR REPLACE TRIGGER trg_auditar_salario
AFTER UPDATE OF salario ON empleado
FOR EACH ROW
WHEN (OLD.salario <> NEW.salario)
BEGIN
    INSERT INTO auditoria_salario (id_empleado, salario_anterior, salario_nuevo, fecha, usuario)
    VALUES (:OLD.id_empleado, :OLD.salario, :NEW.salario, SYSDATE, USER);
END trg_auditar_salario;
/
```

### Ejemplo: Validar y Completar Datos Antes de Insertar

```sql
CREATE OR REPLACE TRIGGER trg_empleado_bi
BEFORE INSERT OR UPDATE ON empleado
FOR EACH ROW
BEGIN
    IF :NEW.salario < 0 THEN
        RAISE_APPLICATION_ERROR(-20030, 'El salario no puede ser negativo');
    END IF;

    IF INSERTING AND :NEW.id_empleado IS NULL THEN
        :NEW.id_empleado := seq_empleado.NEXTVAL;
    END IF;

    :NEW.nombre := UPPER(:NEW.nombre);
END trg_empleado_bi;
/
```

* **`INSERTING`, `UPDATING`, `DELETING`:** predicados booleanos que indican qué operación disparó el trigger.
* Solo en triggers **BEFORE** de fila se pueden **modificar** los valores `:NEW`.

### Error de Tabla Mutante (ORA-04091)

Ocurre cuando un trigger de fila intenta **leer o modificar la misma tabla** que lo disparó. Soluciones habituales:

* Usar un **compound trigger** que acumule los datos por fila y los procese al final de la sentencia.
* Mover la lógica a un procedimiento invocado desde la aplicación.
* Replantear si la regla se puede cubrir con una restricción (`CHECK`, `UNIQUE`, `FK`).

### Compound Trigger

Agrupa varios momentos de disparo en una sola unidad que comparte variables:

```sql
CREATE OR REPLACE TRIGGER trg_empleado_compound
FOR UPDATE OF salario ON empleado
COMPOUND TRIGGER

    TYPE t_ids IS TABLE OF empleado.id_empleado%TYPE;
    g_ids t_ids := t_ids();

    AFTER EACH ROW IS
    BEGIN
        g_ids.EXTEND;
        g_ids(g_ids.LAST) := :NEW.id_empleado;
    END AFTER EACH ROW;

    AFTER STATEMENT IS
    BEGIN
        -- aquí ya es seguro consultar la tabla sin ORA-04091
        DBMS_OUTPUT.PUT_LINE('Filas modificadas: ' || g_ids.COUNT);
    END AFTER STATEMENT;

END trg_empleado_compound;
/
```

### Buenas Prácticas con Triggers

* Mantenerlos **cortos**; que llamen a procedimientos para la lógica pesada.
* **No** usar `COMMIT` ni `ROLLBACK` dentro de un trigger (forman parte de la transacción que los disparó).
* Evitar cadenas de triggers que se disparan entre sí.
* Pueden activarse y desactivarse: `ALTER TRIGGER trg_x DISABLE;` / `ENABLE;`.

---

## 10. Colecciones

Una **colección** es una estructura que guarda varios elementos del mismo tipo (similar a un arreglo).

| Tipo | Índice | ¿Tamaño fijo? | ¿Se puede guardar en una columna? |
| :--- | :--- | :--- | :--- |
| **Associative Array** (`INDEX BY`) | Entero o texto, disperso | No | No (solo en memoria PL/SQL) |
| **Nested Table** | Entero, puede quedar disperso | No | Sí |
| **VARRAY** | Entero consecutivo | Sí (límite máximo) | Sí |

```sql
DECLARE
    -- Associative array
    TYPE t_salarios IS TABLE OF NUMBER INDEX BY VARCHAR2(30);
    v_sal t_salarios;

    -- Nested table
    TYPE t_nombres IS TABLE OF VARCHAR2(50);
    v_nombres t_nombres := t_nombres('Ana', 'Luis', 'Marta');

    -- VARRAY
    TYPE t_top3 IS VARRAY(3) OF VARCHAR2(30);
    v_top t_top3 := t_top3('Oro', 'Plata', 'Bronce');
BEGIN
    v_sal('Ana')  := 3000000;
    v_sal('Luis') := 2500000;
    DBMS_OUTPUT.PUT_LINE('Ana gana ' || v_sal('Ana'));

    v_nombres.EXTEND;
    v_nombres(4) := 'Pedro';

    FOR i IN 1..v_nombres.COUNT LOOP
        DBMS_OUTPUT.PUT_LINE(i || ': ' || v_nombres(i));
    END LOOP;
END;
/
```

### Métodos de Colecciones

| Método | Función |
| :--- | :--- |
| `COUNT` | Cantidad de elementos existentes. |
| `FIRST` / `LAST` | Primer y último índice. |
| `NEXT(n)` / `PRIOR(n)` | Índice siguiente o anterior a `n`. |
| `EXISTS(n)` | `TRUE` si existe el elemento `n`. |
| `EXTEND` | Agrega espacio (nested table y VARRAY). |
| `DELETE` / `TRIM` | Elimina elementos / recorta desde el final. |
| `LIMIT` | Tamaño máximo (solo VARRAY). |

---

## 11. Rendimiento: BULK COLLECT y FORALL

### El Problema: Cambios de Contexto

Cada vez que PL/SQL le pasa una sentencia al motor SQL (y viceversa) ocurre un **cambio de contexto**. Hacerlo fila por fila dentro de un bucle es muy costoso.

```sql
-- MAL: un cambio de contexto por cada fila
BEGIN
    FOR r IN (SELECT id_empleado FROM empleado) LOOP
        UPDATE empleado SET salario = salario * 1.05 WHERE id_empleado = r.id_empleado;
    END LOOP;
END;
/
```

> Lo más rápido, cuando se puede, es **un solo `UPDATE` en SQL puro**. Usa BULK solo cuando necesites lógica procedural por fila.

### BULK COLLECT (Lectura Masiva)

Trae muchas filas de una sola vez a una colección:

```sql
DECLARE
    TYPE t_emp IS TABLE OF empleado%ROWTYPE;
    v_emps t_emp;
BEGIN
    SELECT *
      BULK COLLECT INTO v_emps
      FROM empleado
     WHERE id_departamento = 10;

    DBMS_OUTPUT.PUT_LINE('Filas leídas: ' || v_emps.COUNT);
END;
/
```

### BULK COLLECT con LIMIT (Para Tablas Grandes)

Evita agotar la memoria procesando por lotes:

```sql
DECLARE
    CURSOR c_emp IS SELECT id_empleado, salario FROM empleado;
    TYPE t_lote IS TABLE OF c_emp%ROWTYPE;
    v_lote t_lote;
BEGIN
    OPEN c_emp;
    LOOP
        FETCH c_emp BULK COLLECT INTO v_lote LIMIT 1000;
        EXIT WHEN v_lote.COUNT = 0;

        FORALL i IN 1..v_lote.COUNT
            UPDATE empleado
               SET salario = v_lote(i).salario * 1.05
             WHERE id_empleado = v_lote(i).id_empleado;

        COMMIT;
    END LOOP;
    CLOSE c_emp;
END;
/
```

> **Ojo con el `EXIT WHEN`:** con `LIMIT`, usa `v_lote.COUNT = 0` y **no** `c_emp%NOTFOUND`, porque este último puede ser verdadero en el último lote parcial y te haría perder esas filas.

### FORALL (Escritura Masiva)

Envía **todas** las operaciones DML al motor SQL en un solo cambio de contexto. No es un bucle: es **una sola sentencia DML** que se repite para cada índice.

```sql
DECLARE
    TYPE t_ids IS TABLE OF NUMBER;
    v_ids t_ids := t_ids(101, 102, 103);
BEGIN
    FORALL i IN 1..v_ids.COUNT
        DELETE FROM empleado WHERE id_empleado = v_ids(i);

    DBMS_OUTPUT.PUT_LINE('Eliminadas: ' || SQL%ROWCOUNT);
END;
/
```

### SAVE EXCEPTIONS (Continuar Pese a los Errores)

```sql
DECLARE
    TYPE t_ids IS TABLE OF NUMBER;
    v_ids t_ids := t_ids(1, 2, 3);
    e_bulk EXCEPTION;
    PRAGMA EXCEPTION_INIT(e_bulk, -24381);
BEGIN
    FORALL i IN 1..v_ids.COUNT SAVE EXCEPTIONS
        INSERT INTO empleado (id_empleado, nombre) VALUES (v_ids(i), 'Test');
EXCEPTION
    WHEN e_bulk THEN
        FOR j IN 1..SQL%BULK_EXCEPTIONS.COUNT LOOP
            DBMS_OUTPUT.PUT_LINE(
                'Índice fallido: ' || SQL%BULK_EXCEPTIONS(j).ERROR_INDEX ||
                ' - Código: '       || SQL%BULK_EXCEPTIONS(j).ERROR_CODE
            );
        END LOOP;
END;
/
```

---

## 12. SQL Dinámico

Se usa cuando la sentencia **no se conoce hasta ejecutar** (nombres de tabla variables, DDL dentro de PL/SQL, filtros armados al vuelo).

### EXECUTE IMMEDIATE

```sql
DECLARE
    v_tabla  VARCHAR2(30) := 'EMPLEADO';
    v_total  NUMBER;
BEGIN
    -- Con SELECT que devuelve un valor
    EXECUTE IMMEDIATE 'SELECT COUNT(*) FROM ' || v_tabla INTO v_total;
    DBMS_OUTPUT.PUT_LINE('Total: ' || v_total);

    -- Con variables de enlace (bind) para los VALORES
    EXECUTE IMMEDIATE
        'UPDATE empleado SET salario = :1 WHERE id_empleado = :2'
        USING 3500000, 100;

    -- DDL (hace COMMIT implícito)
    EXECUTE IMMEDIATE 'CREATE TABLE temp_prueba (id NUMBER)';
END;
/
```

### Seguridad: Evitar la Inyección SQL

* **Los valores** siempre se pasan con **variables de enlace** (`:1`, `:nombre` y `USING`), nunca concatenados.
* **Los identificadores** (nombres de tablas o columnas) no admiten bind; deben validarse con `DBMS_ASSERT`:

```sql
DECLARE
    v_tabla_segura VARCHAR2(130);
BEGIN
    v_tabla_segura := DBMS_ASSERT.SQL_OBJECT_NAME('EMPLEADO');   -- lanza error si no existe
    EXECUTE IMMEDIATE 'SELECT COUNT(*) FROM ' || v_tabla_segura;
END;
/
```

> **Regla de oro:** nunca concatenes texto que venga del usuario directamente dentro de una sentencia dinámica.

---

## 13. Transacciones en PL/SQL

* Una transacción empieza con la primera sentencia DML y termina con `COMMIT` o `ROLLBACK`.
* Un **DDL** (`CREATE`, `ALTER`, `TRUNCATE`...) hace un `COMMIT` implícito, incluso dentro de `EXECUTE IMMEDIATE`.
* Si un bloque termina con una **excepción no controlada**, Oracle deshace únicamente la **sentencia** que falló, no toda la transacción. Por eso conviene decidir explícitamente con `ROLLBACK`.
* **`SAVEPOINT`** permite revertir parcialmente:

```sql
BEGIN
    INSERT INTO cuenta (id_cuenta, saldo) VALUES (1, 100);
    SAVEPOINT despues_del_primero;

    BEGIN
        INSERT INTO cuenta (id_cuenta, saldo) VALUES (1, 200);   -- falla por PK duplicada
    EXCEPTION
        WHEN DUP_VAL_ON_INDEX THEN
            ROLLBACK TO despues_del_primero;                     -- conserva el primer insert
    END;

    COMMIT;
END;
/
```

### Transacciones Autónomas

`PRAGMA AUTONOMOUS_TRANSACTION` hace que un subprograma tenga su **propia transacción**, independiente de la que lo llamó. Su uso clásico es **registrar logs de error** que no se pierdan aunque la transacción principal haga `ROLLBACK`:

```sql
CREATE OR REPLACE PROCEDURE prc_log_error (p_mensaje IN VARCHAR2) AS
    PRAGMA AUTONOMOUS_TRANSACTION;
BEGIN
    INSERT INTO log_errores (fecha, usuario, mensaje)
    VALUES (SYSDATE, USER, p_mensaje);
    COMMIT;   -- obligatorio: debe cerrar su propia transacción
END prc_log_error;
/
```

---

## 14. Ejemplo Integrador: Transferencia Bancaria Segura

Combina parámetros, validaciones, excepciones personalizadas, bloqueo ordenado y control de transacción:

```sql
CREATE OR REPLACE PROCEDURE prc_transferir (
    p_origen  IN cuenta.id_cuenta%TYPE,
    p_destino IN cuenta.id_cuenta%TYPE,
    p_monto   IN NUMBER
) AS
    e_monto_invalido     EXCEPTION;
    e_saldo_insuficiente EXCEPTION;
    PRAGMA EXCEPTION_INIT(e_monto_invalido,     -20101);
    PRAGMA EXCEPTION_INIT(e_saldo_insuficiente, -20102);

    v_saldo_origen cuenta.saldo%TYPE;
BEGIN
    IF p_monto IS NULL OR p_monto <= 0 THEN
        RAISE_APPLICATION_ERROR(-20101, 'El monto debe ser positivo');
    END IF;

    -- Bloqueo en orden determinístico para evitar deadlocks
    FOR r IN (SELECT id_cuenta, saldo
                FROM cuenta
               WHERE id_cuenta IN (p_origen, p_destino)
               ORDER BY id_cuenta
                 FOR UPDATE) LOOP
        IF r.id_cuenta = p_origen THEN
            v_saldo_origen := r.saldo;
        END IF;
    END LOOP;

    IF v_saldo_origen IS NULL THEN
        RAISE_APPLICATION_ERROR(-20103, 'Cuenta de origen inexistente');
    END IF;

    IF v_saldo_origen < p_monto THEN
        RAISE_APPLICATION_ERROR(-20102, 'Saldo insuficiente');
    END IF;

    UPDATE cuenta SET saldo = saldo - p_monto, version = version + 1 WHERE id_cuenta = p_origen;
    UPDATE cuenta SET saldo = saldo + p_monto, version = version + 1 WHERE id_cuenta = p_destino;

    COMMIT;
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        prc_log_error('Transferencia fallida: ' || SQLERRM);
        RAISE;
END prc_transferir;
/
```

---

## 15. Buenas Prácticas y Errores Comunes

### Buenas Prácticas

* **Nombrar con prefijos:** `v_` variables, `p_` parámetros, `c_` constantes y cursores, `e_` excepciones, `r_` registros, `t_` tipos, `prc_` / `fn_` / `pkg_` / `trg_` para objetos.
* Usar **`%TYPE` y `%ROWTYPE`** en lugar de tipos escritos a mano.
* Preferir **Cursor FOR LOOP** a manejar `OPEN / FETCH / CLOSE` manualmente.
* Hacer en **SQL puro** lo que SQL pueda hacer; PL/SQL solo para lo que exige lógica procedural.
* Usar **BULK COLLECT + FORALL** para procesar grandes volúmenes.
* Agrupar la lógica de negocio en **paquetes**.
* Controlar siempre los errores esperados (`NO_DATA_FOUND`, `TOO_MANY_ROWS`) con handlers específicos.
* Usar **variables de enlace** y validar identificadores en SQL dinámico.
* Mantener los triggers pequeños y sin `COMMIT`.

### Errores Frecuentes

| Error | Causa | Solución |
| :--- | :--- | :--- |
| ORA-01403 `no data found` | `SELECT INTO` sin filas. | Capturar `NO_DATA_FOUND` o usar un cursor. |
| ORA-01422 `exact fetch returns more than requested number of rows` | `SELECT INTO` con varias filas. | Filtrar mejor o usar cursor / `BULK COLLECT`. |
| ORA-06502 `numeric or value error` | Variable muy pequeña o conversión inválida. | Ampliar tamaño o usar `%TYPE`. |
| ORA-04091 `table is mutating` | Trigger de fila leyendo su propia tabla. | Compound trigger o rediseño. |
| ORA-06512 `at line n` | Traza de dónde ocurrió el error. | Revisar la línea indicada y la pila de llamadas. |
| ORA-00054 `resource busy` | `FOR UPDATE NOWAIT` sobre fila bloqueada. | Reintentar o usar `WAIT n` / `SKIP LOCKED`. |
| ORA-14551 `cannot perform a DML operation inside a query` | Función con DML llamada desde un `SELECT`. | Mover el DML a un procedimiento. |
| Procedimiento `INVALID` | Un objeto del que depende cambió. | `ALTER PROCEDURE nombre COMPILE;` y revisar `USER_ERRORS`. |

### Resumen Rápido

| Necesito... | Uso |
| :--- | :--- |
| Ejecutar algo una vez, sin guardarlo | Bloque anónimo |
| Realizar una acción reutilizable | `PROCEDURE` |
| Calcular un valor reutilizable (incluso en SQL) | `FUNCTION` |
| Agrupar lógica relacionada con partes privadas | `PACKAGE` |
| Reaccionar automáticamente a cambios de datos | `TRIGGER` |
| Recorrer filas de una consulta | Cursor `FOR LOOP` |
| Devolver un resultado a una aplicación | `SYS_REFCURSOR` |
| Procesar miles de filas rápido | `BULK COLLECT` + `FORALL` |
| Lanzar un error propio a la aplicación | `RAISE_APPLICATION_ERROR` |
| Guardar log aunque haya `ROLLBACK` | `PRAGMA AUTONOMOUS_TRANSACTION` |