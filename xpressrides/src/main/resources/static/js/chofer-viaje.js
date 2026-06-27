document.addEventListener('DOMContentLoaded', () => {
    inicializarMapaChofer();
    configurarPushNotification();
    configurarBotonesEstado();
    configurarBotonEmergencia();
    setTimeout(simularSolicitudViaje, 3000);
    setTimeout(simularSolicitudViaje, 12000);
    setTimeout(simularSolicitudViaje, 25000);
});

let mapaChofer = null;
let marcadorChofer = null;
let circuloPrecision = null;
let watchId = null;
let timerInterval = null;
let segundosRestantes = 30;
let viajeAceptado = false;
let notifActivaId = null;

const historialNotificaciones = [];

let notifIdCounter = 0;

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

// ─── 2. PUSH NOTIFICATION ───────────────────────────

function configurarPushNotification() {
    document.getElementById('push-btn-aceptar').addEventListener('click', aceptarViaje);
    document.getElementById('push-btn-rechazar').addEventListener('click', rechazarViaje);
}

function simularSolicitudViaje() {
    const origenes = ['Alta Vista', 'Unare', 'Castillito', 'Los Olivos', 'Villa Asia'];
    const destinos = ['Centro', 'San Félix', 'Puerto Ordaz', 'Matanzas', 'Universidad UNEG'];

    const notif = {
        id: ++notifIdCounter,
        origen: origenes[Math.floor(Math.random() * origenes.length)],
        destino: destinos[Math.floor(Math.random() * destinos.length)],
        timestamp: new Date(),
        status: 'pendiente'
    };

    historialNotificaciones.unshift(notif);

    if (!notifActivaId) {
        mostrarPushNotification(notif);
    }

    actualizarBadge();
}

function mostrarPushNotification(notif) {
    notifActivaId = notif.id;

    document.getElementById('push-origen').textContent = notif.origen;
    document.getElementById('push-destino').textContent = notif.destino;
    document.getElementById('push-notification').classList.remove('hidden');
    iniciarTimer();
}

function cerrarPushNotification() {
    clearInterval(timerInterval);
    document.getElementById('push-notification').classList.add('hidden');
    notifActivaId = null;
    // No llamar a mostrarSiguientePendiente()
    // La notif sigue como 'pendiente' disponible desde el panel
}

function iniciarTimer() {
    segundosRestantes = 30;
    const barra = document.getElementById('push-timer-bar');
    const texto = document.getElementById('push-timer-text');
    barra.style.width = '100%';
    barra.classList.remove('expired');
    texto.textContent = '30 segundos restantes';

    clearInterval(timerInterval);
    timerInterval = setInterval(() => {
        segundosRestantes--;
        const porcentaje = (segundosRestantes / 30) * 100;
        barra.style.width = Math.max(porcentaje, 0) + '%';
        texto.textContent = `${segundosRestantes} segundos restantes`;

        if (segundosRestantes <= 0) {
            clearInterval(timerInterval);
            barra.classList.add('expired');
            texto.textContent = '⏰ Tiempo agotado';

            const notif = historialNotificaciones.find(n => n.id === notifActivaId);
            if (notif && notif.status === 'pendiente') {
                notif.status = 'expirado';
            }
            notifActivaId = null;
            actualizarBadge();

            setTimeout(() => {
                document.getElementById('push-notification').classList.add('hidden');
                mostrarSiguientePendiente();
            }, 2000);
        }
    }, 1000);
}

function aceptarViaje() {
    clearInterval(timerInterval);
    viajeAceptado = true;

    const notif = historialNotificaciones.find(n => n.id === notifActivaId);
    if (notif) notif.status = 'aceptado';

    document.getElementById('push-notification').classList.add('hidden');
    notifActivaId = null;
    actualizarBadge();

    document.getElementById('state-buttons').classList.remove('hidden');
    document.getElementById('btn-en-camino').classList.remove('hidden');
    document.getElementById('btn-llegue').classList.add('hidden');
    document.getElementById('btn-completado').classList.add('hidden');

    mostrarMensaje('Viaje aceptado. Dirígete al origen.');

    const panel = document.getElementById('panel-notificaciones-viaje');
    if (panel) { panel.remove(); window.abrirNotificaciones(); }
}

function rechazarViaje() {
    clearInterval(timerInterval);

    const notif = historialNotificaciones.find(n => n.id === notifActivaId);
    if (notif) notif.status = 'rechazado';

    document.getElementById('push-notification').classList.add('hidden');
    notifActivaId = null;
    actualizarBadge();

    mostrarSiguientePendiente();

    const panel = document.getElementById('panel-notificaciones-viaje');
    if (panel) { panel.remove(); window.abrirNotificaciones(); }
}

function mostrarSiguientePendiente() {
    const pendiente = historialNotificaciones.find(n => n.status === 'pendiente');
    if (pendiente) {
        mostrarPushNotification(pendiente);
    }
}

function actualizarBadge() {
    const badge = document.getElementById('badge-count');
    if (!badge) return;
    const pendientes = historialNotificaciones.filter(n => n.status === 'pendiente').length;
    if (pendientes > 0) {
        badge.textContent = pendientes > 99 ? '99+' : pendientes;
        badge.style.display = 'flex';
    } else {
        badge.style.display = 'none';
    }
}

// ─── 3. PANEL DE NOTIFICACIONES ─────────────────────

window.abrirNotificaciones = function () {
    const existente = document.getElementById('panel-notificaciones-viaje');
    if (existente) { existente.remove(); return; }

    let listaHTML = '';
    if (historialNotificaciones.length === 0) {
        listaHTML = '<div style="padding:20px;text-align:center;color:#999;font-size:14px;">No hay notificaciones de viaje</div>';
    } else {
        historialNotificaciones.forEach(n => {
            const fecha = new Date(n.timestamp);
            const hora = fecha.toLocaleTimeString('es-VE', { hour: '2-digit', minute: '2-digit' });
            const statusLabels = {
                pendiente: 'Pendiente',
                aceptado: 'Aceptado',
                rechazado: 'Rechazado',
                expirado: 'Expirado'
            };

            let iconoColor;
            switch (n.status) {
                case 'pendiente': iconoColor = 'var(--color-primary)'; break;
                case 'aceptado': iconoColor = 'var(--color-success)'; break;
                default: iconoColor = 'var(--color-error)';
            }

            const statusBadge = `<span class="notif-status ${n.status}">${statusLabels[n.status] || n.status}</span>`;

            const actionButtons = n.status === 'pendiente' ? `
                <div class="notif-actions">
                    <button class="btn-sm-aceptar" onclick="aceptarDesdePanel(${n.id})">✓ Aceptar</button>
                    <button class="btn-sm-rechazar" onclick="rechazarDesdePanel(${n.id})">✕ Rechazar</button>
                </div>
            ` : '';

            listaHTML += `
                <div class="notif-item ${n.status}">
                    <span style="font-size:18px;flex-shrink:0;line-height:1.4;">
                        <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="${iconoColor}" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                            <path d="M19 17h2c.6 0 1-.4 1-1v-3c0-.9-.7-1.7-1.5-1.9C18.7 10.6 16 10 16 10s-1.3-1.4-2.2-2.3c-.5-.4-1.1-.7-1.8-.7H5c-.6 0-1.1.4-1.4.9l-1.4 2.9A3.7 3.7 0 0 0 2 12v4c0 .6.4 1 1 1h2"></path>
                            <circle cx="7" cy="17" r="2"></circle><path d="M9 17h6"></path><circle cx="17" cy="17" r="2"></circle>
                        </svg>
                    </span>
                    <div style="flex:1;min-width:0;padding-right:24px;">
                        <p style="margin:0 0 2px 0;font-size:14px;color:#333;font-weight:500;">
                            Viaje a ${n.destino}
                        </p>
                        <p style="margin:0 0 4px 0;font-size:12px;color:#999;">
                            Origen: ${n.origen} · ${hora}
                        </p>
                        ${statusBadge}
                        ${actionButtons}
                    </div>
                    <button class="notif-close" onclick="eliminarNotificacion(${n.id})" title="Eliminar">✕</button>
                </div>
            `;
        });
    }

    const panelHTML = `
        <div id="panel-notificaciones-viaje" style="position:fixed;top:0;right:0;bottom:0;left:0;z-index:9998;background:transparent;" onclick="if(event.target===this)this.remove();">
            <div style="position:absolute;top:56px;right:16px;width:360px;max-width:calc(100vw - 32px);background:#fff;border-radius:12px;box-shadow:0 8px 30px rgba(0,0,0,0.18);overflow:hidden;z-index:9999;animation:slideDown 0.2s ease-out;">
                <div style="padding:14px 16px;background:linear-gradient(135deg,#1F4E79 0%,#C55A11 100%);color:white;font-weight:700;font-size:15px;display:flex;justify-content:space-between;align-items:center;">
                    <span>Notificaciones de Viaje</span>
                    <span style="font-size:12px;opacity:0.9;">${historialNotificaciones.filter(n => n.status === 'pendiente').length} pendiente(s)</span>
                </div>
                <div style="max-height:400px;overflow-y:auto;">
                    ${listaHTML}
                </div>
            </div>
        </div>
    `;
    document.body.insertAdjacentHTML('beforeend', panelHTML);
};

window.eliminarNotificacion = function (id) {
    const idx = historialNotificaciones.findIndex(n => n.id === id);
    if (idx === -1) return;

    if (id === notifActivaId) {
        clearInterval(timerInterval);
        document.getElementById('push-notification').classList.add('hidden');
        notifActivaId = null;
    }

    historialNotificaciones.splice(idx, 1);
    actualizarBadge();

    const panel = document.getElementById('panel-notificaciones-viaje');
    if (panel) {
        panel.remove();
        window.abrirNotificaciones();
    }

    if (id === notifActivaId) {
        mostrarSiguientePendiente();
    }
};

// ─── 4. ACEPTAR / RECHAZAR DESDE PANEL ──────────────

function aceptarDesdePanel(id) {
    const notif = historialNotificaciones.find(n => n.id === id);
    if (!notif || notif.status !== 'pendiente') return;
    notif.status = 'aceptado';
    viajeAceptado = true;

    if (id === notifActivaId) {
        clearInterval(timerInterval);
        document.getElementById('push-notification').classList.add('hidden');
        notifActivaId = null;
    }

    actualizarBadge();

    document.getElementById('state-buttons').classList.remove('hidden');
    document.getElementById('btn-en-camino').classList.remove('hidden');
    document.getElementById('btn-llegue').classList.add('hidden');
    document.getElementById('btn-completado').classList.add('hidden');

    mostrarMensaje('Viaje aceptado. Dirígete al origen.');

    const panel = document.getElementById('panel-notificaciones-viaje');
    if (panel) { panel.remove(); window.abrirNotificaciones(); }
}

function rechazarDesdePanel(id) {
    const notif = historialNotificaciones.find(n => n.id === id);
    if (!notif || notif.status !== 'pendiente') return;
    notif.status = 'rechazado';

    if (id === notifActivaId) {
        clearInterval(timerInterval);
        document.getElementById('push-notification').classList.add('hidden');
        notifActivaId = null;
    }

    actualizarBadge();
    mostrarSiguientePendiente();

    const panel = document.getElementById('panel-notificaciones-viaje');
    if (panel) { panel.remove(); window.abrirNotificaciones(); }
}

// ─── 5. CAMBIO DE ESTADOS ───────────────────────────

function configurarBotonesEstado() {
    document.getElementById('btn-en-camino').addEventListener('click', () => cambiarEstado('en-camino'));
    document.getElementById('btn-llegue').addEventListener('click', () => cambiarEstado('llegue'));
    document.getElementById('btn-completado').addEventListener('click', () => cambiarEstado('completado'));
}

function cambiarEstado(estado) {
    switch (estado) {
        case 'en-camino':
            document.getElementById('btn-en-camino').classList.add('hidden');
            document.getElementById('btn-llegue').classList.remove('hidden');
            mostrarMensaje('Estado: En camino al origen');
            break;
        case 'llegue':
            document.getElementById('btn-llegue').classList.add('hidden');
            document.getElementById('btn-completado').classList.remove('hidden');
            mostrarMensaje('Estado: Llegué al destino');
            break;
        case 'completado':
            document.getElementById('state-buttons').classList.add('hidden');
            mostrarMensaje('✅ Viaje completado exitosamente');
            viajeAceptado = false;
            break;
    }
}

// ─── 6. EMERGENCIA ──────────────────────────────────

function configurarBotonEmergencia() {}

window.mostrarEmergencia = function () {
    const modalHTML = `
        <div id="modal-emergencia" class="modal-overlay" onclick="if(event.target===this)this.remove();">
            <div class="modal-content text-center">
                <h3 class="h2-subtitle" style="color:var(--color-error);">🚨 Emergencia</h3>
                <p class="text-normal mt-md mb-md">Si estás en peligro, contacta a las autoridades:</p>
                <p class="text-highlight" style="font-size:24px;color:var(--color-error);">911</p>
                <p class="text-small mt-sm">Este botón enviará una alerta a soporte de XpressRides.</p>
                <button class="btn-secondary mt-md" onclick="document.getElementById('modal-emergencia').remove();">Cerrar</button>
            </div>
        </div>
    `;
    document.body.insertAdjacentHTML('beforeend', modalHTML);
};

// ─── 7. MENSAJES TEMPORALES ─────────────────────────

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
        animation:slideDown 0.3s ease-out;max-width:90%;
    `;
    div.textContent = texto;
    document.body.appendChild(div);

    setTimeout(() => {
        div.style.transition = 'opacity 0.3s ease';
        div.style.opacity = '0';
        setTimeout(() => div.remove(), 300);
    }, 3000);
}

// ─── 8. LIMPIEZA ────────────────────────────────────

window.addEventListener('beforeunload', () => {
    if (watchId) navigator.geolocation.clearWatch(watchId);
    clearInterval(timerInterval);
});