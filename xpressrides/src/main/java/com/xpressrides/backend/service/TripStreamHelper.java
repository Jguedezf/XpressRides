package com.xpressrides.backend.service;

import org.springframework.web.servlet.mvc.method.annotation.SseEmitter;

import java.io.IOException;
import java.util.Map;
import java.util.Objects;
import java.util.concurrent.Executors;
import java.util.concurrent.ScheduledExecutorService;
import java.util.concurrent.ScheduledFuture;
import java.util.concurrent.TimeUnit;
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

    private static final ScheduledExecutorService SCHEDULER = Executors.newScheduledThreadPool(
            Math.max(2, Runtime.getRuntime().availableProcessors()),
            r -> {
                Thread t = new Thread(r, "sse-trip-stream");
                t.setDaemon(true);
                return t;
            }
    );

    private TripStreamHelper() {}

    static SseEmitter stream(Supplier<Map<String, Object>> activeTripSupplier) {
        SseEmitter emitter = new SseEmitter(TIMEOUT_MS);

        final Object[] ultimoEnviado = new Object[] { new Object() };
        final ScheduledFuture<?>[] futureHolder = new ScheduledFuture<?>[1];

        Runnable task = () -> {
            try {
                Map<String, Object> data = activeTripSupplier.get();
                if (data == null) {
                    if (futureHolder[0] != null) {
                        futureHolder[0].cancel(false);
                    }
                    emitter.complete();
                    return;
                }
                if (!Objects.equals(data, ultimoEnviado[0])) {
                    emitter.send(SseEmitter.event().name("viaje").data(data));
                    ultimoEnviado[0] = data;
                }
            } catch (IOException e) {
                if (futureHolder[0] != null) {
                    futureHolder[0].cancel(false);
                }
                emitter.complete();
            } catch (Exception e) {
                if (futureHolder[0] != null) {
                    futureHolder[0].cancel(false);
                }
                emitter.completeWithError(e);
            }
        };

        ScheduledFuture<?> future = SCHEDULER.scheduleWithFixedDelay(task, 0, POLL_INTERVAL_MS, TimeUnit.MILLISECONDS);
        futureHolder[0] = future;

        Runnable cleanup = () -> {
            if (futureHolder[0] != null) {
                futureHolder[0].cancel(false);
            }
        };

        emitter.onCompletion(cleanup);
        emitter.onTimeout(() -> { emitter.complete(); cleanup.run(); });
        emitter.onError((ex) -> cleanup.run());

        return emitter;
    }
}
