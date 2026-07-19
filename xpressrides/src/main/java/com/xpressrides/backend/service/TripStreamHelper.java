package com.xpressrides.backend.service;

import org.springframework.web.servlet.mvc.method.annotation.SseEmitter;

import java.io.IOException;
import java.util.Map;
import java.util.Objects;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.function.Supplier;

// Utilidad compartida para exponer el seguimiento de un viaje activo (cliente o
// chofer) como Server-Sent Events en vez de que el frontend haga polling HTTP
// repetido. No usa WebSocket ni ninguna dependencia nueva — SseEmitter ya viene
// con spring-boot-starter-web. La "novedad en tiempo real" es que el servidor
// empuja el estado sobre una única conexión persistente en vez de que el
// navegador abra una petición HTTP nueva cada pocos segundos.
final class TripStreamHelper {

    private static final long TIMEOUT_MS = 10 * 60 * 1000L; // 10 minutos — igual que un viaje largo
    private static final long POLL_INTERVAL_MS = 3000L;

    private TripStreamHelper() {}

    static SseEmitter stream(Supplier<Map<String, Object>> activeTripSupplier) {
        SseEmitter emitter = new SseEmitter(TIMEOUT_MS);
        ExecutorService executor = Executors.newSingleThreadExecutor();

        executor.execute(() -> {
            Object ultimoEnviado = new Object(); // distinto de cualquier valor real para forzar el primer envío
            try {
                while (true) {
                    Map<String, Object> data = activeTripSupplier.get();
                    if (!Objects.equals(data, ultimoEnviado)) {
                        emitter.send(SseEmitter.event().name("viaje").data(data));
                        ultimoEnviado = data;
                    }
                    if (data == null) {
                        emitter.complete();
                        break;
                    }
                    Thread.sleep(POLL_INTERVAL_MS);
                }
            } catch (IOException e) {
                // El cliente cerró la conexión (cambió de pantalla, cerró la pestaña) — normal, no es un error.
                emitter.complete();
            } catch (Exception e) {
                emitter.completeWithError(e);
            }
        });

        emitter.onCompletion(executor::shutdown);
        emitter.onTimeout(() -> { emitter.complete(); executor.shutdown(); });
        emitter.onError((ex) -> executor.shutdown());

        return emitter;
    }
}
