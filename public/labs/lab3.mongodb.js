/* global use, db */
// ============================================================================
// AUTOR:        Estudiante Ingeniería de Sistemas
// FECHA:        18/11/2026
// VERSIÓN:      1.1
// DESCRIPCIÓN:  Laboratorio Completo de MongoDB (CRUD, Patrones de Diseño NoSQL,
//               Índices Compuestos Multi-llave y Framework de Agregación).
// ============================================================================

use('lab_tienda_nosql');

// Limpieza inicial para ejecución repetible
db.productos.drop();
db.pedidos.drop();
db.lecturas_iot.drop();

// ============================================================================
// PASO 1: INSERCIÓN CON PATRONES ATTRIBUTE, SUBSET Y COMPUTED (insertMany)
// ============================================================================
db.productos.insertMany([
  {
    _id: "PROD-101",
    nombre: "Servidor Rack PowerEdge R750",
    categoria: "Servidores",
    precio: 18500000,
    stock: 10,
    activo: true,
    etiquetas: ["enterprise", "datacenter", "linux"],
    // COMPUTED PATTERN: métricas precalculadas para lectura instantánea
    total_unidades_vendidas: 45,
    rating_promedio: 4.9,
    // ATTRIBUTE PATTERN: especificaciones heterogéneas bajo llave uniforme {k, v}
    specs: [
      { k: "RAM", v: "64GB DDR4" },
      { k: "Procesador", v: "Intel Xeon Silver" },
      { k: "Almacenamiento", v: "2TB NVMe" }
    ],
    // SUBSET PATTERN: solo las 2 reseñas más recientes embebidas en el documento
    ultimas_resenas: [
      { usuario: "Ana R.", calificacion: 5, comentario: "Rendimiento impecable 24/7" },
      { usuario: "Carlos M.", calificacion: 5, comentario: "Excelente disipación térmica" }
    ]
  },
  {
    _id: "PROD-102",
    nombre: "Monitor 27 4K IPS",
    categoria: "Periféricos",
    precio: 1200000,
    stock: 8,
    activo: true,
    etiquetas: ["pantalla", "oficina", "4k"],
    total_unidades_vendidas: 120,
    rating_promedio: 4.7,
    specs: [
      { k: "Resolucion", v: "3840x2160" },
      { k: "Refresco", v: "144Hz" },
      { k: "Panel", v: "IPS" }
    ],
    ultimas_resenas: [
      { usuario: "Laura G.", calificacion: 5, comentario: "Colores muy precisos para diseño" }
    ]
  },
  {
    _id: "PROD-103",
    nombre: "Teclado Mecánico Industrial",
    categoria: "Periféricos",
    precio: 450000,
    stock: 4,
    activo: true,
    etiquetas: ["oficina", "ergonomico", "mecanico"],
    total_unidades_vendidas: 85,
    rating_promedio: 4.5,
    specs: [
      { k: "Switch", v: "Tactil Brown" },
      { k: "Conexion", v: "USB-C" }
    ],
    ultimas_resenas: []
  }
]);

// ============================================================================
// PASO 2: EXTENDED REFERENCE Y BUCKET PATTERN (pedidos y lecturas_iot)
// ============================================================================
db.pedidos.insertMany([
  {
    _id: "PED-9001",
    fecha: new Date("2026-11-15T10:30:00Z"),
    estado: "COMPLETADO",
    // EXTENDED REFERENCE: datos clave del cliente embebidos para evitar $lookup
    cliente: {
      cliente_id: "CLI-501",
      nombre: "Ana Ruiz",
      ciudad: "Bogotá"
    },
    items: [
      { producto_id: "PROD-101", nombre: "Servidor Rack PowerEdge R750", cantidad: 1, precio_unitario: 18500000 },
      { producto_id: "PROD-102", nombre: "Monitor 27 4K IPS", cantidad: 2, precio_unitario: 1200000 }
    ],
    total_pagado: 20900000
  }
]);

// BUCKET PATTERN: agrupación horaria de lecturas de temperatura del Datacenter
db.lecturas_iot.insertOne({
  sensor_id: "SEN-RACK-01",
  ubicacion: "Datacenter Bogotá Norte",
  hora_inicio: new Date("2026-11-17T14:00:00Z"),
  n_lecturas: 3,
  suma_temperatura: 64.5,
  lecturas: [
    { minuto: 0, temp_c: 21.2 },
    { minuto: 20, temp_c: 21.5 },
    { minuto: 40, temp_c: 21.8 }
  ]
});

// ============================================================================
// PASO 3: CREACIÓN DE ÍNDICES ESTRATÉGICOS (createIndex)
// ============================================================================
// Índice compuesto multi-llave para el Attribute Pattern
db.productos.createIndex({ "specs.k": 1, "specs.v": 1 });

// Índice compuesto por igualdad y ordenamiento descendente
db.productos.createIndex({ categoria: 1, precio: -1 });

// Verificación: lista de índices creados (deben aparecer 3 con el _id_)
db.productos.getIndexes();

// ============================================================================
// PASO 4: CRUD - UPDATE, READ, DELETE
// ============================================================================

// 4.1 Incrementar stock (+5) y contador de ventas (+2) y añadir etiqueta "gamer"
db.productos.updateOne(
  { _id: "PROD-102" },
  {
    $inc: { stock: 5, total_unidades_vendidas: 2 },
    $push: { etiquetas: "gamer" }
  }
);

// 4.2 Consulta usando Attribute Pattern ($elemMatch) y Proyección
db.productos.find(
  {
    specs: { $elemMatch: { k: "Panel", v: "IPS" } },
    precio: { $lt: 1500000 }
  },
  { _id: 0, nombre: 1, precio: 1, stock: 1, etiquetas: 1 }
);

// 4.3 Verificar que la consulta 4.2 usa el índice multi-llave (debe decir IXSCAN)
db.productos.find(
  { specs: { $elemMatch: { k: "Panel", v: "IPS" } } }
).explain("executionStats").queryPlanner.winningPlan;

// 4.4 SUBSET PATTERN: agregar una reseña nueva al inicio y conservar solo las 2 más recientes
db.productos.updateOne(
  { _id: "PROD-101" },
  {
    $push: {
      ultimas_resenas: {
        $each: [{ usuario: "Pedro S.", calificacion: 4, comentario: "Buen equipo, ruido moderado" }],
        $position: 0,
        $slice: 2
      }
    }
  }
);

// 4.5 BUCKET PATTERN: registrar una nueva lectura en el bucket de la hora
db.lecturas_iot.updateOne(
  { sensor_id: "SEN-RACK-01", hora_inicio: new Date("2026-11-17T14:00:00Z") },
  {
    $push: { lecturas: { minuto: 50, temp_c: 22.0 } },
    $inc: { n_lecturas: 1, suma_temperatura: 22.0 }
  }
);

// 4.6 DELETE: insertar un producto temporal y eliminarlo
db.productos.insertOne({
  _id: "PROD-999",
  nombre: "Producto temporal de prueba",
  categoria: "Pruebas",
  precio: 1000,
  stock: 1,
  activo: false,
  etiquetas: []
});
db.productos.deleteOne({ _id: "PROD-999" });

// Debe devolver 3 (los productos originales)
db.productos.countDocuments();

// ============================================================================
// PASO 5: PIPELINES DE AGREGACIÓN ($match, $unwind, $group, $lookup, $bucket)
// ============================================================================

// 5.1 Agrupamiento por categoría calculando inventario total y precio promedio
db.productos.aggregate([
  { $match: { activo: true } },
  {
    $group: {
      _id: "$categoria",
      total_productos: { $sum: 1 },
      unidades_stock: { $sum: "$stock" },
      precio_promedio: { $avg: "$precio" }
    }
  },
  { $sort: { precio_promedio: -1 } }
]);

// 5.2 Desanidar etiquetas ($unwind) y obtener el Top 3 de etiquetas más frecuentes
db.productos.aggregate([
  { $unwind: "$etiquetas" },
  {
    $group: {
      _id: "$etiquetas",
      frecuencia: { $sum: 1 }
    }
  },
  { $sort: { frecuencia: -1, _id: 1 } },
  { $limit: 3 }
]);

// 5.3 Segmentación de productos por rangos de precio ($bucket)
db.productos.aggregate([
  {
    $bucket: {
      groupBy: "$precio",
      boundaries: [0, 1000000, 5000000],
      default: "5000000_o_mas",
      output: {
        cantidad_productos: { $sum: 1 },
        lista_productos: { $push: "$nombre" }
      }
    }
  }
]);

// 5.4 $lookup: ventas por categoría uniendo pedidos con productos
db.pedidos.aggregate([
  { $unwind: "$items" },
  {
    $lookup: {
      from: "productos",
      localField: "items.producto_id",
      foreignField: "_id",
      as: "producto"
    }
  },
  { $unwind: "$producto" },
  {
    $group: {
      _id: "$producto.categoria",
      unidades_vendidas: { $sum: "$items.cantidad" },
      ingresos: { $sum: { $multiply: ["$items.cantidad", "$items.precio_unitario"] } }
    }
  },
  { $sort: { ingresos: -1 } }
]);

// 5.5 Temperatura promedio por bucket horario (usa los valores pre-agregados)
db.lecturas_iot.aggregate([
  {
    $project: {
      _id: 0,
      sensor_id: 1,
      hora_inicio: 1,
      n_lecturas: 1,
      temp_promedio: { $divide: ["$suma_temperatura", "$n_lecturas"] }
    }
  }
]);