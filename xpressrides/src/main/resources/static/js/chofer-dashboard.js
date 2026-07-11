// js/chofer-dashboard.js
// Carga los datos del chofer desde localStorage y maneja el panel

let watchId = null;
let daemonIntervalId = null;
let ultimaPosicion = null;

document.addEventListener('DOMContentLoaded', () => {
    if (!requireAuth()) return;
    cargarDatosChofer();
    configurarToggle();
    configurarBalance();

    // Arrancar tracking GPS si el chofer ya está disponible al cargar la página
    const toggleInput = document.getElementById('availability-toggle');
    const disponible = toggleInput && toggleInput.checked;
    controlarTrackingUbicacion(disponible);
});

function requireAuth() {
    const usuario = localStorage.getItem('xpressUsuario');
    if (!usuario) {
        window.location.href = '../views/login.html';
        return false;
    }
    return true;
}

function cargarDatosChofer() {
    const usuario = JSON.parse(localStorage.getItem('xpressUsuario'));

    const driverName = document.getElementById('driver-name');
    const driverAvatar = document.getElementById('driver-avatar');
    const driverBalance = document.getElementById('driver-balance');
    const statusText = document.getElementById('status-text');
    const toggleInput = document.getElementById('availability-toggle');

    if (driverName) {
        const nombre = usuario.nombre || '';
        const apellido = usuario.apellido || '';
        driverName.innerText = `${nombre} ${apellido}`.trim() || 'Chofer';
    }

    if (driverAvatar) {
        const inicial1 = usuario.nombre ? usuario.nombre.charAt(0) : '';
        const inicial2 = usuario.apellido ? usuario.apellido.charAt(0) : '';
        driverAvatar.innerText = `${inicial1}${inicial2}`.toUpperCase() || 'CH';
    }

    if (driverBalance) {
        const saldo = usuario.saldoUsd != null ? Number(usuario.saldoUsd) : 0;
        driverBalance.innerText = `$${saldo.toFixed(2)}`;
    }

    if (toggleInput && statusText) {
        const disponible = usuario.disponible === true || usuario.disponible === 'true';
        toggleInput.checked = disponible;
        statusText.textContent = disponible ? 'En línea' : 'Inactivo';
        statusText.classList.toggle('offline', !disponible);
    }

    // Calificación
    const driverRating = document.getElementById('driver-rating');
    if (driverRating) {
        const calif = usuario.calificacion !== undefined ? usuario.calificacion : (usuario.rating !== undefined ? usuario.rating : 5.0);
        driverRating.innerText = Number(calif).toFixed(2) + ' ★';
    }

    // Actualizar con datos reales del backend
    actualizarDatosBackendChofer(usuario, driverBalance);
}

async function actualizarDatosBackendChofer(usuario, driverBalance) {
    try {
        const response = await fetchAPI('/chofer/perfil');
        if (response && response.data) {
            const profileData = response.data;
            // Actualizar localstorage con los nuevos datos
            const updatedUser = { ...usuario, ...profileData };
            // Aseguramos mantener la propiedad saldoUsd para no romper otra logica
            if (profileData.saldoAcumuladoUsd !== undefined) {
                updatedUser.saldoUsd = profileData.saldoAcumuladoUsd;
            }
            
            localStorage.setItem('xpressUsuario', JSON.stringify(updatedUser));
            
            if (driverBalance) {
                const saldo = updatedUser.saldoUsd != null ? Number(updatedUser.saldoUsd) : 0;
                driverBalance.innerText = `$${saldo.toFixed(2)}`;
            }

            const driverRating = document.getElementById('driver-rating');
            if (driverRating && profileData.calificacion !== undefined) {
                driverRating.innerText = Number(profileData.calificacion).toFixed(2) + ' ★';
            }

            // Actualizar toggle switch UI
            if (profileData.disponible !== undefined) {
                updatedUser.disponible = profileData.disponible;
                localStorage.setItem('xpressUsuario', JSON.stringify(updatedUser));

                const toggleInput = document.getElementById('availability-toggle');
                const statusText = document.getElementById('status-text');
                if (toggleInput && statusText) {
                    toggleInput.checked = profileData.disponible;
                    statusText.textContent = profileData.disponible ? 'En línea' : 'Inactivo';
                    statusText.classList.toggle('offline', !profileData.disponible);
                }
            }
        }
    } catch (e) {
        console.error("Error actualizando perfil del chofer desde backend:", e);
    }
}

function configurarToggle() {
    const toggleInput = document.getElementById('availability-toggle');
    const statusText = document.getElementById('status-text');

    if (!toggleInput || !statusText) return;

    toggleInput.addEventListener('change', function() {
        const disponible = this.checked;
        statusText.textContent = disponible ? 'En línea' : 'Inactivo';
        statusText.classList.toggle('offline', !disponible);

        // Actualizar en localStorage
        try {
            const usuario = JSON.parse(localStorage.getItem('xpressUsuario'));
            usuario.disponible = disponible;
            localStorage.setItem('xpressUsuario', JSON.stringify(usuario));
        } catch (e) {
            console.warn('Error actualizando localStorage:', e);
        }

        fetchAPI('/chofer/disponibilidad', {
            method: 'PUT',
            body: JSON.stringify({ available: disponible })
        }).catch(err => console.warn('Error actualizando disponibilidad:', err));

        // Iniciar o detener tracking GPS según disponibilidad
// Tracking manual desactivado
    });
}

function configurarBalance() {
    const btnShowBalance = document.getElementById('btn-show-balance');
    const balanceDisplay = document.getElementById('balance-display');

    if (!btnShowBalance || !balanceDisplay) return;

    btnShowBalance.addEventListener('click', function() {
        if (balanceDisplay.classList.contains('hidden')) {
            balanceDisplay.classList.remove('hidden');
            btnShowBalance.textContent = 'Ocultar Saldo';
        } else {
            balanceDisplay.classList.add('hidden');
            btnShowBalance.textContent = 'Ver Saldo Acumulado';
        }
    });
}

// ─────────────────────────────────────────────────────────
// Polling Viaje Pendiente
// ─────────────────────────────────────────────────────────
let pollingTripInterval = null;
let currentPendingTripId = null;
let countdownInterval = null;
const RESPONSE_TIMEOUT_SECONDS = 30; // debe coincidir con TripTimeoutScheduler (backend)

function iniciarPollingViajes() {
    verificarViajePendiente();
    pollingTripInterval = setInterval(verificarViajePendiente, 5000);
}

async function verificarViajePendiente() {
    // Si el chofer está inactivo en UI, podemos saltar
    const toggle = document.getElementById('availability-toggle');
    if (toggle && !toggle.checked) return;

    try {
        const response = await fetchAPI('/chofer/viaje-activo');
        const data = response.data || response;
        if (data && data.estado) {
            if (data.estado === 'solicitado') {
                mostrarAlertaViaje(data);
            } else if (['aceptado', 'en_camino', 'chofer_llego', 'en_progreso'].includes(data.estado)) {
                // Redirigir a la vista del viaje en curso
                window.location.href = '/views/chofer-viaje.html';
            }
        } else {
            ocultarAlertaViaje();
        }
    } catch (err) {
        console.warn("Error al verificar viaje pendiente:", err);
    }
}

function mostrarAlertaViaje(trip) {
    if (currentPendingTripId === trip.idTraslado) return; // Ya está mostrándose
    currentPendingTripId = trip.idTraslado;

    const alertContainer = document.getElementById('trip-alert-container');
    if (!alertContainer) return;

    document.getElementById('alert-trip-origin').textContent = trip.origen;
    document.getElementById('alert-trip-dest').textContent = trip.destino;
    document.getElementById('alert-trip-price').textContent = `$${trip.costoUsd ? trip.costoUsd.toFixed(2) : '0.00'}`;

    alertContainer.style.display = 'flex';
    iniciarCuentaRegresiva(trip.fechaAsignacionActual || trip.fechaSolicitud);
}

function ocultarAlertaViaje() {
    currentPendingTripId = null;
    detenerCuentaRegresiva();
    const alertContainer = document.getElementById('trip-alert-container');
    if (alertContainer) alertContainer.style.display = 'none';
}

// Cuenta regresiva visual de los 30s que tiene el chofer para responder antes de
// que el backend (TripTimeoutScheduler) reasigne el viaje automáticamente.
// No dispara ninguna acción por sí sola: solo refleja el plazo real del servidor,
// que se aplica igual aunque esta pestaña esté cerrada.
function iniciarCuentaRegresiva(fechaAsignacionIso) {
    detenerCuentaRegresiva();
    if (!fechaAsignacionIso) return;

    const asignadoEnMs = new Date(fechaAsignacionIso).getTime();
    const countdownEl = document.getElementById('alert-trip-countdown');
    const barEl = document.getElementById('alert-trip-countdown-bar');

    const actualizar = () => {
        const transcurridoSeg = Math.floor((Date.now() - asignadoEnMs) / 1000);
        const restante = Math.max(0, RESPONSE_TIMEOUT_SECONDS - transcurridoSeg);

        if (countdownEl) countdownEl.textContent = `${restante}s`;
        if (barEl) barEl.style.width = `${(restante / RESPONSE_TIMEOUT_SECONDS) * 100}%`;

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

window.aceptarViajeAlerta = async function() {
    if (!currentPendingTripId) return;
    try {
        await fetchAPI(`/chofer/traslados/${currentPendingTripId}/estado`, { method: 'PUT', body: JSON.stringify({ status: 'aceptado' }) });
        window.location.href = '/views/chofer-viaje.html';
    } catch (err) {
        alert("Error al aceptar viaje: " + err.message);
        ocultarAlertaViaje();
    }
};

window.rechazarViajeAlerta = async function() {
    if (!currentPendingTripId) return;
    try {
        await fetchAPI(`/chofer/traslados/${currentPendingTripId}/rechazar`, { method: 'PUT' });
        ocultarAlertaViaje();
    } catch (err) {
        alert("Error al rechazar viaje: " + err.message);
        ocultarAlertaViaje();
    }
};

// Iniciar polling al cargar
document.addEventListener('DOMContentLoaded', iniciarPollingViajes);
