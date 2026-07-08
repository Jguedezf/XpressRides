package com.xpressrides.backend.repository;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.Optional;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import com.xpressrides.backend.model.Customer;

public interface CustomerRepository extends JpaRepository<Customer, Integer> {
    Optional<Customer> findByUserId_Username(String username);

    Optional<Customer> findByCodigoReferido(String codigoReferido);

    boolean existsByCodigoReferido(String codigoReferido);

    // Asigna quién refirió a este cliente solo si todavía no tiene uno asignado
    // y sigue dentro de la ventana de tiempo permitida (creado_en >= corteMinimo).
    // Es un UPDATE condicionado en vez de un SELECT-y-luego-UPDATE por separado:
    // si dos solicitudes del mismo cliente llegaran casi al mismo tiempo (doble
    // clic, reintento de red), solo una puede afectar la fila — la otra recibe
    // 0 filas y el servicio la traduce en un mensaje de error, no en una
    // segunda asignación silenciosa.
    @Modifying(clearAutomatically = true, flushAutomatically = true)
    @Query("UPDATE Customer c SET c.referidoPor = :referente " +
           "WHERE c.id = :idCliente AND c.referidoPor IS NULL AND c.createdAt >= :corteMinimo")
    int asignarReferidoPor(@Param("idCliente") Integer idCliente,
                           @Param("referente") Customer referente,
                           @Param("corteMinimo") LocalDateTime corteMinimo);

    // Acredita una recarga al saldo del cliente con un UPDATE atómico
    // (saldo_usd = saldo_usd + :monto) en vez de leer-sumar-guardar en Java,
    // para que dos recargas casi simultáneas del mismo cliente no se pisen
    // (mismo patrón que asignarReferidoPor y que TripRejectionService usa
    // para el timeout de 30s). Retorna 0 si el cliente no existe.
    @Modifying(clearAutomatically = true, flushAutomatically = true)
    @Query("UPDATE Customer c SET c.balance = c.balance + :monto WHERE c.id = :idCliente")
    int acreditarSaldo(@Param("idCliente") Integer idCliente, @Param("monto") BigDecimal monto);
}
