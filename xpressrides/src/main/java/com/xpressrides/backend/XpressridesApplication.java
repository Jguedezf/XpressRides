package com.xpressrides.backend;

import org.springframework.boot.CommandLineRunner;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.context.annotation.Bean;
import org.springframework.jdbc.core.JdbcTemplate;

@SpringBootApplication
public class XpressridesApplication {

	public static void main(String[] args) {
		SpringApplication.run(XpressridesApplication.class, args);
	}

	@Bean
	public CommandLineRunner dbMigration(org.springframework.beans.factory.ObjectProvider<JdbcTemplate> jdbcTemplateProvider) {
		return args -> {
			JdbcTemplate jdbcTemplate = jdbcTemplateProvider.getIfAvailable();
			if (jdbcTemplate == null) {
				return;
			}
			try {
				// Actualizamos el ENUM de notificaciones para incluir 'emergencia' en la BD existente.
				jdbcTemplate.execute("ALTER TABLE notificacion MODIFY COLUMN tipo ENUM('viaje_solicitado','chofer_asignado','chofer_en_camino','viaje_iniciado','viaje_completado','factura_emitida','pago_recibido','recarga_acreditada','viaje_cancelado','emergencia') NOT NULL");
			} catch (Exception e) {
				System.err.println("Nota: No se pudo alterar la tabla notificacion (puede que ya esté actualizada): " + e.getMessage());
			}
		};
	}
}
