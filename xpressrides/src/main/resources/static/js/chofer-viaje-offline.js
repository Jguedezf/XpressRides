// js/chofer-viaje-offline.js — Integración real con el backend XpressRides (Leaflet Offline)

document.addEventListener('DOMContentLoaded', async () => {
    if (!requireAuth()) return;
    configurarBotonesEstado();
    configurarBotonEmergencia();
    configurarModoUbicacion();
    cargarViajeActivo();
    setInterval(cargarViajeActivo, 8000);
    await inicializarMapaChofer();
});

let mapaChofer = null;
let marcadorChofer = null;
let ultimaPosicion = null;
let viajeActual = null;
let countdownInterval = null;
let watchId = null;
let daemonIntervalId = null;
let modoUbicacion = 'manual'; // 'manual' | 'automatico'
let primerFixAutomatico = false;
const RESPONSE_TIMEOUT_SECONDS = 30; // debe coincidir con TripTimeoutScheduler (backend)

// ─── 1. MAPA (LEAFLET) ────────────────────────────────

// Intento único (no watchPosition) de obtener la posición real antes de
// centrar el mapa por primera vez. Si falla o tarda más de 6s, seguimos
// con el fallback de siempre en vez de bloquear el render del mapa.
function obtenerPosicionInicial() {
    return new Promise((resolve) => {
        if (!navigator.geolocation) {
            resolve(null);
            return;
        }
        navigator.geolocation.getCurrentPosition(
            (pos) => resolve({ lat: pos.coords.latitude, lng: pos.coords.longitude }),
            () => resolve(null),
            { enableHighAccuracy: true, timeout: 6000, maximumAge: 0 }
        );
    });
}

async function inicializarMapaChofer() {
    const overlay = document.getElementById('ubicando-overlay');

    if (!ultimaPosicion) {
        ultimaPosicion = await obtenerPosicionInicial();
    }
    if (overlay) overlay.style.display = 'none';

    const centroGuayana = ultimaPosicion || { lat: 8.29, lng: -62.71 };

    mapaChofer = L.map('map').setView([centroGuayana.lat, centroGuayana.lng], 14);

    L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
        attribution: '&copy; OpenStreetMap contributors'
    }).addTo(mapaChofer);

    mapaChofer.on('click', (e) => {
        const clickedLat = e.latlng.lat;
        const clickedLng = e.latlng.lng;
        
        // No usaremos reverse geocoding aquí porque es offline/leaflet, solo colocaremos las coordenadas.
        const direccion = `${clickedLat.toFixed(5)}, ${clickedLng.toFixed(5)}`;

        const popup = L.popup()
            .setLatLng(e.latlng)
            .setContent(`
                <div style="padding: 4px; color: #333; font-family: 'Inter', sans-serif;">
                    <h4 style="margin: 0 0 4px 0; color: #1F4E79; font-size: 14px;">Ubicación seleccionada</h4>
                    <p style="margin: 0 0 8px 0; font-size: 12px;">${direccion}</p>
                    <button id="btn-fijar-offline" style="
                        background: #1F4E79; color: white; border: none; border-radius: 6px;
                        padding: 6px 12px; font-size: 12px; font-weight: 600; cursor: pointer;
                        width: 100%; font-family: 'Inter', sans-serif;
                    ">📍 Fijar como mi ubicación</button>
                </div>
            `)
            .openOn(mapaChofer);

        // Añadir evento al botón que acabamos de inyectar
        setTimeout(() => {
            const btn = document.getElementById('btn-fijar-offline');
            if (btn) {
                btn.addEventListener('click', () => {
                    ultimaPosicion = { lat: clickedLat, lng: clickedLng };
                    
                    if (marcadorChofer) {
                        marcadorChofer.setLatLng([clickedLat, clickedLng]);
                    } else {
                        marcadorChofer = L.marker([clickedLat, clickedLng]).addTo(mapaChofer);
                    }
                    
                    mapaChofer.setView([clickedLat, clickedLng], 15);
                    reportarUbicacion();
                    mapaChofer.closePopup();
                });
            }
        }, 100);
    });

    if (ultimaPosicion) {
        marcadorChofer = L.marker([ultimaPosicion.lat, ultimaPosicion.lng]).addTo(mapaChofer);
    }
}

async function reportarUbicacion() {
    if (!ultimaPosicion) return;
    try {
        await fetchAPI('/chofer/ubicacion', {
            method: 'PUT',
            body: JSON.stringify({ lat: ultimaPosicion.lat, lng: ultimaPosicion.lng })
        });
    } catch (e) {
        console.warn('Error reportando ubicación al backend:', e);
    }
}

function configurarModoUbicacion() {
    const toggle = document.getElementById('ubicacion-mode-toggle');
    const label = document.getElementById('ubicacion-mode-label');
    if (!toggle) return;

    toggle.addEventListener('change', () => {
        detenerTrackingAutomatico();
        if (toggle.checked) {
            modoUbicacion = 'automatico';
            if (label) label.textContent = 'GPS automático';
            iniciarTrackingAutomatico();
        } else {
            modoUbicacion = 'manual';
            if (label) label.textContent = 'Manual';
        }
    });
}

// Mismo patrón base que controlarTrackingUbicacion() en chofer-dashboard-offline.js:
// watchPosition solo guarda la posición y NO recentra el mapa en cada callback
// (evita el bug de recentrado que colapsaba el render — ver commit 9386be4).
// Única excepción: la primera vez que el modo automático obtiene un fix, se
// recentra una sola vez (primerFixAutomatico), para que el usuario vea que
// el mapa sí reconoció su posición real al encender el GPS automático.
// El reporte al backend va aparte, cada 15s, con la última posición conocida.
function iniciarTrackingAutomatico() {
    if (!navigator.geolocation) return;
    primerFixAutomatico = false;
    if (!watchId) {
        watchId = navigator.geolocation.watchPosition(
            (pos) => {
                ultimaPosicion = { lat: pos.coords.latitude, lng: pos.coords.longitude };
                if (!primerFixAutomatico && mapaChofer) {
                    mapaChofer.setView([ultimaPosicion.lat, ultimaPosicion.lng], 15);
                    primerFixAutomatico = true;
                }
            },
            (err) => console.warn('Error de geolocalización:', err.message),
            { enableHighAccuracy: true, maximumAge: 5000, timeout: 10000 }
        );
    }
    if (!daemonIntervalId) {
        reportarUbicacion();
        daemonIntervalId = setInterval(reportarUbicacion, 15000);
    }
}

function detenerTrackingAutomatico() {
    if (watchId) {
        navigator.geolocation.clearWatch(watchId);
        watchId = null;
    }
    if (daemonIntervalId) {
        clearInterval(daemonIntervalId);
        daemonIntervalId = null;
    }
}

window.addEventListener('beforeunload', () => {
    if (watchId) navigator.geolocation.clearWatch(watchId);
    if (daemonIntervalId) clearInterval(daemonIntervalId);
});

// ─── 2. CARGAR VIAJE ACTIVO ─────────────────────────

async function cargarViajeActivo() {
    try {
        const response = await fetchAPI('/chofer/viaje-activo');
        const viaje = response.data;

        if (!viaje) {
            if (viajeActual !== null) {
                ocultarPaneles();
            }
            return;
        }

        if (!viajeActual || viajeActual.estado !== viaje.estado || viajeActual.idTraslado !== viaje.idTraslado) {
            viajeActual = viaje;
            renderizarEstado(viaje);
        }
    } catch (error) {
        console.error('Error cargando viaje activo:', error);
    }
}

function ocultarPaneles() {
    document.getElementById('push-notification').classList.add('hidden');
    document.getElementById('state-buttons').classList.add('hidden');
    viajeActual = null;
    detenerCuentaRegresiva();
}

function renderizarEstado(viaje) {
    const { estado, origen, destino, tiempoEstimadoLlegadaMinutos, duracionEstimadaMinutos } = viaje;

    document.getElementById('push-origen').textContent = origen;
    document.getElementById('push-destino').textContent = destino;

    document.getElementById('push-notification').classList.add('hidden');
    document.getElementById('state-buttons').classList.add('hidden');
    document.getElementById('btn-en-camino').classList.add('hidden');
    document.getElementById('btn-llegue').classList.add('hidden');
    document.getElementById('btn-completado').classList.add('hidden');
    detenerCuentaRegresiva();

    const btnCancelar = document.getElementById('btn-cancelar');
    if (btnCancelar) btnCancelar.classList.add('hidden');

    switch (estado) {
        case 'solicitado':
            document.getElementById('push-notification').classList.remove('hidden');
            iniciarCuentaRegresiva(viaje.fechaAsignacionActual || viaje.fechaSolicitud);
            break;

        case 'aceptado':
            document.getElementById('state-buttons').classList.remove('hidden');
            document.getElementById('btn-en-camino').classList.remove('hidden');
            if (btnCancelar) btnCancelar.classList.remove('hidden');
            mostrarMensaje(`Viaje aceptado — dirígete a ${origen}`);
            break;

        case 'en_camino':
            document.getElementById('state-buttons').classList.remove('hidden');
            const btnLlegue = document.getElementById('btn-llegue');
            btnLlegue.textContent = 'Llegué al origen';
            btnLlegue.dataset.accion = 'chofer_llego';
            btnLlegue.classList.remove('hidden');
            if (btnCancelar) btnCancelar.classList.remove('hidden');
            mostrarMensaje(`En camino al origen${tiempoEstimadoLlegadaMinutos ? ' (~' + tiempoEstimadoLlegadaMinutos + ' min)' : ''}`);
            break;

        case 'chofer_llego':
            document.getElementById('state-buttons').classList.remove('hidden');
            const btnIniciar = document.getElementById('btn-llegue');
            btnIniciar.textContent = 'Iniciar viaje';
            btnIniciar.dataset.accion = 'en_progreso';
            btnIniciar.classList.remove('hidden');
            if (btnCancelar) btnCancelar.classList.remove('hidden');
            mostrarMensaje('Esperando que el cliente aborde');
            break;

        case 'en_progreso':
            document.getElementById('state-buttons').classList.remove('hidden');
            document.getElementById('btn-completado').classList.remove('hidden');
            mostrarMensaje(`En progreso → ${destino}${duracionEstimadaMinutos ? ' (~' + duracionEstimadaMinutos + ' min)' : ''}`);
            break;
    }
}

window.cerrarPushNotification = function () {
    document.getElementById('push-notification').classList.add('hidden');
    detenerCuentaRegresiva();
};

function iniciarCuentaRegresiva(fechaAsignacionIso) {
    detenerCuentaRegresiva();
    if (!fechaAsignacionIso) return;

    const asignadoEnMs = new Date(fechaAsignacionIso).getTime();
    const barEl = document.getElementById('push-timer-bar');
    const textEl = document.getElementById('push-timer-text');

    const actualizar = () => {
        const transcurridoSeg = Math.floor((Date.now() - asignadoEnMs) / 1000);
        const restante = Math.max(0, RESPONSE_TIMEOUT_SECONDS - transcurridoSeg);

        if (textEl) textEl.textContent = `${restante} segundos restantes`;
        if (barEl) {
            barEl.style.width = `${(restante / RESPONSE_TIMEOUT_SECONDS) * 100}%`;
            barEl.classList.toggle('expired', restante <= 0);
        }

        if (restante <= 0) detenerCuentaRegresiva();
    };

    actualizar();
    countdownInterval = setInterval(actualizar, 1000);
}

function detenerCuentaRegresiva() {
    if (countdownInterval) {
        clearInterval(countdownInterval);
        countdownInterval = null;
    }
}

// ─── 3. BOTONES DE ESTADO ───────────────────────────

function configurarBotonesEstado() {
    document.getElementById('push-btn-aceptar').addEventListener('click', () => cambiarEstado('aceptado'));
    document.getElementById('push-btn-rechazar').addEventListener('click', rechazarViaje);
    document.getElementById('btn-en-camino').addEventListener('click', () => cambiarEstado('en_camino'));
    document.getElementById('btn-completado').addEventListener('click', () => cambiarEstado('completado'));

    document.getElementById('btn-llegue').addEventListener('click', () => {
        const accion = document.getElementById('btn-llegue').dataset.accion || 'chofer_llego';
        cambiarEstado(accion);
    });

    const btnCancelar = document.getElementById('btn-cancelar');
    if (btnCancelar) {
        btnCancelar.addEventListener('click', cancelarViajeActivo);
    }
}

async function cambiarEstado(nuevoEstado) {
    if (!viajeActual) return;
    try {
        await fetchAPI(`/chofer/traslados/${viajeActual.idTraslado}/estado`, {
            method: 'PUT',
            body: JSON.stringify({ status: nuevoEstado })
        });
        if (nuevoEstado === 'completado') {
            ocultarPaneles();
            mostrarMensaje('✅ Viaje completado exitosamente');
        } else {
            await cargarViajeActivo();
        }
    } catch (error) {
        mostrarMensaje('Error: ' + error.message);
    }
}

async function rechazarViaje() {
    if (!viajeActual) return;
    try {
        await fetchAPI(`/chofer/traslados/${viajeActual.idTraslado}/rechazar`, { method: 'PUT' });
        document.getElementById('push-notification').classList.add('hidden');
        viajeActual = null;
        detenerCuentaRegresiva();
        mostrarMensaje('Viaje rechazado');
    } catch (error) {
        mostrarMensaje('Error: ' + error.message);
    }
}

async function cancelarViajeActivo() {
    if (!viajeActual) return;
    if (confirm('¿Estás seguro de que deseas cancelar este viaje?')) {
        try {
            await fetchAPI(`/chofer/traslados/${viajeActual.idTraslado}/cancelar`, {
                method: 'PUT',
                body: JSON.stringify({ motivo: 'Cancelado por el chofer' })
            });
            ocultarPaneles();
            mostrarMensaje('Viaje cancelado');
        } catch (error) {
            mostrarMensaje('Error al cancelar: ' + error.message);
        }
    }
}

// ─── 4. EMERGENCIA ──────────────────────────────────

function configurarBotonEmergencia() {}

window.mostrarEmergencia = async function () {
    const modalHTML = `
        <div id="modal-emergencia" class="modal-overlay" onclick="if(event.target===this)this.remove();">
            <div class="modal-content text-center">
                <h3 class="h2-subtitle" style="color:var(--color-error);">🚨 Emergencia</h3>
                <p class="text-normal mt-md mb-md">Si estás en peligro, contacta a las autoridades:</p>
                <p class="text-highlight" style="font-size:24px;color:var(--color-error);">911</p>
                <p class="text-small mt-sm">Se ha enviado una alerta de emergencia a soporte.</p>
                <button class="btn-secondary mt-md" onclick="document.getElementById('modal-emergencia').remove();">Cerrar</button>
            </div>
        </div>
    `;
    document.body.insertAdjacentHTML('beforeend', modalHTML);

    try {
        const payload = viajeActual ? { tripId: viajeActual.idTraslado } : {};
        await fetchAPI('/notificaciones/emergencia', {
            method: 'POST',
            body: JSON.stringify(payload)
        });
    } catch (e) {
        console.error("Error al enviar alerta de emergencia:", e);
    }
};

// ─── 5. MENSAJES TEMPORALES ─────────────────────────

function mostrarMensaje(texto) {
    const previo = document.getElementById('msg-temporal');
    if (previo) previo.remove();

    const div = document.createElement('div');
    div.id = 'msg-temporal';
    div.style.cssText = `
        position:fixed;top:70px;left:50%;transform:translateX(-50%);
        z-index:2000;padding:12px 20px;border-radius:8px;
        background:#E8F4FD;border:1px solid #1F4E79;color:#1F4E79;
        font-size:14px;font-weight:600;box-shadow:0 4px 12px rgba(0,0,0,0.15);
        max-width:90%;
    `;
    div.textContent = texto;
    document.body.appendChild(div);

    setTimeout(() => {
        div.style.transition = 'opacity 0.3s ease';
        div.style.opacity = '0';
        setTimeout(() => div.remove(), 300);
    }, 3000);
}
