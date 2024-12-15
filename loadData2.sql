-- Limpiar tablas en orden inverso para evitar violaciones de claves foráneas
TRUNCATE TABLE detalle_orden CASCADE;
TRUNCATE TABLE orden CASCADE;
TRUNCATE TABLE cliente CASCADE;
TRUNCATE TABLE producto CASCADE;
TRUNCATE TABLE categoria CASCADE;


-- =============================
-- Poblar tabla usuario
-- =============================
INSERT INTO usuario (id_usuario, nombre, email, contrasena) VALUES
                                                                (1, 'Juan Pérez', 'juan.perez@example.com', 'password123'),
                                                                (2, 'María López', 'maria.lopez@example.com', 'securepassword'),
                                                                (3, 'Pedro Gómez', 'pedro.gomez@example.com', 'mypassword'),
                                                                (4, 'Ana Torres', 'ana.torres@example.com', 'password456'),
                                                                (5, 'Carlos Sánchez', 'carlos.sanchez@example.com', 'password789');

-- =============================
-- Poblar tabla categoria
-- =============================
INSERT INTO categoria (id_categoria, nombre) VALUES
                                                 (1, 'Electrónica'),
                                                 (2, 'Hogar'),
                                                 (3, 'Ropa'),
                                                 (4, 'Juguetes'),
                                                 (5, 'Deportes');

-- =============================
-- Poblar tabla producto
-- =============================
INSERT INTO producto (id_producto, nombre, descripcion, precio, stock, estado, id_categoria) VALUES
                                                                                                 (1, 'Smart TV 4K', 'Televisor de última generación', 500000.00, 10, 'Disponible', 1),
                                                                                                 (2, 'Licuadora', 'Licuadora de alta potencia', 20000.00, 50, 'Disponible', 2),
                                                                                                 (3, 'Polera', 'Polera básica', 10000.00, 100, 'Disponible', 3);

-- =============================
-- Poblar tabla cliente
-- =============================
INSERT INTO cliente (id_cliente, nombre, direccion, email, telefono, posicion, latitud, longitud) VALUES
                                                                                                      (1, 'Sofía Martínez', 'Calle 123', 'sofia.martinez@example.com', '123456789', 'Calle 123', '0.0', '0.0'),
                                                                                                      (2, 'Diego Torres', 'Avenida 456', 'diego.torres@example.com', '987654321', 'Avenida 456', '0.0', '0.0'),
                                                                                                      (3, 'Laura Ramírez', 'Boulevard 789', 'laura.ramirez@example.com', '456123789', 'Boulevard 789', '0.0', '0.0');

-- =============================
-- Poblar tabla pos_usuario
-- =============================
INSERT INTO pos_usuario (id_cliente, latitud, longitud, geom) VALUES
                                                                  ('1', 0.0, 0.0, ST_SetSRID(ST_MakePoint(0.0, 0.0), 4326)),
                                                                  ('2', 0.0, 0.0, ST_SetSRID(ST_MakePoint(0.0, 0.0), 4326)),
                                                                  ('3', 0.0, 0.0, ST_SetSRID(ST_MakePoint(0.0, 0.0), 4326));

-- =============================
-- Poblar tabla almacen
-- =============================
INSERT INTO almacen (id_almacen, nombre, posicion, latitud, longitud) VALUES
                                                                          (1, 'Almacén Central', 'Calle Principal 1', '0.0', '0.0'),
                                                                          (2, 'Almacén Norte', 'Avenida Norte 2', '1.0', '1.0');

-- =============================
-- Poblar tabla pos_almacen
-- =============================
INSERT INTO pos_almacen (id_almacen, latitud, longitud, geom) VALUES
                                                                  (1, 0.0, 0.0, ST_SetSRID(ST_MakePoint(0.0, 0.0), 4326)),
                                                                  (2, 1.0, 1.0, ST_SetSRID(ST_MakePoint(1.0, 1.0), 4326));

-- =============================
-- Poblar tabla orden
-- =============================
INSERT INTO orden (id_orden, fecha_orden, estado, id_cliente, id_almacen, total) VALUES
                                                                                     (1, '2024-12-01 12:00:00', 'Pagada', 1, 1, 500000.00),
                                                                                     (2, '2024-12-02 15:00:00', 'Pendiente', 2, 2, 200000.00);

-- =============================
-- Poblar tabla detalle_orden
-- =============================
INSERT INTO detalle_orden (id_detalle, id_orden, id_producto, cantidad, precio_unitario) VALUES
                                                                                             (1, 1, 1, 2, 500000.00),
                                                                                             (2, 2, 2, 3, 20000.00);

-- =============================
-- Poblar tabla auditoria
-- =============================
INSERT INTO auditoria (id_auditoria, accion, nombre_tabla, id_registro, usuario, descripcion) VALUES
                                                                                                  (1, 'INSERT', 'usuario', 1, 'admin', '{"nombre": "Juan Pérez", "email": "juan.perez@example.com"}'),
                                                                                                  (2, 'INSERT', 'categoria', 2, 'admin', '{"nombre": "Electrónica"}');
