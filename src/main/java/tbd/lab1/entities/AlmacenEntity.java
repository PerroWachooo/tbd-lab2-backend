package tbd.lab1.entities;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;
@Data
@AllArgsConstructor
@NoArgsConstructor
public class AlmacenEntity {

        private Integer id_almacen;

        private String nombre;

        private String direccion;

        private String email;

        private String telefono;

        private Point location;

}
