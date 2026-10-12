# Modelos editables V30

01_Modelo_relacional_completo.dia: 21 tablas y 31 relaciones, con todos los campos.
02 a 05: vistas por dominio con claves y campos de referencia.
06_Casos_uso_alto_nivel: nueve casos y siete actores, SVG/PNG y fuente PlantUML.

R01 a R31 corresponden al catálogo del Word y Excel. Cardinalidad: padre por hijo : hijos por padre. Ejemplo 1 : 0..N significa que cada hijo requiere un padre y el padre puede tener cero o muchos hijos.

Los .dia son XML GZip con objetos estándar editables y conexiones ancladas. Se comprobó estructura XML, IDs y destinos; falta validación dentro de la aplicación de escritorio Dia. Los SVG son vectoriales.
