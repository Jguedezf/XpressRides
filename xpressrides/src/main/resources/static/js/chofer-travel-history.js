// js/chofer-travel-history.js

document.addEventListener('DOMContentLoaded', async () => {
    if (!requireAuth()) return;
    await cargarHistorial();
});

document.getElementById('form-filtro-historial').addEventListener('submit', async (e) => {
    e.preventDefault();
    await cargarHistorial();
});

document.getElementById('btn-limpiar-filtro').addEventListener('click', async () => {
    document.getElementById('filtroDesde').value = '';
    document.getElementById('filtroHasta').value = '';
    document.getElementById('filtroSoloCancelados').checked = false;
    await cargarHistorial();
});

async function cargarHistorial() {
    const container = document.getElementById('trips-container');
    if (!container) return;

    const desde = document.getElementById('filtroDesde').value;
    const hasta = document.getElementById('filtroHasta').value;
    const soloCancelados = document.getElementById('filtroSoloCancelados').checked;

    container.innerHTML = '<p class="text-center text-muted mt-lg">Cargando historial...</p>';

    try {
        const endpoint = soloCancelados ? '/chofer/traslados/cancelados' : '/chofer/traslados';
        const params = new URLSearchParams();
        if (desde) params.set('desde', desde);
        if (hasta) params.set('hasta', hasta);
        const query = params.toString() ? `?${params.toString()}` : '';

        const response = await fetchAPI(`${endpoint}${query}`);
        const viajes = response.data || response;

        if (!viajes || viajes.length === 0) {
            container.innerHTML = '<p class="text-center text-muted mt-lg">No hay viajes que coincidan con este filtro.</p>';
            return;
        }

        renderTrips(container, viajes);

    } catch (err) {
        container.innerHTML = `<p class="text-center text-error mt-lg">Error al cargar historial: ${err.message}</p>`;
    }
}

function renderTrips(container, viajes) {
    container.innerHTML = '';

    viajes.forEach(viaje => {
        let timeStr = viaje.requestDate || viaje.startDate || '';
        if (timeStr) {
            const d = new Date(timeStr);
            timeStr = d.toLocaleDateString() + ' ' + d.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
        }

        const isCanceled = viaje.status === 'cancelado';
        const isCompleted = viaje.status === 'completado';

        let iconColor = 'var(--color-primary)';
        let bgColor = '#E8F4FD';

        if (isCanceled) {
            iconColor = 'var(--color-error)';
            bgColor = 'var(--color-error-bg)';
        } else if (isCompleted) {
            iconColor = 'var(--color-success)';
            bgColor = 'var(--color-success-bg)';
        }

        // Fallback for amount if not provided by API
        let montoDisplay = '';
        if (viaje.driverAmountUsd) {
            montoDisplay = `$ ${viaje.driverAmountUsd.toFixed(2)}`;
        } else {
            montoDisplay = isCanceled ? 'Cancelado' : (isCompleted ? 'Completado' : viaje.status);
        }

        const destinoStr = (viaje.destinationZone && viaje.destinationZone.name) ? viaje.destinationZone.name : 'Destino desconocido';

        const html = `
            <div class="trip-card">
                <div class="trip-icon" style="background-color: ${bgColor}; color: ${iconColor};">
                    <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M19 17h2c.6 0 1-.4 1-1v-3c0-.9-.7-1.7-1.5-1.9C18.7 10.6 16 10 16 10s-1.3-1.4-2.2-2.3c-.5-.4-1.1-.7-1.8-.7H5c-.6 0-1.1.4-1.4.9l-1.4 2.9A3.7 3.7 0 0 0 2 12v4c0 .6.4 1 1 1h2"></path><circle cx="7" cy="17" r="2"></circle><path d="M9 17h6"></path><circle cx="17" cy="17" r="2"></circle></svg>
                </div>
                <div class="trip-details">
                    <div class="trip-location">Viaje a ${destinoStr}</div>
                    <div class="trip-time">${timeStr}</div>
                    ${isCanceled && viaje.cancellationReason ? `<div class="trip-time" style="color: var(--color-error);">Motivo: ${viaje.cancellationReason}</div>` : ''}
                </div>
                <div class="trip-amount">
                    <div class="trip-usd" style="color: ${iconColor}; font-size: 14px; font-weight: bold;">${montoDisplay}</div>
                    ${viaje.starRating != null ? `
                        <button class="btn-secondary" style="padding: 4px 8px; font-size: 11px; margin-top: 4px; background-color:#FFD700; color:#000; border:none;" onclick="window.location.href='/views/chofer-resenas.html?tripId=${viaje.id}'">
                            Ver Reseña
                        </button>
                    ` : ''}
                </div>
            </div>
        `;
        container.insertAdjacentHTML('beforeend', html);
    });
}
