---
title: "Apuntes Maestros de MongoDB: Documentos, CRUD, Agregaciones, Índices, Modelado y Transacciones"
description: "Guía práctica de MongoDB: modelo de documentos BSON, mongosh, CRUD, operadores de consulta y actualización, pipeline de agregación, índices, explain, modelado embebido vs referenciado, validación de esquema, transacciones, replicación y sharding."
excerpt: "Guía práctica de MongoDB: modelo de documentos BSON, mongosh, CRUD, pipelines de agregación, índices y modelado NoSQL."
publishDate: "Nov 09 2026"
tags: ["mongodb", "nosql", "databases", "agregaciones", "indices", "modelado", "transacciones"]
---

# 🍃 Guía Completa de MongoDB: De tu Primer Documento a Producción

---

## 1. ¿Qué es MongoDB y Cómo se Organiza?

**MongoDB** es una base de datos **NoSQL orientada a documentos**. En lugar de filas y columnas, guarda **documentos** con estructura flexible, parecidos a JSON, dentro de **colecciones**.

**¿Por qué usarlo?**

* **Esquema flexible:** cada documento puede tener campos distintos, y la estructura evoluciona sin migraciones pesadas.
* **Modelo natural para aplicaciones:** un documento se parece al objeto que manejas en tu código (JavaScript, Python, Java...).
* **Datos relacionados juntos:** se pueden **embeber** subdocumentos y arreglos en un solo documento, evitando muchos `JOIN`.
* **Escalabilidad horizontal:** replicación y *sharding* integrados.
* **Consultas potentes:** índices, agregaciones, búsqueda de texto, geoespacial y más.

### Jerarquía de Objetos

| Concepto MongoDB | Equivalente en SQL | Descripción |
| :--- | :--- | :--- |
| **Base de datos** (`database`) | Esquema / Base de datos | Contenedor de colecciones. |
| **Colección** (`collection`) | Tabla | Grupo de documentos, normalmente de un mismo tema. |
| **Documento** (`document`) | Fila (tupla) | Registro individual en formato BSON. |
| **Campo** (`field`) | Columna | Par nombre-valor dentro del documento. |
| **Índice** (`index`) | Índice | Estructura que acelera consultas. |
| **`$lookup`** | `JOIN` | Unión entre colecciones en agregaciones. |
| **Pipeline de agregación** | `GROUP BY` + subconsultas | Procesamiento por etapas. |
| **Subdocumento / arreglo** | Tabla relacionada 1:N | Datos embebidos dentro del documento. |

### Anatomía de un Documento

```javascript
{
  _id: ObjectId("66f1c0a2b7d3a1c9e8f40a11"),
  nombre: "Ana Torres",
  edad: 28,
  activo: true,
  email: "ana@correo.com",
  direccion: {                       // subdocumento embebido
    ciudad: "Bogotá",
    pais: "Colombia"
  },
  intereses: ["sql", "mongodb", "node"],   // arreglo
  creado: ISODate("2026-11-09T10:00:00Z")
}
```

* **`_id`:** clave primaria obligatoria y **única** en la colección. Si no la envías, MongoDB genera un `ObjectId`.
* **BSON** (*Binary JSON*): formato binario con más tipos que JSON (fechas, enteros de 32/64 bits, `Decimal128`, `ObjectId`, binarios).
* **Límite:** un documento puede pesar hasta **16 MB**.
* **`ObjectId`:** 12 bytes (4 de marca de tiempo, 5 aleatorios, 3 de contador). Es casi único y **ordenable por fecha de creación**.

### Tipos BSON Frecuentes

| Tipo | Ejemplo | Nota |
| :--- | :--- | :--- |
| `String` | `"hola"` | UTF-8. |
| `Int32` / `Int64` | `NumberInt(5)` / `NumberLong(5)` | Enteros. |
| `Double` | `3.14` | Es el número por defecto en mongosh. |
| `Decimal128` | `NumberDecimal("19.99")` | Ideal para dinero. |
| `Boolean` | `true` | |
| `Date` | `ISODate("2026-11-09")` | Siempre se guarda en UTC. |
| `ObjectId` | `ObjectId()` | Identificador por defecto. |
| `Array` | `[1, 2, 3]` | Puede mezclar tipos. |
| `Object` | `{ a: 1 }` | Subdocumento. |
| `Null` | `null` | Valor nulo. |

---

## 2. mongosh: Comandos Básicos

**`mongosh`** es la consola interactiva (basada en JavaScript) para trabajar con MongoDB.

```javascript
// Conectarse (por defecto puerto 27017)
// mongosh "mongodb://localhost:27017"

show dbs                       // lista las bases de datos
use tienda                     // cambia a la base "tienda" (se crea al insertar datos)
db                             // muestra la base actual
show collections               // lista colecciones de la base actual

db.createCollection("productos")
db.productos.drop()            // elimina la colección
db.dropDatabase()              // elimina la base de datos actual

db.stats()                     // estadísticas de la base
db.productos.countDocuments()  // cuenta documentos
```

> **Detalle clave:** MongoDB crea bases de datos y colecciones **de forma perezosa**: aparecen cuando insertas el primer documento.

---

## 3. CRUD: Crear, Leer, Actualizar y Eliminar

### 3.1 Insertar (Create)

```javascript
// Un documento
db.clientes.insertOne({
  nombre: "Ana",
  email: "ana@correo.com",
  edad: 28
})

// Varios documentos
db.clientes.insertMany([
  { nombre: "Luis",  email: "luis@correo.com",  edad: 35 },
  { nombre: "Marta", email: "marta@correo.com", edad: 22 },
  { nombre: "Pedro", email: "pedro@correo.com", edad: 41 }
])

// ordered: false → sigue insertando aunque alguno falle
db.clientes.insertMany(
  [ { _id: 1 }, { _id: 1 }, { _id: 2 } ],
  { ordered: false }
)
```

* Cada inserción devuelve el `insertedId` (o `insertedIds`).
* Con `ordered: true` (por defecto) la inserción **se detiene en el primer error**.

### 3.2 Consultar (Read)

```javascript
db.clientes.find()                              // todos los documentos
db.clientes.find({ edad: 28 })                  // filtro por igualdad
db.clientes.findOne({ email: "ana@correo.com" })// primer documento que coincide
db.clientes.find({ edad: { $gte: 30 } })        // con operador de comparación
```

#### Proyección (Elegir Campos)

```javascript
// 1 = incluir, 0 = excluir (no se pueden mezclar, salvo con _id)
db.clientes.find({}, { nombre: 1, email: 1, _id: 0 })
```

#### Ordenar, Limitar y Saltar

```javascript
db.clientes
  .find({ edad: { $gt: 20 } })
  .sort({ edad: -1 })      // 1 = ascendente, -1 = descendente
  .skip(10)                // salta 10 documentos
  .limit(5)                // devuelve máximo 5
```

> **Orden lógico:** MongoDB aplica `sort`, luego `skip` y luego `limit`, sin importar el orden en que los escribas en la cadena.

### 3.3 Operadores de Consulta

| Categoría | Operador | Significado |
| :--- | :--- | :--- |
| **Comparación** | `$eq`, `$ne` | Igual / distinto. |
| | `$gt`, `$gte`, `$lt`, `$lte` | Mayor, mayor o igual, menor, menor o igual. |
| | `$in`, `$nin` | Pertenece / no pertenece a una lista. |
| **Lógicos** | `$and`, `$or`, `$nor` | Y, O, ni uno ni otro. |
| | `$not` | Niega una condición. |
| **Elemento** | `$exists` | El campo existe (o no). |
| | `$type` | El campo es de un tipo BSON dado. |
| **Evaluación** | `$regex` | Coincidencia con expresión regular. |
| | `$expr` | Usa expresiones de agregación (comparar campos entre sí). |
| **Arreglos** | `$all` | Contiene **todos** los valores indicados. |
| | `$elemMatch` | Un mismo elemento cumple varias condiciones. |
| | `$size` | El arreglo tiene exactamente n elementos. |

```javascript
// AND implícito: todas las condiciones a la vez
db.clientes.find({ edad: { $gte: 20, $lte: 40 }, activo: true })

// OR explícito
db.clientes.find({
  $or: [ { edad: { $lt: 18 } }, { edad: { $gt: 60 } } ]
})

// IN
db.productos.find({ categoria: { $in: ["libros", "musica"] } })

// Existencia y tipo
db.clientes.find({ telefono: { $exists: false } })
db.clientes.find({ edad: { $type: "int" } })

// Regex (insensible a mayúsculas)
db.clientes.find({ nombre: { $regex: "^an", $options: "i" } })

// Comparar dos campos del mismo documento
db.pedidos.find({ $expr: { $gt: ["$total", "$presupuesto"] } })
```

### 3.4 Consultar Subdocumentos y Arreglos

```javascript
// Subdocumento: notación de punto (entre comillas)
db.clientes.find({ "direccion.ciudad": "Bogotá" })

// Arreglo: contiene un valor
db.clientes.find({ intereses: "mongodb" })

// Arreglo: contiene todos
db.clientes.find({ intereses: { $all: ["sql", "mongodb"] } })

// Arreglo de subdocumentos: un MISMO elemento cumple ambas condiciones
db.pedidos.find({
  items: { $elemMatch: { producto: "Teclado", cantidad: { $gte: 2 } } }
})
```

> **Trampa clásica:** sin `$elemMatch`, las condiciones sobre un arreglo de subdocumentos pueden cumplirse con **elementos distintos**. Con `$elemMatch` deben cumplirse en el **mismo** elemento.

### 3.5 Actualizar (Update)

```javascript
// Primer documento que coincide
db.clientes.updateOne(
  { email: "ana@correo.com" },
  { $set: { edad: 29, "direccion.ciudad": "Medellín" } }
)

// Todos los que coinciden
db.clientes.updateMany(
  { activo: false },
  { $set: { estado: "inactivo" } }
)

// Reemplazo completo (conserva solo el _id)
db.clientes.replaceOne(
  { email: "pedro@correo.com" },
  { nombre: "Pedro", email: "pedro@correo.com", edad: 42 }
)

// Upsert: actualiza si existe, inserta si no
db.contadores.updateOne(
  { _id: "visitas" },
  { $inc: { total: 1 } },
  { upsert: true }
)
```

> **Importante:** `updateOne` y `updateMany` **requieren operadores** (`$set`, `$inc`...). Si pasas un documento sin operadores, falla; para reemplazar todo usa `replaceOne`.

#### Operadores de Actualización

| Operador | Efecto |
| :--- | :--- |
| `$set` | Asigna o crea un campo. |
| `$unset` | Elimina un campo. |
| `$inc` | Suma (o resta con negativo) un número. |
| `$mul` | Multiplica el valor. |
| `$rename` | Cambia el nombre de un campo. |
| `$min` / `$max` | Actualiza solo si el nuevo valor es menor / mayor. |
| `$currentDate` | Asigna la fecha actual. |
| `$setOnInsert` | Asigna valores solo cuando un `upsert` **inserta**. |

#### Operadores para Arreglos

| Operador | Efecto |
| :--- | :--- |
| `$push` | Agrega un elemento al final. |
| `$addToSet` | Agrega solo si no existe (evita duplicados). |
| `$pull` | Elimina los elementos que cumplan una condición. |
| `$pop` | Elimina el primero (`-1`) o el último (`1`). |
| `$each` | Modificador para agregar varios valores. |
| `$` | Operador posicional: el primer elemento que coincidió. |
| `$[]` | Todos los elementos del arreglo. |
| `$[ident]` | Elementos filtrados con `arrayFilters`. |

```javascript
db.clientes.updateOne(
  { email: "ana@correo.com" },
  {
    $push: { intereses: { $each: ["python", "docker"] } },
    $currentDate: { modificado: true }
  }
)

// Actualizar solo los elementos que cumplen una condición
db.pedidos.updateOne(
  { _id: 1 },
  { $set: { "items.$[it].estado": "enviado" } },
  { arrayFilters: [ { "it.cantidad": { $gte: 2 } } ] }
)
```

#### Buscar y Modificar en una Sola Operación Atómica

```javascript
db.tickets.findOneAndUpdate(
  { estado: "pendiente" },
  { $set: { estado: "en_proceso" } },
  { sort: { creado: 1 }, returnDocument: "after" }   // devuelve el documento ya actualizado
)
```

### 3.6 Eliminar (Delete)

```javascript
db.clientes.deleteOne({ email: "pedro@correo.com" })
db.clientes.deleteMany({ activo: false })
db.clientes.deleteMany({})          // vacía la colección (conserva índices)
db.clientes.drop()                  // elimina la colección completa
```

> **Comparación con SQL:** `deleteMany({})` es como `DELETE FROM tabla`; `drop()` es como `DROP TABLE`.

---

## 4. Pipeline de Agregación

El **pipeline de agregación** procesa los documentos **por etapas**: la salida de una etapa es la entrada de la siguiente. Es el equivalente a `GROUP BY`, `HAVING`, `JOIN` y subconsultas de SQL.

```javascript
db.coleccion.aggregate([
  { $match: { ... } },      // etapa 1
  { $group: { ... } },      // etapa 2
  { $sort:  { ... } }       // etapa 3
])
```

### Etapas Principales

| Etapa | Equivalente SQL | Función |
| :--- | :--- | :--- |
| `$match` | `WHERE` / `HAVING` | Filtra documentos. |
| `$group` | `GROUP BY` | Agrupa y calcula acumuladores. |
| `$project` | `SELECT` | Elige, renombra o calcula campos. |
| `$addFields` / `$set` | Columnas calculadas | Agrega campos sin quitar los demás. |
| `$sort` | `ORDER BY` | Ordena. |
| `$limit` / `$skip` | `LIMIT` / `OFFSET` | Pagina el resultado. |
| `$unwind` | Desanidar | Convierte cada elemento de un arreglo en un documento. |
| `$lookup` | `LEFT JOIN` | Une con otra colección. |
| `$count` | `COUNT(*)` | Cuenta documentos. |
| `$facet` | Varias consultas | Ejecuta varios sub-pipelines en paralelo. |
| `$bucket` | Rangos | Agrupa en intervalos. |
| `$out` / `$merge` | `INSERT ... SELECT` | Escribe el resultado en una colección. |

### Acumuladores de `$group`

| Acumulador | Función |
| :--- | :--- |
| `$sum` | Suma (o cuenta con `1`). |
| `$avg` | Promedio. |
| `$min` / `$max` | Mínimo / máximo. |
| `$first` / `$last` | Primer / último valor del grupo (según el orden previo). |
| `$push` | Arreglo con todos los valores. |
| `$addToSet` | Arreglo con valores únicos. |

### Ejemplo 1: Ventas por Categoría

```javascript
db.pedidos.aggregate([
  { $match: { estado: "pagado", fecha: { $gte: ISODate("2026-01-01") } } },
  { $group: {
      _id: "$categoria",                       // clave de agrupamiento
      total_ventas: { $sum: "$total" },
      promedio:     { $avg: "$total" },
      num_pedidos:  { $sum: 1 }
  } },
  { $match: { total_ventas: { $gt: 1000000 } } },   // equivale a HAVING
  { $sort: { total_ventas: -1 } },
  { $limit: 5 }
])
```

> **Regla de oro:** coloca `$match` y `$limit` **lo más temprano posible** para reducir los documentos que viajan por el pipeline y para que pueda usarse un índice.

### Ejemplo 2: `$unwind` para Arreglos

```javascript
// Cada pedido tiene un arreglo "items"; contamos unidades vendidas por producto
db.pedidos.aggregate([
  { $unwind: "$items" },
  { $group: {
      _id: "$items.producto",
      unidades: { $sum: "$items.cantidad" }
  } },
  { $sort: { unidades: -1 } }
])
```

### Ejemplo 3: `$lookup` (JOIN entre Colecciones)

```javascript
db.pedidos.aggregate([
  { $lookup: {
      from: "clientes",              // colección a unir
      localField: "id_cliente",      // campo en pedidos
      foreignField: "_id",           // campo en clientes
      as: "cliente"                  // arreglo resultante
  } },
  { $unwind: "$cliente" },           // convierte el arreglo en un subdocumento
  { $project: { _id: 0, id_pedido: 1, total: 1, "cliente.nombre": 1 } }
])
```

> **Ojo:** `$lookup` siempre devuelve un **arreglo** (puede venir vacío). Es el comportamiento de un `LEFT JOIN`; si no hay coincidencia, el arreglo queda vacío.

### Ejemplo 4: Campos Calculados

```javascript
db.productos.aggregate([
  { $project: {
      nombre: 1,
      precio: 1,
      precio_con_iva: { $round: [ { $multiply: ["$precio", 1.19] }, 2 ] },
      categoria_precio: {
        $switch: {
          branches: [
            { case: { $lt: ["$precio", 50000] },  then: "económico" },
            { case: { $lt: ["$precio", 200000] }, then: "medio" }
          ],
          default: "premium"
        }
      }
  } }
])
```

### Funciones de Ventana: `$setWindowFields`

Calcula métricas acumuladas sin colapsar documentos (similar a `OVER` en SQL; requiere MongoDB 5.0 o superior):

```javascript
db.movimientos.aggregate([
  { $setWindowFields: {
      partitionBy: "$id_cuenta",
      sortBy: { fecha: 1 },
      output: {
        saldo_acumulado: {
          $sum: "$valor",
          window: { documents: ["unbounded", "current"] }
        }
      }
  } }
])
```

---

## 5. Índices

Sin índices, MongoDB hace un **escaneo de colección** (`COLLSCAN`): revisa todos los documentos. Con un índice adecuado usa un **escaneo de índice** (`IXSCAN`). Los índices se implementan con **árboles B-tree**.

> El índice sobre `_id` se crea automáticamente en todas las colecciones.

### Tipos de Índices

| Tipo | Ejemplo | Uso |
| :--- | :--- | :--- |
| **Simple** | `createIndex({ email: 1 })` | Un solo campo. |
| **Compuesto** | `createIndex({ estado: 1, fecha: -1 })` | Varios campos; el orden importa. |
| **Único** | `createIndex({ email: 1 }, { unique: true })` | Impide valores repetidos. |
| **Multikey** | Automático sobre un campo arreglo | Indexa cada elemento del arreglo. |
| **Texto** | `createIndex({ descripcion: "text" })` | Búsqueda de texto completo. |
| **Geoespacial** | `createIndex({ ubicacion: "2dsphere" })` | Consultas por cercanía y área. |
| **Hashed** | `createIndex({ _id: "hashed" })` | Igualdad exacta y shard keys. |
| **TTL** | `createIndex({ creado: 1 }, { expireAfterSeconds: 3600 })` | Borra documentos vencidos automáticamente. |
| **Parcial** | `createIndex({ email: 1 }, { partialFilterExpression: { activo: true } })` | Indexa solo documentos que cumplen un filtro. |
| **Sparse** | `createIndex({ telefono: 1 }, { sparse: true })` | Omite documentos sin el campo. |
| **Comodín** | `createIndex({ "atributos.$**": 1 })` | Campos dinámicos o desconocidos. |

```javascript
db.clientes.createIndex({ email: 1 }, { unique: true })
db.pedidos.createIndex({ estado: 1, fecha: -1 })

db.clientes.getIndexes()              // lista los índices
db.clientes.dropIndex("email_1")      // elimina un índice por nombre

// Búsqueda de texto
db.articulos.createIndex({ titulo: "text", contenido: "text" })
db.articulos.find({ $text: { $search: "mongodb rendimiento" } })
```

### Regla ESR para Índices Compuestos

Ordena los campos del índice así: **E**quality (igualdad), **S**ort (orden), **R**ange (rango).

```javascript
// Consulta: estado igual a "pagado", rango de fechas, ordenado por total
db.pedidos.find({ estado: "pagado", fecha: { $gte: ISODate("2026-01-01") } }).sort({ total: -1 })

// Índice óptimo según ESR
db.pedidos.createIndex({ estado: 1, total: -1, fecha: 1 })
```

* **Prefijo del índice:** un índice `{ a: 1, b: 1, c: 1 }` sirve para consultas por `a`, por `a, b` y por `a, b, c`, pero **no** para consultas solo por `b` o `c`.
* **Índice de cobertura (*covered query*):** si todos los campos del filtro y de la proyección están en el índice (y se excluye `_id` si no está incluido), MongoDB responde **solo desde el índice**, sin leer documentos.

### Analizar con `explain()`

```javascript
db.pedidos.find({ estado: "pagado" }).explain("executionStats")
```

| Campo a revisar | Qué indica |
| :--- | :--- |
| `winningPlan.stage` | `COLLSCAN` (malo en colecciones grandes) o `IXSCAN` (usa índice). |
| `totalDocsExamined` | Documentos leídos del disco. |
| `totalKeysExamined` | Entradas de índice recorridas. |
| `nReturned` | Documentos devueltos. |
| `executionTimeMillis` | Tiempo de ejecución. |

> **Regla práctica:** una consulta saludable tiene `totalDocsExamined` cercano a `nReturned`. Si examina muchísimos más documentos de los que devuelve, necesita un índice mejor.

### Costos de los Índices

* Ocupan **espacio** y memoria RAM.
* Cada `INSERT`, `UPDATE` y `DELETE` debe **mantener** todos los índices afectados.
* No indexes todo: crea índices según las consultas reales de tu aplicación.

---

## 6. Modelado de Datos: Embeber vs Referenciar

En MongoDB el diseño se guía por **cómo consulta la aplicación**, no por la normalización. La pregunta central: *¿los datos se leen juntos?*

### Embeber (Subdocumentos)

```javascript
{
  _id: 1,
  nombre: "Ana",
  direcciones: [
    { tipo: "casa",    ciudad: "Bogotá" },
    { tipo: "trabajo", ciudad: "Bogotá" }
  ]
}
```

### Referenciar (Como Clave Foránea)

```javascript
// Colección pedidos
{ _id: 100, id_cliente: 1, total: 250000 }

// Colección clientes
{ _id: 1, nombre: "Ana" }
```

### ¿Cuál Elegir?

| Situación | Recomendación |
| :--- | :--- |
| Relación **1:pocos** y los datos se leen juntos | **Embeber**. |
| El subdocumento no tiene sentido sin el padre | **Embeber**. |
| Relación **1:muchos** con crecimiento ilimitado | **Referenciar**. |
| Relación **N:M** | **Referenciar** (arreglo de ids en uno o ambos lados). |
| El dato se consulta o actualiza de forma independiente | **Referenciar**. |
| Necesitas atomicidad sobre todo el conjunto | **Embeber** (una operación sobre un documento es atómica). |
| Datos muy duplicados que cambian a menudo | **Referenciar**. |

### Patrones de Diseño Comunes

* **Referencia extendida:** guarda una copia de los pocos campos del documento relacionado que más se leen (por ejemplo, el nombre del cliente dentro del pedido) para evitar `$lookup`.
* **Subconjunto (*subset*):** embebe solo los datos más usados (por ejemplo, las 10 últimas reseñas) y deja el resto en otra colección.
* **Calculado (*computed*):** guarda totales o contadores precalculados para no recalcularlos en cada lectura.
* **Cubetas (*bucket*):** agrupa datos de series temporales en un documento por intervalo (por ejemplo, un documento por hora con las lecturas de un sensor).
* **Polimórfico:** documentos de formas distintas en una misma colección, distinguidos por un campo `tipo`.

### Anti-Patrones a Evitar

* **Arreglos sin límite:** un arreglo que crece sin control puede llegar al límite de 16 MB y degrada el rendimiento.
* **Demasiados `$lookup`:** si necesitas unir constantemente, probablemente conviene embeber.
* **Colecciones o índices innecesarios en exceso.**
* **Nombres de campos largos en colecciones enormes:** el nombre se almacena en cada documento.

---

## 7. Validación de Esquema

Aunque MongoDB es flexible, puedes **exigir reglas** con `$jsonSchema`:

```javascript
db.createCollection("clientes", {
  validator: {
    $jsonSchema: {
      bsonType: "object",
      required: ["nombre", "email"],
      properties: {
        nombre: { bsonType: "string", minLength: 2 },
        email:  { bsonType: "string", pattern: "^.+@.+$" },
        edad:   { bsonType: "int", minimum: 0, maximum: 120 }
      }
    }
  },
  validationLevel: "strict",     // valida inserciones y actualizaciones
  validationAction: "error"      // rechaza (con "warn" solo avisa en el log)
})
```

* **`validationLevel`:** `strict` (todos los documentos) o `moderate` (solo los que ya cumplían).
* **`validationAction`:** `error` rechaza el documento; `warn` lo acepta y registra una advertencia.
* Para una colección existente se usa `db.runCommand({ collMod: "clientes", validator: ... })`.

---

## 8. Transacciones y Atomicidad

### Atomicidad a Nivel de Documento

Cualquier operación sobre **un solo documento** (incluidos sus subdocumentos y arreglos) es **atómica**. Por eso un buen modelado con documentos embebidos suele eliminar la necesidad de transacciones.

### Transacciones Multidocumento (ACID)

Disponibles desde la versión 4.0 en *replica sets* y desde la 4.2 en clústeres con *sharding*. **Requieren un *replica set*** (incluso uno de un solo nodo).

```javascript
const sesion = db.getMongo().startSession()
const cuentas = sesion.getDatabase("banco").cuentas

try {
  sesion.startTransaction({
    readConcern:  { level: "snapshot" },
    writeConcern: { w: "majority" }
  })

  cuentas.updateOne({ _id: 1001 }, { $inc: { saldo: -300000 } })
  cuentas.updateOne({ _id: 1002 }, { $inc: { saldo:  300000 } })

  sesion.commitTransaction()
} catch (e) {
  sesion.abortTransaction()
  throw e
} finally {
  sesion.endSession()
}
```

| Comando | Equivalente SQL |
| :--- | :--- |
| `startTransaction()` | `BEGIN` |
| `commitTransaction()` | `COMMIT` |
| `abortTransaction()` | `ROLLBACK` |

* Las transacciones tienen un **límite de tiempo** (60 segundos por defecto) y añaden costo; úsalas solo cuando haga falta.
* En los drivers oficiales se recomienda `withTransaction()`, que reintenta automáticamente ante errores transitorios.
* Un error de escritura concurrente sobre el mismo documento produce un **conflicto de escritura** (`WriteConflict`); la transacción debe reintentarse.

### Control de Concurrencia sin Transacciones

```javascript
// Evitar "actualización perdida": operación atómica relativa
db.cuentas.updateOne({ _id: 1001 }, { $inc: { saldo: -300000 } })

// Control optimista con campo de versión
db.cuentas.updateOne(
  { _id: 1001, version: 7 },
  { $set: { saldo: 500000 }, $inc: { version: 1 } }
)
// Si modifiedCount es 0, otro proceso cambió el documento: reintentar.
```

---

## 9. Replicación y Alta Disponibilidad

Un **replica set** es un grupo de servidores `mongod` con los mismos datos.

| Rol | Función |
| :--- | :--- |
| **Primario** | Único nodo que acepta **escrituras**. |
| **Secundarios** | Copian los cambios del primario leyendo su **oplog**. |
| **Árbitro** | Vota en elecciones, pero no guarda datos. |

* Si el primario cae, los secundarios hacen una **elección** y uno pasa a ser el nuevo primario (conmutación automática).
* El **oplog** es una colección especial con el registro de operaciones que se replican.
* Se recomienda un número **impar** de nodos con voto (mínimo 3) para alcanzar mayoría.

### Write Concern, Read Concern y Read Preference

| Ajuste | Opciones | Efecto |
| :--- | :--- | :--- |
| **Write concern** | `w: 1`, `w: "majority"` | Cuántos nodos deben confirmar la escritura. `majority` es la opción más segura. |
| | `j: true` | Espera a que se escriba en el diario (*journal*). |
| **Read concern** | `local`, `majority`, `snapshot` | Qué nivel de consistencia tienen los datos leídos. |
| **Read preference** | `primary`, `secondary`, `nearest`... | Desde qué nodo se lee. Leer de secundarios puede devolver datos **ligeramente desactualizados**. |

```javascript
db.pedidos.insertOne(
  { total: 100000 },
  { writeConcern: { w: "majority", j: true } }
)
```

---

## 10. Sharding (Escalado Horizontal)

El **sharding** reparte los datos de una colección entre varios servidores (*shards*), cuando un solo servidor ya no alcanza.

| Componente | Rol |
| :--- | :--- |
| **Shard** | Guarda una parte de los datos (normalmente un replica set). |
| **mongos** | Enrutador al que se conectan las aplicaciones. |
| **Config servers** | Guardan los metadatos y la ubicación de los datos. |

* **Shard key:** campo (o campos) que decide en qué *shard* cae cada documento. Es la decisión de diseño más importante.
* **Estrategias:** por **rango** (buenas consultas por intervalos, riesgo de concentrar escrituras) o **hashed** (distribución uniforme, peor para rangos).
* Una buena *shard key* tiene **alta cardinalidad**, **distribución uniforme** y aparece en las **consultas más frecuentes**.
* Una mala clave (por ejemplo, una fecha creciente) crea un **punto caliente**: todas las escrituras nuevas van a un mismo *shard*.

```javascript
sh.enableSharding("tienda")
sh.shardCollection("tienda.pedidos", { id_cliente: "hashed" })
```

---

## 11. Change Streams

Permiten **escuchar en tiempo real** los cambios de una colección, base de datos o clúster (requiere *replica set*):

```javascript
const cursor = db.pedidos.watch([
  { $match: { operationType: { $in: ["insert", "update"] } } }
])

while (cursor.hasNext()) {
  printjson(cursor.next())
}
```

Útiles para notificaciones, sincronización con otros sistemas y arquitecturas orientadas a eventos.

---

## 12. Seguridad Básica

* **Autenticación:** activar `--auth` (o `security.authorization: enabled` en la configuración). Por defecto, un servidor local sin esto no exige credenciales.
* **Autorización por roles (RBAC):** `read`, `readWrite`, `dbAdmin`, `userAdmin`, `clusterAdmin`, `root`.
* **Cifrado:** TLS en tránsito y cifrado en reposo.
* **Principio de mínimo privilegio:** cada aplicación debe usar un usuario con solo los permisos necesarios.

```javascript
use admin
db.createUser({
  user: "app_tienda",
  pwd: passwordPrompt(),                 // pide la contraseña sin dejarla en el historial
  roles: [ { role: "readWrite", db: "tienda" } ]
})
```

> **Nunca** dejes una instancia expuesta a Internet sin autenticación ni *firewall*: es una de las causas más comunes de filtraciones de datos en MongoDB.

---

## 13. Uso desde una Aplicación (Node.js)

```javascript
import { MongoClient } from "mongodb";

const cliente = new MongoClient(process.env.MONGODB_URI);

async function main() {
  try {
    await cliente.connect();
    const db = cliente.db("tienda");
    const clientes = db.collection("clientes");

    await clientes.insertOne({ nombre: "Ana", edad: 28 });

    const mayores = await clientes.find({ edad: { $gte: 18 } }).toArray();
    console.log(mayores);
  } finally {
    await cliente.close();
  }
}

main().catch(console.error);
```

* Guarda la cadena de conexión en una **variable de entorno**, no dentro del código.
* Reutiliza **una sola instancia** de `MongoClient`; ya administra un *pool* de conexiones.
* **Mongoose** es una librería popular que añade esquemas y validación del lado de la aplicación sobre MongoDB.

---

## 14. Importar, Exportar y Respaldar

| Herramienta | Formato | Uso |
| :--- | :--- | :--- |
| `mongodump` / `mongorestore` | BSON | **Respaldo y restauración** completos, conservan tipos e índices. |
| `mongoexport` / `mongoimport` | JSON o CSV | Intercambio de datos con otras herramientas. |

```bash
mongodump --uri="mongodb://localhost:27017" --db=tienda --out=./respaldo
mongorestore --uri="mongodb://localhost:27017" ./respaldo

mongoexport --db=tienda --collection=clientes --out=clientes.json
mongoimport --db=tienda --collection=clientes --file=clientes.json --jsonArray
```

---

## 15. MongoDB vs SQL: Cuándo Usar Cada Uno

| Aspecto | SQL (relacional) | MongoDB (documentos) |
| :--- | :--- | :--- |
| **Esquema** | Rígido y definido de antemano. | Flexible, validable opcionalmente. |
| **Relaciones** | `JOIN` y claves foráneas. | Embeber o referenciar; `$lookup` limitado. |
| **Integridad referencial** | Garantizada por el motor. | Responsabilidad de la aplicación. |
| **Transacciones** | Nativas y centrales. | Disponibles, pero conviene evitarlas con buen modelado. |
| **Escalado** | Vertical (y réplicas de lectura). | Horizontal con *sharding* integrado. |
| **Consultas complejas y reportes** | Muy fuertes. | Posibles con agregaciones, más verbosas. |
| **Normalización** | Recomendada (3FN). | Se **desnormaliza** según las lecturas. |

**Elige MongoDB cuando:** los datos son jerárquicos o cambian de forma, necesitas escalar horizontalmente, o manejas catálogos, perfiles, contenido, eventos e IoT.

**Elige SQL cuando:** hay muchas relaciones complejas, integridad estricta y transacciones multitabla frecuentes (banca, contabilidad, inventarios muy relacionales).

---

## 16. Buenas Prácticas y Errores Comunes

### Buenas Prácticas

* **Diseña según las consultas:** modela pensando en cómo leerás los datos.
* Crea **índices** para tus consultas frecuentes y revisa con `explain()`.
* Aplica **`$match` y `$limit` temprano** en los pipelines.
* Usa **proyecciones** para traer solo los campos necesarios.
* Evita **arreglos que crecen sin límite**.
* Usa **validación de esquema** para proteger la calidad de los datos.
* Prefiere operaciones **atómicas** (`$inc`, `$push`) frente a leer, modificar y escribir.
* Usa `Decimal128` para dinero, nunca `Double`.
* Pagina con **rangos sobre un índice** (por ejemplo, `_id` mayor que el último visto) en lugar de `skip` con valores grandes.
* Activa **autenticación**, TLS y haz **respaldos** periódicos.

### Errores Frecuentes

| Error o problema | Causa | Solución |
| :--- | :--- | :--- |
| `E11000 duplicate key error` | Valor repetido en `_id` o en un índice único. | Verificar el dato, o usar `upsert` / `updateOne`. |
| Consulta muy lenta | `COLLSCAN` por falta de índice. | Crear el índice adecuado y revisar con `explain()`. |
| `Document failed validation` | El documento incumple el `$jsonSchema`. | Corregir los datos o ajustar el validador. |
| `Unknown modifier` / `update document requires atomic operators` | Se envió un documento sin `$set` a `updateOne`. | Usar operadores o `replaceOne`. |
| `Document too large` (16 MB) | Documento o arreglo demasiado grande. | Referenciar o usar el patrón de subconjunto. |
| `WriteConflict` en transacción | Dos operaciones modifican el mismo documento. | Reintentar la transacción. |
| `Sort exceeded memory limit` | Ordenamiento grande sin índice. | Crear un índice que cubra el `sort` o usar `allowDiskUse`. |
| Datos desactualizados al leer | Lectura desde un secundario. | Usar `readPreference: primary` o `readConcern: majority`. |
| `$lookup` lento | Falta índice en el campo `foreignField`. | Indexar el campo de la colección unida. |
| Comparaciones que no coinciden | Tipos distintos (`"5"` frente a `5`). | Guardar y consultar con el mismo tipo BSON. |

### Resumen Rápido

| Necesito... | Uso |
| :--- | :--- |
| Insertar uno o varios documentos | `insertOne` / `insertMany` |
| Buscar con filtros | `find` / `findOne` |
| Cambiar campos de un documento | `updateOne` con `$set` |
| Contar o sumar por grupos | `aggregate` con `$group` |
| Unir dos colecciones | `$lookup` |
| Recorrer un arreglo como filas | `$unwind` |
| Acelerar una consulta | `createIndex` + `explain()` |
| Borrar documentos vencidos solos | Índice **TTL** |
| Exigir campos y tipos | Validación `$jsonSchema` |
| Operar varios documentos de forma atómica | Transacción en *replica set* |
| Evitar perder datos si cae el primario | Write concern `w: "majority"` |
| Repartir datos entre servidores | **Sharding** con buena *shard key* |
| Reaccionar a cambios en tiempo real | **Change streams** |