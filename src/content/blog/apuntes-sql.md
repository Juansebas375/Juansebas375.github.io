---
title: "Apuntes Maestros de SQL: Fundamentos, Analítica, Optimización y Concurrencia"
description: "Guía técnica exhaustiva de SQL relacional: DDL, DML, TCL, normalización 3FN, JOINs, funciones de ventana, CTEs recursivas, MERGE, optimización de índices B-tree y control de concurrencia."
pubDate: "2026-11-08"
tags: ["sql", "databases", "oracle", "optimizacion", "concurrencia", "transacciones"]
---

# 📚 Guía Completa de SQL: De la Estructura a la Producción

---

## 1. Clasificación del Lenguaje SQL y Transacciones (TCL)

El estándar SQL se clasifica en sublenguajes según el nivel de operación en el motor de base de datos:

| Sublenguaje | Significado | Comandos Principales | Propósito y Efecto |
| :--- | :--- | :--- | :--- |
| **DDL** | Data Definition Language | `CREATE`, `ALTER`, `DROP`, `TRUNCATE` | Modifica estructuras, esquemas, catálogos e índices físicos. Aplica confirmación implícita en la base de datos. |
| **DML** | Data Manipulation Language | `INSERT`, `UPDATE`, `DELETE`, `MERGE` | Lee y manipula las tuplas de datos dentro de las tablas sin alterar la arquitectura física. |
| **DQL** | Data Query Language | `SELECT` | Recuperación, filtrado y proyección de registros desde las tablas. |
| **DCL** | Data Control Language | `GRANT`, `REVOKE` | Administra permisos, privilegios de esquema y roles de usuario. |
| **TCL** | Transaction Control Language | `COMMIT`, `ROLLBACK`, `SAVEPOINT` | Garantiza las propiedades ACID transaccionales y controla la persistencia de cambios en disco. |

### Transacciones y Comandos TCL

* **`COMMIT`:** Vuelca los cambios de la sesión activa al registro de transacciones (*Redo Log*) y los hace permanentes e irrevocables en disco, liberando los bloqueos exclusivos adquiridos en las filas.
* **`ROLLBACK`:** Deshace todas las modificaciones efectuadas en la transacción en curso recurriendo a los segmentos de memoria de anulación (*Undo*), devolviendo los datos a su último estado confirmado.
* **`SAVEPOINT <nombre>`:** Fija un punto de guardado intermedio dentro de una transacción para ejecutar reversiones parciales (`ROLLBACK TO <nombre>`) sin perder el trabajo anterior.

### Comparativa Vital: DELETE vs TRUNCATE vs DROP

* **`DELETE` (DML):** Borra tuplas fila por fila o según un filtro `WHERE`. Escribe cada eliminación en el log de transacciones (admite `ROLLBACK`), dispara disparadores de fila (`FOR EACH ROW`) y mantiene el espacio asignado a la tabla.
* **`TRUNCATE` (DDL):** Vía rápida. Desasigna masivamente las páginas de datos del motor. No recorre fila a fila, reduce al mínimo el registro en logs, reinicia secuencias/identidades y no ejecuta triggers `ON DELETE`.
* **`DROP` (DDL):** Destruye físicamente la definición de la tabla en el diccionario de datos junto con sus índices, triggers, restricciones asociadas y registros.

---

## 2. Modelo Relacional e Integridad Referencial (3FN)

### Componentes y Conceptos Formales

* **Relación:** Estructura bidimensional percibida formalmente como un conjunto no ordenado de tuplas (tabla).
* **Tupla:** Cada registro individual dentro de una relación (fila).
* **Atributo:** Columna nombrada asociada a un dominio de valores específico.
* **Dominio:** Conjunto predefinido de valores atómicos válidos para un atributo.
* **Superclave:** Conjunto de uno o más atributos que identifican de forma unívoca a cada tupla en una relación.
* **Clave Candidata:** Superclave mínima e irreducible; si se elimina un atributo, pierde la unicidad.
* **Clave Primaria (Primary Key - PK):** Clave candidata seleccionada formalmente para indexar y distinguir de forma única cada tupla. No admite valores `NULL` (Integridad de Entidad).
* **Clave Foránea (Foreign Key - FK):** Atributo que referencia la clave primaria de otra tabla para modelar asociaciones lógicas (Integridad Referencial).

### Reglas de Normalización

1. **Primera Forma Normal (1FN):** Atributos atómicos (indivisibles), ausencia de arreglos o cadenas delimitadas por comas, e identificación unívoca por clave primaria.
2. **Segunda Forma Normal (2FN):** Cumple 1FN y ningún atributo no clave depende de un subconjunto propio de una clave primaria compuesta (dependencia funcional completa). Si la PK es simple, la tabla en 1FN ya está en 2FN.
3. **Tercera Forma Normal (3FN):** Cumple 2FN y no existen dependencias transitivas (ningún atributo no primo depende funcionalmente de otro atributo no primo).
4. **Forma Normal de Boyce-Codd (BCNF):** Toda dependencia funcional no trivial exige estrictamente que el determinante sea una superclave.

### Tipos de Relaciones

* **Relación 1:1:** Clave primaria compartida entre ambas tablas o una Foreign Key con restricción `UNIQUE` en la tabla secundaria.
* **Relación 1:N:** Foreign Key ubicada obligatoriamente en la tabla del lado "muchos" (hija).
* **Relación N:M:** Requiere una **tabla asociativa intermedia** con clave primaria compuesta conformada por las FKs de ambas entidades (`PK = {FK_1, FK_2}`).
* **Relación Recursiva:** Una clave foránea que apunta a la clave primaria dentro de la misma tabla (ej. `id_jefe` referenciando `id_empleado`).

### Reglas de Eliminación en Llaves Foráneas (Acciones Referenciales)

* `ON DELETE RESTRICT` / `NO ACTION`: Bloquea la eliminación del registro padre si existen filas hijas que lo referencian.
* `ON DELETE CASCADE`: Elimina en cascada todos los registros hijos vinculados al eliminar el registro padre.
* `ON DELETE SET NULL`: Pone en `NULL` la columna FK de la tabla hija al borrar al padre (la columna no debe ser `NOT NULL`).

---

## 3. Consultas Multitabla: Todos los Tipos de JOIN

Los JOINs permiten combinar datos de dos o más relaciones según una condición lógica de enlace:

```text
       Tabla A                       Tabla B
     ┌───────────┐                 ┌───────────┐
     │           │   INNER JOIN    │           │
     │      ┌────┼─────────────────┼────┐      │
     │      │    │     A ∩ B       │    │      │
     │      └────┼─────────────────┼────┘      │
     └───────────┘                 └───────────┘
           LEFT JOIN:  A + (A ∩ B)
          RIGHT JOIN:  (A ∩ B) + B
           FULL JOIN:  A + (A ∩ B) + B
```

### 1. INNER JOIN

Retorna exclusivamente las tuplas que satisfacen el predicado de cruce en ambas tablas (A ∩ B). Si un registro no tiene pareja, se descarta.

```sql
SELECT c.id_cliente, c.nombre, p.id_pedido, p.total
  FROM cliente c
 INNER JOIN pedido p ON c.id_cliente = p.id_cliente;
```

### 2. LEFT (OUTER) JOIN

Preserva todas las tuplas de la relación izquierda (A). Si una fila no tiene correspondencia en la derecha, las columnas de la tabla derecha se rellenan con `NULL`.

```sql
SELECT c.id_cliente, c.nombre, p.id_pedido, p.total
  FROM cliente c
  LEFT JOIN pedido p ON c.id_cliente = p.id_cliente;
```

### 3. RIGHT (OUTER) JOIN

Preserva todas las tuplas de la relación derecha (B). Si una fila no tiene correspondencia en la izquierda, las columnas de la tabla izquierda se rellenan con `NULL`.

```sql
SELECT c.id_cliente, p.id_pedido, p.total
  FROM cliente c
 RIGHT JOIN pedido p ON c.id_cliente = p.id_cliente;
```

### 4. FULL (OUTER) JOIN

Retorna la totalidad de registros con y sin coincidencia de ambos conjuntos (A ∪ B). Los campos sin correspondencia de cualquier lado se completan con `NULL`.

```sql
SELECT c.id_cliente, c.nombre, p.id_pedido, p.total
  FROM cliente c
  FULL OUTER JOIN pedido p ON c.id_cliente = p.id_cliente;
```

### 5. LEFT JOIN EXCLUSIVO (Diferencia A − B)

Obtiene únicamente las filas de la tabla izquierda que no existen en la tabla derecha mediante el filtrado de nulos en la clave foránea.

```sql
SELECT c.id_cliente, c.nombre
  FROM cliente c
  LEFT JOIN pedido p ON c.id_cliente = p.id_cliente
 WHERE p.id_cliente IS NULL;
```

### 6. RIGHT JOIN EXCLUSIVO (Diferencia B − A)

Obtiene únicamente las filas de la tabla derecha que no tienen ningún vínculo o padre en la tabla izquierda.

```sql
SELECT p.id_pedido, p.total
  FROM cliente c
 RIGHT JOIN pedido p ON c.id_cliente = p.id_cliente
 WHERE c.id_cliente IS NULL;
```

### 7. FULL OUTER JOIN EXCLUSIVO (Diferencia Simétrica)

Retorna registros que están en A o están en B, pero descarta todos los registros que coinciden simultáneamente en ambos conjuntos.

```sql
SELECT c.id_cliente, p.id_pedido
  FROM cliente c
  FULL OUTER JOIN pedido p ON c.id_cliente = p.id_cliente
 WHERE c.id_cliente IS NULL OR p.id_cliente IS NULL;
```

### 8. CROSS JOIN (Producto Cartesiano)

Empareja cada tupla de la tabla izquierda con todas las tuplas de la tabla derecha (M × N tuplas resultantes). No lleva cláusula `ON`.

```sql
SELECT p.nombre AS producto, t.talla
  FROM producto p
 CROSS JOIN talla t;
```

### 9. NATURAL JOIN

Cruce por equidad automática entre todas las columnas que comparten exactamente el mismo nombre y dominio en ambas tablas.

```sql
SELECT id_departamento, departamento_nombre, primer_nombre
  FROM departamento
 NATURAL JOIN empleado;
```

### 10. SELF JOIN

Cruce de una tabla consigo misma requiriendo el uso obligatorio de alias diferenciados para modelar estructuras jerárquicas o dependencias internas.

```sql
SELECT e.nombre AS empleado,
       j.nombre AS jefe_directo
  FROM empleado e
  LEFT JOIN empleado j ON e.id_jefe = j.id_empleado;
```

### 11. NON-EQUIJOIN

Reunión de tablas donde la condición de enlace utiliza operadores de rango o desigualdad (`BETWEEN`, `>=`, `<=`, `!=`) en lugar de igualdad estricta.

```sql
SELECT e.nombre, e.salario, n.nivel
  FROM empleado e
  JOIN nivel_salarial n ON e.salario BETWEEN n.salario_min AND n.salario_max;
```

---

## 4. Estructura y Orden de Procesamiento Lógico del SELECT

El motor de bases de datos procesa las consultas en un orden interno estricto que difiere de la sintaxis declarativa escrita:

| Paso Lógico | Cláusula | Operación Interna del Motor |
| :--- | :--- | :--- |
| 1 | `FROM` / `JOIN` | Ubica las relaciones base, resuelve productos cartesianos y evalúa condiciones `ON`. |
| 2 | `WHERE` | Filtra filas individuales del conjunto base. No admite funciones de agregación ni analíticas. |
| 3 | `GROUP BY` | Segmenta las filas sobrevivientes en cubetas o particiones según las columnas indicadas. |
| 4 | `HAVING` | Filtra los grupos consolidados evaluando condiciones sobre funciones agregadas (`SUM`, `COUNT`, `AVG`). |
| 5 | `SELECT` | Computa expresiones escalares, resuelve alias y evalúa funciones analíticas/ventana (`OVER`). |
| 6 | `DISTINCT` | Elimina tuplas idénticas repetidas del conjunto proyectado. |
| 7 | `ORDER BY` | Ordena el conjunto final de registros (`ASC` o `DESC`). Admite alias calculados en el `SELECT`. |
| 8 | `LIMIT` / `OFFSET` / `FETCH` | Corta y pagina el volumen final de tuplas transferidas a la aplicación cliente. |

> **Regla de Examen:** `WHERE` filtra filas individuales antes de agrupar; `HAVING` filtra grupos consolidados después del agrupamiento.

---

## 5. Funciones Escalares, Conversiones y Tratamiento de Nulos

### Funciones de Fila y Fechas

* **`UPPER(cadena)` / `LOWER(cadena)`:** Homogeneizan cadenas a mayúsculas o minúsculas para comparaciones insensibles al formato.
* **`TRUNC(fecha)`:** Trunca la porción horaria dejando la marca temporal en la medianoche (00:00:00).
* **Conversiones explícitas:** `TO_CHAR`, `TO_DATE`, `TO_NUMBER` y `CAST` garantizan transformaciones homogéneas de tipos de datos.

### Lógica Trivaluada y Nulos

Las comparaciones directas frente a un valor `NULL` retornan `UNKNOWN`. No se debe usar `= NULL`, sino los predicados `IS NULL` o `IS NOT NULL`.

* **`NVL(columna, reemplazo)`:** Reemplazo de nulos nativo en Oracle.
* **`NVL2(columna, si_no_nulo, si_nulo)`:** Retorna la primera expresión si la columna contiene dato; de ser nula retorna la segunda.
* **`COALESCE(c1, c2, ..., cn)`:** Retorna la primera expresión no nula de la lista evaluada según el estándar ANSI.
* **`NULLIF(expr1, expr2)`:** Devuelve `NULL` si ambas expresiones coinciden; de lo contrario devuelve `expr1`.
* **`CASE WHEN ... THEN ... ELSE ... END`:** Estructura condicional evaluada fila por fila.

---

## 6. Subconsultas y Operadores de Conjuntos

### Variantes de Subconsultas

* **Subconsulta Escalar:** Retorna una sola fila y una sola columna. Utilizable en predicados con operadores aritméticos y directos (`=`, `>`, `<`) dentro de `SELECT`, `WHERE` o `HAVING`.
* **Subconsulta de Múltiples Filas:** Emplea operadores de pertenencia y comparación de conjuntos:
  * `IN` / `NOT IN`: Verifica pertenencia en la lista devuelta.
  * `ANY` / `SOME`: Compara contra al menos un elemento devuelto (ej. `> ANY (...)`).
  * `ALL`: Compara contra la totalidad de elementos del subconjunto (ej. `> ALL (...)`).
* **Subconsulta Correlacionada:** La consulta interna depende de los valores de la fila actual procesada por la consulta externa, evaluándose iterativamente fila a fila.
* **`EXISTS` / `NOT EXISTS`:** Valida si la subconsulta subordinada retorna al menos una tupla. Detiene la búsqueda en el primer acierto.

> **Regla de Operación Crítica:** Si una subconsulta dentro de `NOT IN` retorna al menos un valor `NULL`, cualquier comparación `valor = NULL` produce `UNKNOWN`, ocasionando que la consulta completa devuelva cero registros. Debe resolverse mediante `NOT EXISTS` o aplicando `WHERE columna IS NOT NULL` en la subconsulta.

### Operadores de Conjuntos

* **`UNION`:** Concatena conjuntos suprimiendo registros duplicados mediante ordenamiento y deduplicación interna.
* **`UNION ALL`:** Concatena conjuntos conservando todos los registros duplicados de forma directa y sin costo de ordenamiento.
* **`INTERSECT`:** Retorna únicamente los registros comunes existentes en ambos conjuntos.
* **`MINUS` / `EXCEPT`:** Retorna los registros presentes en la primera consulta que no existen en la segunda.

---

## 7. SQL Analítico, Jerarquías y Sentencia MERGE

### Funciones de Ventana (OVER)

Permiten calcular métricas acumuladas, rankings o particiones manteniendo el detalle de cada fila física (sin colapsar los registros como un `GROUP BY`):

```sql
SELECT id_cuenta,
       fecha_mov,
       tipo_movimiento,
       valor,
       SUM(CASE 
             WHEN tipo_movimiento = 'CREDITO' THEN valor 
             WHEN tipo_movimiento = 'DEBITO'  THEN -valor 
             ELSE 0 
           END) OVER (
           PARTITION BY id_cuenta 
           ORDER BY fecha_mov ASC, id_movimiento ASC 
           ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
       ) AS saldo_acumulado
  FROM movimiento;
```

* **`ROW_NUMBER()`:** Genera enteros secuenciales estrictos (1, 2, 3, 4) sin empates. Único que asegura un top exacto.
* **`RANK()`:** Asigna la misma posición a valores idénticos y genera huecos equivalentes (1, 2, 2, 4).
* **`DENSE_RANK()`:** Asigna la misma posición a valores idénticos sin dejar huecos (1, 2, 2, 3).
* **`LEAD()` / `LAG()`:** Accede a datos de tuplas posteriores o anteriores dentro de la partición sin recurrir a auto-uniones (*self-joins*).
* **`ROWS` vs `RANGE`:** `ROWS` delimita por filas físicas individuales; `RANGE` delimita por el valor lógico del ordenamiento (agrupa duplicados simultáneamente).

### Jerarquías con CTE Recursiva (Estándar ANSI)

Estructura compuesta por un miembro ancla (caso base/raíz) y un miembro recursivo combinados mediante `UNION ALL` para recorrer árboles y grafos acíclicos:

```sql
WITH jerarquia_empleados (id_empleado, nombre, id_jefe, nivel, ruta) AS (
    -- Paso Ancla: Localiza al líder superior (sin supervisor)
    SELECT id_empleado, nombre, id_jefe, 1 AS nivel,
           CAST(nombre AS VARCHAR2(1000)) AS ruta
      FROM empleado
     WHERE id_jefe IS NULL
    UNION ALL
    -- Paso Recursivo: Empareja subordinados con el nivel superior
    SELECT sub.id_empleado, sub.nombre, sub.id_jefe, padre.nivel + 1 AS nivel,
           CAST(padre.ruta || ' -> ' || sub.nombre AS VARCHAR2(1000)) AS ruta
      FROM empleado sub
      JOIN jerarquia_empleados padre ON sub.id_jefe = padre.id_empleado
)
SELECT LPAD(' ', (nivel - 1) * 3, ' ') || nombre AS organigrama, nivel, ruta
  FROM jerarquia_empleados
 ORDER BY ruta ASC;
```

### Sentencia MERGE (UPSERT)

Actualiza registros existentes o inserta nuevos en una única sentencia atómica.

```sql
MERGE INTO cuenta c
USING (
    -- Preagrupamiento obligatorio para garantizar unicidad y evitar ORA-30926
    SELECT id_cuenta, SUM(delta) AS delta_total
      FROM ajuste_saldo
     GROUP BY id_cuenta
) a
ON (c.id_cuenta = a.id_cuenta)
WHEN MATCHED THEN
    UPDATE SET c.saldo   = c.saldo + a.delta_total,
               c.version = c.version + 1
     WHERE (c.saldo + a.delta_total) >= 0
WHEN NOT MATCHED THEN
    INSERT (id_cuenta, saldo, version)
    VALUES (a.id_cuenta, a.delta_total, 1);
```

* **Error ORA-30926 (*unable to get a stable set of rows*):** Se genera cuando la tabla fuente contiene múltiples filas para un mismo registro destino en la condición `ON`. Se soluciona agrupando con `GROUP BY` en el bloque `USING`.
* **Efecto Fan-Out:** Ocurre al cruzar en una sola consulta una entidad con dos o más relaciones 1:N independientes, multiplicando los registros resultantes (3 × 5 = 15) y falseando las sumas (`SUM`). Se soluciona preagrupando cada cálculo en CTEs separadas antes del `JOIN` principal.

---

## 8. Optimización Física de Consultas e Índices B-Tree

### Reglas Cardinales del Optimizador (CBO)

* **Evitar la Supresión de Índices:** Aplicar funciones sobre columnas indexadas en el `WHERE` (`TRUNC(fecha)`, `UPPER(nombre)`) invalida el uso del árbol B-tree y provoca un escaneo completo (`TABLE ACCESS FULL`).
  * **Solución texto:** Crear un índice basado en funciones (FBI): `CREATE INDEX ix_cliente_upper ON cliente (UPPER(nombre));`
  * **Solución fechas:** Reescribir como rango puro cerrado-abierto sobre la columna limpia:

    ```sql
    WHERE fecha >= DATE '2026-03-01' AND fecha < DATE '2026-04-01'
    ```

* **Regla de Orden Compuesto (ESR):** «Igualdad primero, Rango después». La columna evaluada por igualdad estricta (`=`) debe ser el prefijo líder del índice; la evaluada por rango (`>=`, `<`) se ubica al final.
* **Índice de Cobertura (Covering Index):** Incluir todas las columnas solicitadas en el `SELECT`, `WHERE` y `GROUP BY`. La consulta se responde de forma exclusiva desde los bloques hoja del índice B-tree (`INDEX RANGE SCAN`) sin saltos físicos a la tabla por `ROWID` (*Index-Only Access*).
* **Selectividad:** Si una consulta retorna más del 10%–15% de la tabla, el motor opta por `TABLE ACCESS FULL` mediante lecturas multibloque contiguas (*Multiblock Read*), ya que recorrer el índice con accesos aleatorios monobloque (*Single Block I/O*) resulta más costoso.
* **Clustering Factor:** Mide qué tan alineado está el orden de las llaves del índice con el orden físico de las filas en disco. Valores cercanos al total de bloques físicos indican alta eficiencia; valores cercanos al total de filas denotan fragmentación y dispersión.

---

## 9. Concurrencia Transaccional y Control de Bloqueos

### Anomalías Transaccionales Clásicas

* **Actualización Perdida (Lost Update):** Ocurre cuando dos transacciones leen el mismo dato, realizan cálculos en la memoria local de la aplicación y sobreescriben con valores absolutos (`SET saldo = 800000`). La última en confirmar pisa el valor de la primera sin aviso del motor.
  * **Solución:** Modificaciones atómicas relativas directas (`SET saldo = saldo - :monto`) o bloqueo pesimista anticipado.

### Bloqueo Pesimista (`SELECT ... FOR UPDATE`)

Adquiere un cerrojo exclusivo de fila (TX) en el bloque de datos impidiendo que otra sesión modifique las tuplas hasta la ejecución de `COMMIT` o `ROLLBACK`:

```sql
-- Adquisición determinística ordenada (previene Deadlocks - ORA-00060)
SELECT id_cuenta, saldo
  FROM cuenta
 WHERE id_cuenta IN (1001, 1002)
 ORDER BY id_cuenta ASC
   FOR UPDATE;

-- Actualización atómica sobre el saldo vivo
UPDATE cuenta 
   SET saldo = saldo - 300000, 
       version = version + 1 
 WHERE id_cuenta = 1001;

UPDATE cuenta 
   SET saldo = saldo + 300000, 
       version = version + 1 
 WHERE id_cuenta = 1002;

COMMIT; -- Liberación atómica de los cerrojos adquiridos
```

### Variantes de `FOR UPDATE`

* **`NOWAIT`:** Aborta de inmediato con error (`ORA-00054: resource busy`) si la fila ya se encuentra bloqueada por otra sesión.
* **`WAIT n`:** Espera un máximo de *n* segundos antes de abortar la transacción (`ORA-30006`).
* **`SKIP LOCKED`:** Salta las filas retenidas por otros hilos y toma únicamente las libres (ideal para colas de mensajería concurrentes).

### Mecanismos de Consistencia y Bloqueos de Catálogo

* **Lectura Consistente (MVCC):** Un lector puro nunca es bloqueado por un escritor ni por un `FOR UPDATE`; el motor reconstruye la imagen confirmada previa desde los segmentos de anulación (*Undo*).
* **Control Optimista:** No adquiere cerrojos de fila al leer; valida mediante una columna de control en el `UPDATE` (`WHERE id = :id AND version = :version_leida`). Si afecta 0 filas, se detectó colisión y la transacción debe reintentarse.
* **Interbloqueo Cruzado (Deadlock - ORA-00060):** Se produce cuando dos sesiones bloquean recursos cruzados en orden inverso. Se previene imponiendo un orden de adquisición determinístico en el código (`ORDER BY id ASC FOR UPDATE`).
* **Bloqueos TM por Foreign Keys sin Índice:** La eliminación o modificación de una tupla en la tabla padre impone un cerrojo compartido de tabla completa (TM modo 4 o 5) sobre toda la tabla hija si la clave foránea no cuenta con un índice B-tree secundario, paralizando transacciones ajenas. Por eso conviene indexar siempre las FKs.