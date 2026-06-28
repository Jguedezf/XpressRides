// js/chofer-viaje.js — Integración real con el backend XpressRides

document.addEventListener('DOMContentLoaded', () => {
    if (!requireAuth()) return;
    inicializarMapaChofer();
    configurarBotonesEstado();
    configurarBotonEmergencia();
    cargarViajeActivo();
    // Polling cada 8 segundos para detectar nuevos viajes asignados por el SP
    setInterval(cargarViajeActivo, 8000);
});

let mapaChofer = null;
let marcadorChofer = null;
let circuloPrecision = null;
let watchId = null;
let viajeActual = null;

// ─── 1. MAPA ────────────────────────────────────────

function inicializarMapaChofer() {
    mapaChofer = L.map('map').setView([8.3535, -62.6328], 14);

    L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
        attribution: '© OpenStreetMap contributors',
        maxZoom: 19
    }).addTo(mapaChofer);

    if (!navigator.geolocation) return;

    const iconoChofer = L.divIcon({
        html: `<div style="width:20px;height:20px;background-color:#1F4E79;border:3px solid white;border-radius:50%;box-shadow:0 0 0 4px rgba(31,78,121,0.3),0 2px 6px rgba(0,0,0,0.3);"></div>`,
        iconSize: [20, 20],
        iconAnchor: [10, 10],
        className: ''
    });

    watchId = navigator.geolocation.watchPosition(
        (pos) => {
            const { latitude, longitude, accuracy } = pos.coords;
            if (marcadorChofer) {
                marcadorChofer.setLatLng([latitude, longitude]);
            } else {
                marcadorChofer = L.marker([latitude, longitude], { icon: iconoChofer })
                    .addTo(mapaChofer)
                    .bindPopup('Tu ubicación');
            }
            if (circuloPrecision) {
                circuloPrecision.setLatLng([latitude, longitude]);
                circuloPrecision.setRadius(accuracy);
            } else {
                circuloPrecision = L.circle([latitude, longitude], {
                    radius: accuracy,
                    color: '#1F4E79',
                    fillColor: '#1F4E79',
                    fillOpacity: 0.1,
                    weight: 1
                }).addTo(mapaChofer);
            }
            mapaChofer.setView([latitude, longitude], mapaChofer.getZoom());
        },
        (err) => console.warn('Error de geolocalización:', err.message),
        { enableHighAccuracy: true, maximumAge: 5000, timeout: 10000 }
    );
}

// ─── 2. CARGAR VIAJE ACTIVO ─────────────────────────

async function cargarViajeActivo() {
    try {
        const response = await fetchAPI('/chofer/viaje-activo');
        const viaje = response.data;

        if (!viaje) {
            ocultarPaneles();
            return;
        }

        // Solo actualizar UI si el estado cambió para no parpadear
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
}

function renderizarEstado(viaje) {
    const { estado, origen, destino, tiempoEstimadoLlegadaMinutos, duracionEstimadaMinutos } = viaje;

    // Poblar datos del viaje en la notificación
    document.getElementById('push-origen').textContent = origen;
    document.getElementById('push-destino').textContent = destino;
    document.getElementById('push-timer-text').textContent = '';

    // Ocultar todo primero
    document.getElementById('push-notification').classList.add('hidden');
    document.getElementById('state-buttons').classList.add('hidden');
    document.getElementById('btn-en-camino').classList.add('hidden');
    document.getElementById('btn-llegue').classList.add('hidden');
    document.getElementById('btn-completado').classList.add('hidden');

    const btnCancelar = document.getElementById('btn-cancelar');
    if (btnCancelar) btnCancelar.classList.add('hidden');

    switch (estado) {
        case 'solicitado':
            document.getElementById('push-notification').classList.remove('hidden');
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

// ─── 3. BOTONES DE ESTADO ───────────────────────────

function configurarBotonesEstado() {
    document.getElementById('push-btn-aceptar').addEventListener('click', () => cambiarEstado('aceptado'));
    document.getElementById('push-btn-rechazar').addEventListener('click', rechazarViaje);
    document.getElementById('btn-en-camino').addEventListener('click', () => cambiarEstado('en_camino'));
    document.getElementById('btn-completado').addEventListener('click', () => cambiarEstado('completado'));

    // btn-llegue sirve para chofer_llego y en_progreso según el estado actual
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

// ─── 6. LIMPIEZA ────────────────────────────────────

window.addEventListener('beforeunload', () => {
    if (watchId) navigator.geolocation.clearWatch(watchId);
});
