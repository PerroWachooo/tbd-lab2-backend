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


---------------------------------- #################################
-- COSAS DEL LABORATORIO 2


-- Creamos un trigger que almacene la posicion del usuario segun su geometría
-- longitud y latitud.
CREATE OR REPLACE FUNCTION insertar_pos_usuario() RETURNS TRIGGER
LANGUAGE plpgsql
AS
$$
BEGIN
INSERT INTO pos_usuario (id_usuario, latitud, longitud, geom)
VALUES (
           NEW.id_usuario,
           CAST(NEW.latitud AS DOUBLE PRECISION),
           CAST(NEW.longitud AS DOUBLE PRECISION),
           ST_SetSRID(ST_MakePoint(CAST(NEW.longitud AS DOUBLE PRECISION), CAST(NEW.latitud AS DOUBLE PRECISION)), 4326)
       )
    ON CONFLICT (id_usuario) DO UPDATE
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
    ON usuarios
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

RETURN QUERY
SELECT
    o.id_orden,
    o.fecha_orden,
    o.estado,
    o.id_cliente,
    o.id_almacen,
    o.total
FROM
    orden o
        JOIN usuario c ON o.id_cliente = c.id_usuario
        JOIN pos_usuario pc ON c.id_usuario = pc.id_usuario::INTEGER
WHERE
    ST_DWithin(geom_almacen, pc.geom::GEOGRAPHY, radio_km * 1000); -- Asegurar que la unidad es metros
END;
$$

LANGUAGE plpgsql;