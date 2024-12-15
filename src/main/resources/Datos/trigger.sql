CREATE TABLE auditoria (
       id_auditoria SERIAL PRIMARY KEY,
       accion VARCHAR(10),
       nombre_tabla VARCHAR(50),
       id_registro BIGINT,
       usuario VARCHAR(50),
       fecha TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
       descripcion TEXT
);

CREATE OR REPLACE FUNCTION auditar_accion()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        INSERT INTO auditoria (accion, nombre_tabla, id_registro, usuario, descripcion)
        VALUES ('INSERT', TG_TABLE_NAME, NEW.id_cliente, current_user, row_to_json(NEW)::text);
RETURN NEW;
ELSIF TG_OP = 'UPDATE' THEN
        INSERT INTO auditoria (accion, nombre_tabla, id_registro, usuario, descripcion)
        VALUES ('UPDATE', TG_TABLE_NAME, NEW.id_cliente, current_user, row_to_json(NEW)::text);
RETURN NEW;
ELSIF TG_OP = 'DELETE' THEN
        INSERT INTO auditoria (accion, nombre_tabla, id_registro, usuario, descripcion)
        VALUES ('DELETE', TG_TABLE_NAME, OLD.id_cliente, current_user, row_to_json(OLD)::text);
RETURN OLD;
END IF;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_auditoria
    AFTER INSERT OR UPDATE OR DELETE ON cliente
    FOR EACH ROW EXECUTE FUNCTION auditar_accion();


CREATE TABLE devoluciones (
                              id_devolucion SERIAL PRIMARY KEY,
                              id_orden INTEGER NOT NULL,
                              id_producto INTEGER NOT NULL,
                              cantidad INTEGER NOT NULL,
                              fecha_devolucion TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE OR REPLACE FUNCTION gestionar_devolucion()
RETURNS TRIGGER AS $$
DECLARE
nueva_cantidad INTEGER;
BEGIN
    -- Actualizar el stock del producto
UPDATE producto
SET stock = stock + NEW.cantidad
WHERE id_producto = NEW.id_producto;

-- Verificar si la orden debe actualizar su estado
IF (SELECT COUNT(*) FROM detalle_orden WHERE id_orden = NEW.id_orden AND cantidad > 0) = 0 THEN
UPDATE orden
SET estado = 'devuelto'
WHERE id_orden = NEW.id_orden;
END IF;

RETURN NEW;
END;
$$ LANGUAGE plpgsql;


CREATE TRIGGER trigger_gestionar_devolucion
    AFTER INSERT ON devoluciones
    FOR EACH ROW
    EXECUTE FUNCTION gestionar_devolucion();


INSERT INTO devoluciones (id_orden, id_producto, cantidad)
VALUES (1, 2, 3);


---------------------------------- #################################----------------
-- COSAS DEL LABORATORIO 2


-- Creamos un trigger que almacene la posicion del usuario segun su geometría
-- longitud y latitud.
CREATE OR REPLACE FUNCTION insertar_pos_usuario() RETURNS TRIGGER
LANGUAGE plpgsql
AS
$$
BEGIN
INSERT INTO pos_usuario (id_cliente, latitud, longitud, geom)
VALUES (
           NEW.id_cliente,
           CAST(NEW.latitud AS DOUBLE PRECISION),
           CAST(NEW.longitud AS DOUBLE PRECISION),
           ST_SetSRID(ST_MakePoint(CAST(NEW.longitud AS DOUBLE PRECISION), CAST(NEW.latitud AS DOUBLE PRECISION)), 4326)
       )
    ON CONFLICT (id_cliente) DO UPDATE
                                     SET
                                     latitud = EXCLUDED.latitud,
                                     longitud = EXCLUDED.longitud,
                                     geom = EXCLUDED.geom;

RETURN NEW;
END;
$$;

ALTER FUNCTION insertar_pos_usuario() OWNER TO postgres;


-- Cada vez que se haga un post o un update, se activa el metodo
CREATE TRIGGER trg_insertar_pos_usuario
    AFTER INSERT OR UPDATE
    ON cliente
    FOR EACH ROW
    EXECUTE FUNCTION insertar_pos_usuario();

-- Creamos el trigger de almacen
CREATE OR REPLACE FUNCTION insertar_pos_almacen() RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
INSERT INTO pos_almacen (id_almacen, latitud, longitud, geom)
VALUES (
           NEW.id_almacen,
           CAST(NEW.latitud AS DOUBLE PRECISION),
           CAST(NEW.longitud AS DOUBLE PRECISION),
           ST_SetSRID(ST_MakePoint(CAST(NEW.longitud AS DOUBLE PRECISION), CAST(NEW.latitud AS DOUBLE PRECISION)), 4326)
       )
    ON CONFLICT (id_almacen) DO UPDATE
                                    SET
                                        latitud = EXCLUDED.latitud,
                                    longitud = EXCLUDED.longitud,
                                    geom = EXCLUDED.geom;

RETURN NEW;
END;
$$;

-- Para que se active
CREATE TRIGGER trg_insertar_pos_almacen
    AFTER INSERT OR UPDATE ON almacen
                        FOR EACH ROW
                        EXECUTE FUNCTION insertar_pos_almacen();


-- REQUERIMIENTO 14
CREATE OR REPLACE FUNCTION obtener_ordenes_cercanas(id_almacen_input INTEGER, radio_km DOUBLE PRECISION DEFAULT 10.0)
RETURNS TABLE (
    id_orden INTEGER,
    fecha_orden TIMESTAMP,
    estado VARCHAR,
    id_cliente INTEGER,
    id_almacen INTEGER,
    total NUMERIC
) AS
$$
DECLARE
geom_almacen GEOGRAPHY;
BEGIN
    -- Obtener la geometría del almacén específico
SELECT pa.geom::GEOGRAPHY INTO geom_almacen
FROM almacen a
         JOIN pos_almacen pa ON a.id_almacen = pa.id_almacen
WHERE a.id_almacen = id_almacen_input;

-- Verificar si se encontró el almacén
IF geom_almacen IS NULL THEN
        RAISE EXCEPTION 'Almacén no encontrado con el ID: %', id_almacen_input;
END IF;

   -- Devolver las órdenes cercanas al almacén
RETURN QUERY
SELECT
    o.id_orden,
    o.fecha_orden,
    o.estado,
    o.id_cliente,  -- Asegúrate de que estás usando el ID correcto aquí
    o.id_almacen,
    o.total
FROM
    orden o
        JOIN cliente c ON o.id_cliente = c.id_cliente  -- Asegúrate de que estás usando el ID correcto aquí
        JOIN pos_usuario pu ON c.id_cliente::VARCHAR = pu.id_cliente  -- Asegúrate de que los tipos coincidan
WHERE
    ST_DWithin(geom_almacen, pu.geom::GEOGRAPHY, radio_km * 1000); -- Asegurar que la unidad es metros

END;
$$
LANGUAGE plpgsql;







-- REQUERIMIENTO 15
CREATE OR REPLACE FUNCTION obtener_almacen_mas_cercano(id_cliente_input INTEGER)
RETURNS TABLE (
    id_almacen INTEGER,
    nombre VARCHAR,
    posicion TEXT,
    latitud DOUBLE PRECISION,
    longitud DOUBLE PRECISION
) AS
$$
DECLARE
geom_cliente GEOGRAPHY;
BEGIN
    -- Obtener la geometría del cliente específico
SELECT pu.geom::GEOGRAPHY INTO geom_cliente
FROM cliente c
         JOIN pos_usuario pu ON c.id_cliente::VARCHAR = pu.id_cliente
WHERE c.id_cliente = id_cliente_input;

-- Verificar si se encontró el cliente
IF geom_cliente IS NULL THEN
        RAISE EXCEPTION 'Cliente no encontrado con el ID: %', id_cliente_input;
END IF;

    -- Devolver el almacén más cercano al cliente
RETURN QUERY
SELECT
    a.id_almacen,
    a.nombre,
    a.posicion,
    pa.latitud,
    pa.longitud
FROM
    almacen a
        JOIN
    pos_almacen pa ON a.id_almacen = pa.id_almacen
ORDER BY
    ST_Distance(geom_cliente, pa.geom::GEOGRAPHY) -- Ordenar por distancia ascendente
    LIMIT 1;
END;
$$
LANGUAGE plpgsql;




-- REQUERIMIENTO 21
CREATE OR REPLACE FUNCTION obtener_distancia_cliente_almacen(id_cliente_input INTEGER, id_almacen_input INTEGER)
RETURNS DOUBLE PRECISION AS
$$
DECLARE
geom_cliente GEOGRAPHY;
    geom_almacen GEOGRAPHY;
BEGIN
    -- Obtener la geometría del cliente
SELECT pu.geom::GEOGRAPHY INTO geom_cliente
FROM cliente c  -- Cambiar a la tabla cliente
         JOIN pos_usuario pu ON c.id_cliente::VARCHAR = pu.id_cliente  -- Asegúrate de usar el id_cliente aquí
WHERE c.id_cliente = id_cliente_input;

-- Verificar si se encontró el cliente
IF geom_cliente IS NULL THEN
        RAISE EXCEPTION 'Cliente no encontrado con el ID: %', id_cliente_input;
END IF;

    -- Obtener la geometría del almacén
SELECT pa.geom::GEOGRAPHY INTO geom_almacen
FROM almacen a
         JOIN pos_almacen pa ON a.id_almacen = pa.id_almacen
WHERE a.id_almacen = id_almacen_input;

-- Verificar si se encontró el almacén
IF geom_almacen IS NULL THEN
        RAISE EXCEPTION 'Almacén no encontrado con el ID: %', id_almacen_input;
END IF;

    -- Calcular la distancia en kilómetros
RETURN ST_Distance(geom_cliente, geom_almacen) / 1000; -- Devuelve la distancia en km
END;
$$
LANGUAGE plpgsql;
