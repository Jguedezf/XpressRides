// js/chofer-travel-history.js

let currentPage = 0;
const pageSize = 5;

document.addEventListener('DOMContentLoaded', async () => {
    if (!requireAuth()) return;
    await cargarHistorial();
});

document.getElementById('form-filtro-historial').addEventListener('submit', async (e) => {
    e.preventDefault();
    currentPage = 0; // Reset a primera página al filtrar
    await cargarHistorial();
});

document.getElementById('btn-limpiar-filtro').addEventListener('click', async () => {
    document.getElementById('filtroDesde').value = '';
    document.getElementById('filtroHasta').value = '';
    document.getElementById('filtroEstadoPago').value = '';
    currentPage = 0;
    await cargarHistorial();
});

// Paginación
document.addEventListener('DOMContentLoaded', () => {
    const btnPrev = document.getElementById('btn-prev-page');
    const btnNext = document.getElementById('btn-next-page');

    if (btnPrev) {
        btnPrev.addEventListener('click', () => {
            if (currentPage > 0) {
                currentPage--;
                cargarHistorial();
            }
        });
    }

    if (btnNext) {
        btnNext.addEventListener('click', () => {
            currentPage++;
            cargarHistorial();
        });
    }
});

async function cargarHistorial() {
    const container = document.getElementById('trips-container');
    const paginationControls = document.getElementById('pagination-controls');
    if (!container) return;

    const desde = document.getElementById('filtroDesde').value;
    const hasta = document.getElementById('filtroHasta').value;
    const paymentStatus = document.getElementById('filtroEstadoPago').value;

    container.innerHTML = '<p class="text-center text-muted mt-lg">Cargando historial...</p>';
    paginationControls.style.display = 'none';

    try {
        const params = new URLSearchParams();
        params.set('page', currentPage);
        params.set('size', pageSize);
        if (desde) params.set('desde', desde);
        if (hasta) params.set('hasta', hasta);
        if (paymentStatus) params.set('paymentStatus', paymentStatus);

        const response = await fetchAPI(`/chofer/traslados?${params.toString()}`);
        const pageData = response.data || response;
        const viajes = pageData.content || pageData || [];

        if (!viajes || viajes.length === 0) {
            container.innerHTML = '<p class="text-center text-muted mt-lg">No hay viajes que coincidan con este filtro.</p>';
            return;
        }

        renderTrips(container, viajes, paymentStatus);

        // Configurar paginación
        if (pageData.totalPages !== undefined) {
            paginationControls.style.display = 'flex';
            document.getElementById('page-info').textContent = `Página ${pageData.number + 1} de ${pageData.totalPages || 1}`;
            document.getElementById('btn-prev-page').disabled = pageData.first;
            document.getElementById('btn-next-page').disabled = pageData.last;
        }

    } catch (err) {
        container.innerHTML = `<p class="text-center text-error mt-lg">Error al cargar historial: ${err.message}</p>`;
    }
}

function renderTrips(container, viajes, paymentStatus) {
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

        // Mostrar monto del chofer (70%)
        let montoDisplay = '';
        if (viaje.driverAmountUsd) {
            montoDisplay = `$ ${viaje.driverAmountUsd.toFixed(2)}`;
        } else {
            montoDisplay = isCanceled ? 'Cancelado' : (isCompleted ? 'Completado' : viaje.status);
        }

        // Badge de estado de pago para viajes completados
        let paymentBadge = '';
        if (isCompleted && viaje.pagadoAlChofer != null) {
            if (viaje.pagadoAlChofer) {
                paymentBadge = '<div style="font-size: 11px; font-weight: 600; color: #2E7D32; background: #E8F5E9; padding: 2px 8px; border-radius: 4px; margin-top: 4px; display: inline-block;">Pagado</div>';
            } else {
                paymentBadge = '<div style="font-size: 11px; font-weight: 600; color: #E65100; background: #FFF3E0; padding: 2px 8px; border-radius: 4px; margin-top: 4px; display: inline-block;">Pendiente</div>';
            }
        }

        const originName = viaje.originZone ? (viaje.originZone.name || viaje.originZone.nombre) : (viaje.originAddress || 'Zona Origen');
        const destName = viaje.destinationZone ? (viaje.destinationZone.name || viaje.destinationZone.nombre) : (viaje.destinationAddress || 'Destino desconocido');

        const html = `
            <div class="trip-card">
                <div class="trip-icon" style="background-color: ${bgColor}; color: ${iconColor}; align-self: flex-start; margin-top: 4px;">
                    <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M19 17h2c.6 0 1-.4 1-1v-3c0-.9-.7-1.7-1.5-1.9C18.7 10.6 16 10 16 10s-1.3-1.4-2.2-2.3c-.5-.4-1.1-.7-1.8-.7H5c-.6 0-1.1.4-1.4.9l-1.4 2.9A3.7 3.7 0 0 0 2 12v4c0 .6.4 1 1 1h2"></path><circle cx="7" cy="17" r="2"></circle><path d="M9 17h6"></path><circle cx="17" cy="17" r="2"></circle></svg>
                </div>
                <div class="trip-details" style="flex: 1;">
                    <div class="trip-route" style="margin-bottom: 6px;">
                        <div style="font-size: 14px; font-weight: 500; color: var(--color-text-main);">
                            <span style="color: #FF5722;">●</span> ${originName}
                        </div>
                        <div style="border-left: 2px dashed #CCC; height: 10px; margin-left: 5px; margin-top: 3px; margin-bottom: 3px;"></div>
                        <div style="font-size: 14px; font-weight: 500; color: var(--color-text-main);">
                            <span style="color: #2196F3;">📍</span> ${destName}
                        </div>
                    </div>
                    <div class="trip-time">${timeStr}</div>
                    ${isCanceled && viaje.cancellationReason ? `<div class="trip-time" style="color: var(--color-error); margin-top: 4px;">Motivo: ${viaje.cancellationReason}</div>` : ''}
                </div>
                <div class="trip-amount">
                    <div class="trip-usd" style="color: ${iconColor}; font-size: 14px; font-weight: bold;">${montoDisplay}</div>
                    ${paymentBadge}
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
