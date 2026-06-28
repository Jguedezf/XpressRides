// js/cliente-record.js
// Historial de viajes del cliente con opción de ver factura

document.addEventListener('DOMContentLoaded', async () => {
    await cargarHistorial();
});

let currentPage = parseInt(sessionStorage.getItem('historialPage')) || 0;
const pageSize = 5; // Mostrar 5 por página para probar paginación

async function cargarHistorial() {
    const container = document.getElementById('historial-container');
    const paginationControls = document.getElementById('pagination-controls');

    // 1. Obtener los datos del usuario logueado desde LocalStorage
    const usuarioString = localStorage.getItem('xpressUsuario');
    if (!usuarioString) {
        window.location.href = '../views/login.html';
        return;
    }

    container.innerHTML = '<p class="text-center mt-md" style="color: var(--color-text-muted);">Cargando tu historial de viajes...</p>';
    paginationControls.style.display = 'none';

    try {
        const response = await fetchAPI(`/cliente/traslados?page=${currentPage}&size=${pageSize}`);
        // Puede que devuelva un objeto con content, totalPages, etc.
        const pageData = response.data || response;
        const viajes = pageData.content || pageData || [];

        if (viajes.length === 0) {
            if (currentPage === 0) {
                container.innerHTML = '<p class="text-center mt-md">Aún no tienes viajes registrados. ¡Solicita tu primer XpressRide!</p>';
            } else {
                container.innerHTML = '<p class="text-center mt-md">No hay más viajes registrados.</p>';
            }
            return;
        }

        container.innerHTML = '';

        viajes.forEach(viaje => {
            const estadoActual = viaje.status ? viaje.status.toLowerCase() : '';
            const esCompletado = estadoActual === 'completado';
            const esCancelado = estadoActual === 'cancelado';
            
            let statusClass = 'status-solicitado';
            if (esCompletado) statusClass = 'status-completado';
            else if (esCancelado) statusClass = 'status-cancelado';
            else if (['aceptado', 'en_camino', 'chofer_llego', 'en_progreso'].includes(estadoActual)) {
                statusClass = 'status-en-progreso';
            }

            const vehiculoInfo = viaje.vehicle
                ? [viaje.vehicle.brand || viaje.vehicle.marca, viaje.vehicle.model || viaje.vehicle.modelo, viaje.vehicle.color, viaje.vehicle.plate ? `(${viaje.vehicle.plate})` : ''].filter(Boolean).join(' ')
                : '';

            const fechaObj = new Date(viaje.requestDate);
            const opcionesFecha = { day: '2-digit', month: 'short', year: 'numeric', hour: '2-digit', minute: '2-digit' };
            const fechaFormateada = fechaObj.toLocaleDateString('es-VE', opcionesFecha);

            const originName = viaje.originZone ? (viaje.originZone.name || viaje.originZone.nombre) : 'Zona Origen';
            const destName = viaje.destinationZone ? (viaje.destinationZone.name || viaje.destinationZone.nombre) : 'Zona Destino';
            // El campo en Java es driver.username (tipo User), serializa como driver.username.name / lastName
            const driverUser = viaje.driver ? (viaje.driver.username || viaje.driver.user || {}) : {};
            const driverName = viaje.driver
                ? `${driverUser.name || driverUser.nombre || ''} ${driverUser.lastName || driverUser.apellido || ''}`.trim()
                : (viaje.driverName || '');

            const cardHTML = `
                <div class="trip-card">
                    <div class="trip-header">
                        <span class="trip-date">${fechaFormateada}</span>
                        <span class="trip-status ${statusClass}">${viaje.status}</span>
                    </div>

                    <div class="trip-route">
                        <div class="route-point">
                            <span style="color: var(--color-primary);">●</span> ${originName}
                        </div>
                        <div style="border-left: 2px dashed #CCC; height: 10px; margin-left: 5px;"></div>
                        <div class="route-point">
                            <span style="color: var(--color-secondary);">📍</span> ${destName}
                        </div>
                    </div>

                    ${driverName ? `
                    <div class="d-flex align-center gap-sm mt-sm" style="font-size: 13px; color: var(--color-text-muted);">
                        <img src="https://ui-avatars.com/api/?name=${encodeURIComponent(driverName)}&background=E2EFDA&color=1E6B3C" class="avatar" style="width: 30px; height: 30px; border-radius: 50%;" alt="Chofer">
                        <span>Chofer: ${driverName} ${vehiculoInfo ? '• ' + vehiculoInfo : ''}</span>
                    </div>
                    ` : ''}

                    <div class="trip-footer">
                        <span class="trip-price" ${esCancelado ? 'style="text-decoration: line-through; color: var(--color-text-muted);"' : ''}>
                            $${viaje.customerCostUsd ? Number(viaje.customerCostUsd).toFixed(2) : '0.00'}
                            ${viaje.customerCostVes ? `<span style="font-size:12px; color:var(--color-text-muted); display:block; font-weight:500;">Bs ${Number(viaje.customerCostVes).toFixed(2)}</span>` : ''}
                        </span>
                        
                        <div class="d-flex gap-xs" style="margin-top: 5px; flex-wrap: wrap; justify-content: flex-end;">
                            <button class="btn-secondary" style="padding: 6px 12px; font-size: 12px; width: auto;" onclick='abrirModalDetalles(${JSON.stringify(viaje)})'>
                                Ver Detalles
                            </button>
                            ${esCompletado ? `
                                <button class="btn-secondary" style="padding: 6px 12px; font-size: 12px; width: auto;" onclick="verFactura(${viaje.id})">
                                    Factura
                                </button>
                                ${viaje.starRating == null ? `
                                    <button class="btn-primary" style="padding: 6px 12px; font-size: 12px; width: auto;" onclick="abrirModalCalificacion(${viaje.id}, '${driverName}')">
                                        Calificar
                                    </button>
                                ` : `
                                    <button class="btn-secondary" style="padding: 6px 12px; font-size: 12px; width: auto; background-color:#FFD700; color:#000; border:none;" onclick="window.location.href='/views/cliente-resenas.html?tripId=${viaje.id}'">
                                        Ver Reseña
                                    </button>
                                `}
                            ` : esCancelado ? `
                            ` : `
                            `}
                        </div>
                    </div>
                </div>
            `;
            container.innerHTML += cardHTML;
        });

        // Configurar botones de paginación si se usa Pageable en el backend
        if (pageData.totalPages !== undefined) {
            paginationControls.style.display = 'flex';
            document.getElementById('page-info').textContent = `Página ${pageData.number + 1} de ${pageData.totalPages || 1}`;
            document.getElementById('btn-prev-page').disabled = pageData.first;
            document.getElementById('btn-next-page').disabled = pageData.last;
        }



    } catch (error) {
        console.error("Error cargando historial:", error);
        container.innerHTML = `<div class="alert-error">No pudimos cargar tu historial: ${error.message}</div>`;
    }
}

document.addEventListener('DOMContentLoaded', () => {
    const btnPrev = document.getElementById('btn-prev-page');
    const btnNext = document.getElementById('btn-next-page');

    if (btnPrev) {
        btnPrev.addEventListener('click', () => {
            if (currentPage > 0) {
                currentPage--;
                sessionStorage.setItem('historialPage', currentPage);
                cargarHistorial();
            }
        });
    }

    if (btnNext) {
        btnNext.addEventListener('click', () => {
            currentPage++;
            sessionStorage.setItem('historialPage', currentPage);
            cargarHistorial();
        });
    }
});

// ─────────────────────────────────────────────────────────
// Lógica del Modal de Calificación
// ─────────────────────────────────────────────────────────
let currentRatingTripId = null;
let selectedStars = 0;

window.abrirModalCalificacion = function(tripId, driverName) {
    currentRatingTripId = tripId;
    selectedStars = 0;
    document.getElementById('modal-driver-name').innerText = driverName;
    document.getElementById('rating-comment').value = '';
    
    // Reset stars
    const stars = document.querySelectorAll('#star-container .star');
    stars.forEach(s => s.classList.remove('selected'));
    
    document.getElementById('rating-modal').style.display = 'flex';
};

window.cerrarModalCalificacion = function() {
    document.getElementById('rating-modal').style.display = 'none';
    currentRatingTripId = null;
};

window.enviarCalificacion = async function() {
    if (!currentRatingTripId) return;
    if (selectedStars === 0) {
        alert("Por favor selecciona una calificación de 1 a 5 estrellas.");
        return;
    }
    
    const comment = document.getElementById('rating-comment').value;
    
    try {
        const response = await fetchAPI(`/cliente/traslados/${currentRatingTripId}/calificar`, 'PUT', {
            starRating: selectedStars,
            customerComment: comment
        });
        
        if (response && response.message) {
            alert("¡Gracias por calificar tu viaje!");
            cerrarModalCalificacion();
            cargarHistorial(); // Recargar para actualizar el botón
        }
    } catch (error) {
        alert("Error al enviar calificación: " + error.message);
    }
};

// Event listeners para las estrellas
document.addEventListener('DOMContentLoaded', () => {
    const stars = document.querySelectorAll('#star-container .star');
    stars.forEach(star => {
        // Hover
        star.addEventListener('mouseover', function() {
            const val = parseInt(this.getAttribute('data-value'));
            stars.forEach(s => {
                if (parseInt(s.getAttribute('data-value')) <= val) s.style.color = '#FFD700';
                else s.style.color = '#ccc';
            });
        });
        
        // Mouse out (restore to selected state)
        star.addEventListener('mouseout', function() {
            stars.forEach(s => {
                if (parseInt(s.getAttribute('data-value')) <= selectedStars) s.style.color = '#FFD700';
                else s.style.color = '#ccc';
            });
        });
        
        // Click
        star.addEventListener('click', function() {
            selectedStars = parseInt(this.getAttribute('data-value'));
            stars.forEach(s => {
                if (parseInt(s.getAttribute('data-value')) <= selectedStars) s.classList.add('selected');
                else s.classList.remove('selected');
            });
        });
    });
});


// ─────────────────────────────────────────────────────────
// Modal de factura — se inyecta dinámicamente al DOM
// ─────────────────────────────────────────────────────────

/**
 * Obtiene la factura del traslado desde el backend y la muestra
 * en un modal superpuesto con todos los campos de InvoiceResponseDTO.
 * @param {number} trasladoId - ID del traslado (viaje)
 */
window.verFactura = async function (trasladoId) {
    try {
        // Consultar la factura asociada al traslado
        const response = await fetchAPI(`/facturas/${trasladoId}`);
        const f = response.data;

        if (!f) {
            alert('No se encontró la factura para este viaje.');
            return;
        }

        // Eliminar modal previo si existiera
        const prevModal = document.getElementById('modal-factura');
        if (prevModal) prevModal.remove();

        // Construir el HTML del modal con los campos de InvoiceResponseDTO
        const modalHTML = `
            <div id="modal-factura" style="
                position: fixed; inset: 0; z-index: 9999;
                display: flex; align-items: center; justify-content: center;
                background: rgba(0,0,0,0.5);">
                <div style="
                    background: #fff; border-radius: 12px; padding: 28px 32px;
                    max-width: 480px; width: 90%; box-shadow: 0 8px 30px rgba(0,0,0,0.25);
                    position: relative; font-family: inherit;">

                    <!-- Botón cerrar -->
                    <button onclick="document.getElementById('modal-factura').remove()"
                        style="position:absolute; top:12px; right:16px; background:none;
                               border:none; font-size:22px; cursor:pointer; color:#888;">✕</button>

                    <h3 style="margin:0 0 4px 0; color: var(--color-primary);">Factura #${f.facturaId}</h3>
                    <p style="margin:0 0 16px 0; font-size:13px; color:var(--color-text-muted);">
                        Doc: ${f.numeroDocumento || '—'} &nbsp;|&nbsp; Control: ${f.control || '—'} &nbsp;|&nbsp; Serie: ${f.serie || '—'}
                    </p>

                    <table style="width:100%; border-collapse:collapse; font-size:14px;">
                        <tr>
                            <td style="padding:6px 0; color:var(--color-text-muted);">Fecha de emisión</td>
                            <td style="padding:6px 0; text-align:right;">${f.fechaEmision || '—'} ${f.horaEmision || ''}</td>
                        </tr>
                        <tr>
                            <td style="padding:6px 0; color:var(--color-text-muted);">Cliente</td>
                            <td style="padding:6px 0; text-align:right;">${f.clienteNombre || '—'}</td>
                        </tr>
                        <tr>
                            <td style="padding:6px 0; color:var(--color-text-muted);">Cédula</td>
                            <td style="padding:6px 0; text-align:right;">${f.clienteCedula || '—'}</td>
                        </tr>
                        <tr>
                            <td style="padding:6px 0; color:var(--color-text-muted);">Dirección</td>
                            <td style="padding:6px 0; text-align:right;">${f.clienteDireccion || '—'}</td>
                        </tr>
                        <tr>
                            <td style="padding:6px 0; color:var(--color-text-muted);">Chofer</td>
                            <td style="padding:6px 0; text-align:right;">${f.choferNombre || '—'}</td>
                        </tr>
                        <tr>
                            <td style="padding:6px 0; color:var(--color-text-muted);">Origen</td>
                            <td style="padding:6px 0; text-align:right;">${f.zonaOrigen || '—'}</td>
                        </tr>
                        <tr>
                            <td style="padding:6px 0; color:var(--color-text-muted);">Destino</td>
                            <td style="padding:6px 0; text-align:right;">${f.zonaDestino || '—'}</td>
                        </tr>
                        <tr>
                            <td style="padding:6px 0; color:var(--color-text-muted);">Distancia (Km)</td>
                            <td style="padding:6px 0; text-align:right;">${f.distanciaKm != null ? Number(f.distanciaKm).toFixed(2) : '—'}</td>
                        </tr>
                        <tr style="border-top:1px solid #eee;">
                            <td style="padding:8px 0; color:var(--color-text-muted);">Costo USD</td>
                            <td style="padding:8px 0; text-align:right; font-weight:600;">$${f.costoUsd != null ? Number(f.costoUsd).toFixed(2) : '0.00'}</td>
                        </tr>
                        <tr>
                            <td style="padding:6px 0; color:var(--color-text-muted);">Tasa BCV (Bs)</td>
                            <td style="padding:6px 0; text-align:right;">${f.tasaVes != null ? Number(f.tasaVes).toFixed(2) : '—'}</td>
                        </tr>
                        ${f.descuentoUsd > 0 ? `
                        <tr>
                            <td style="padding:6px 0; color:#1E6B3C; font-weight:600;">Descuento (USD / Bs)</td>
                            <td style="padding:6px 0; text-align:right; color:#1E6B3C; font-weight:600;">
                                -$${Number(f.descuentoUsd).toFixed(2)} / -Bs ${f.descuentoVes != null ? Number(f.descuentoVes).toFixed(2) : '0.00'}
                            </td>
                        </tr>
                        ` : ''}
                        <tr>
                            <td style="padding:6px 0; color:var(--color-text-muted);">IGTF USD</td>
                            <td style="padding:6px 0; text-align:right;">$${f.montoIgtfUsd != null ? Number(f.montoIgtfUsd).toFixed(2) : '0.00'}</td>
                        </tr>
                        <tr style="border-top:2px solid var(--color-primary);">
                            <td style="padding:10px 0; font-weight:700;">Total USD</td>
                            <td style="padding:10px 0; text-align:right; font-weight:700; color:var(--color-primary);">
                                $${f.totalUsd != null ? Number(f.totalUsd).toFixed(2) : '0.00'}
                            </td>
                        </tr>
                        <tr>
                            <td style="padding:6px 0; font-weight:600;">Total Bs</td>
                            <td style="padding:6px 0; text-align:right; font-weight:600;">
                                Bs ${f.totalVes != null ? Number(f.totalVes).toFixed(2) : '0.00'}
                            </td>
                        </tr>
                    </table>

                    <button onclick="document.getElementById('modal-factura').remove()"
                        class="btn-primary" style="margin-top:20px; width:100%;">
                        Cerrar
                    </button>
                </div>
            </div>
        `;

        // Inyectar el modal al body
        document.body.insertAdjacentHTML('beforeend', modalHTML);

        // Cerrar al hacer clic fuera del contenido
        document.getElementById('modal-factura').addEventListener('click', (e) => {
            if (e.target.id === 'modal-factura') {
                e.target.remove();
            }
        });

    } catch (error) {
        console.error("Error obteniendo factura:", error);
        alert('No se pudo cargar la factura. ' + (error.message || ''));
    }
};

// ─────────────────────────────────────────────────────────
// Lógica del Modal de Detalles
// ─────────────────────────────────────────────────────────

const ESTADOS_DETALLE = {
    'solicitado':   { texto: 'Buscando chofer',        icono: '🔍', bg: '#FFF3E0', color: '#C55A11' },
    'aceptado':     { texto: 'Chofer asignado',         icono: '✅', bg: '#E3F2FD', color: '#1F4E79' },
    'en_camino':    { texto: 'Chofer en camino',        icono: '🚗', bg: '#E3F2FD', color: '#1F4E79' },
    'chofer_llego': { texto: '¡Chofer llegó!',          icono: '📍', bg: '#E8F5E9', color: '#2E7D32' },
    'en_progreso':  { texto: 'Viaje en progreso',       icono: '🛣️', bg: '#E8F5E9', color: '#2E7D32' },
    'completado':   { texto: 'Completado',              icono: '⭐', bg: '#E8F5E9', color: '#2E7D32' },
    'cancelado':    { texto: 'Cancelado',               icono: '❌', bg: '#FFEBEE', color: '#C62828' }
};

window.abrirModalDetalles = function(viaje) {
    const estadoActual = viaje.status ? viaje.status.toLowerCase() : '';
    const cfg = ESTADOS_DETALLE[estadoActual] || { texto: viaje.status, icono: '⏳', bg: '#EEE', color: '#666' };

    document.getElementById('detalle-estado-badge').textContent = cfg.texto;
    document.getElementById('detalle-estado-badge').style.background = cfg.bg;
    document.getElementById('detalle-estado-badge').style.color = cfg.color;

    const icono = document.getElementById('detalle-estado-icono');
    if (viaje.driver && estadoActual !== 'solicitado') {
        const partes = (viaje.driver.user?.nombre || '').split(' ');
        icono.textContent = ((partes[0]?.[0] || '') + (partes[1]?.[0] || '')).toUpperCase() || 'CH';
        icono.style.background = 'var(--color-secondary)';
    } else {
        icono.textContent = cfg.icono;
        icono.style.background = 'var(--color-primary)';
    }

    const originName = viaje.originZone ? (viaje.originZone.name || viaje.originZone.nombre) : 'Zona Origen';
    const destName = viaje.destinationZone ? (viaje.destinationZone.name || viaje.destinationZone.nombre) : 'Zona Destino';
    document.getElementById('detalle-ruta-texto').textContent = `${originName}  →  ${destName}`;

    // Mostrar quién canceló
    const cancelInfo = document.getElementById('detalle-cancel-info');
    if (estadoActual === 'cancelado') {
        cancelInfo.style.display = 'block';
        cancelInfo.textContent = `Cancelado por: ${viaje.cancelledBy === 'chofer' ? 'El Chofer' : 'Tú'}`;
    } else {
        cancelInfo.style.display = 'none';
    }

    // Chofer y Vehículo
    if (viaje.driver && (estadoActual !== 'solicitado' || estadoActual === 'cancelado')) {
        document.getElementById('detalle-chofer-nombre').textContent = viaje.driver.user ? `${viaje.driver.user.nombre} ${viaje.driver.user.apellido}` : (viaje.driverName || 'N/A');
        document.getElementById('detalle-chofer-telefono').textContent = viaje.driver.user?.phone || '—';
        
        if (viaje.vehicle) {
            document.getElementById('detalle-vehiculo-modelo').textContent = `${viaje.vehicle.marca || viaje.vehicle.brand} ${viaje.vehicle.modelo || viaje.vehicle.model}`;
            document.getElementById('detalle-vehiculo-color').textContent = viaje.vehicle.color || '—';
            document.getElementById('detalle-vehiculo-placa').textContent = viaje.vehicle.placa || viaje.vehicle.plate || '—';
        } else {
            document.getElementById('detalle-vehiculo-modelo').textContent = '—';
            document.getElementById('detalle-vehiculo-color').textContent = '—';
            document.getElementById('detalle-vehiculo-placa').textContent = '—';
        }

        document.getElementById('detalle-chofer-card').classList.remove('hidden');
        document.getElementById('detalle-vehiculo-card').classList.remove('hidden');

        // Mostrar Evaluaciones si es completado
        if (estadoActual === 'completado') {
            document.getElementById('detalle-eval-psicologica').style.display = 'flex';
            document.getElementById('detalle-rev-tecnica').style.display = 'flex';
        } else {
            document.getElementById('detalle-eval-psicologica').style.display = 'none';
            document.getElementById('detalle-rev-tecnica').style.display = 'none';
        }
    } else {
        document.getElementById('detalle-chofer-card').classList.add('hidden');
        document.getElementById('detalle-vehiculo-card').classList.add('hidden');
    }

    // Botón cancelar
    const btnCancelar = document.getElementById('detalle-btn-cancelar');
    if (estadoActual === 'solicitado' || estadoActual === 'aceptado') {
        btnCancelar.classList.remove('hidden');
        btnCancelar.onclick = () => confirmarCancelacion(viaje.id);
    } else {
        btnCancelar.classList.add('hidden');
    }

    document.getElementById('trip-details-modal').style.display = 'flex';
};

window.cerrarModalDetalles = function() {
    document.getElementById('trip-details-modal').style.display = 'none';
};

async function confirmarCancelacion(tripId) {
    if (!confirm('¿Estás seguro de que deseas cancelar este viaje?')) return;
    try {
        await fetchAPI(`/cliente/traslados/${tripId}/cancelar`, 'PUT', { motivo: 'Cancelado por el cliente' });
        cerrarModalDetalles();
        cargarHistorial();
    } catch (error) {
        alert('No se pudo cancelar: ' + (error.message || 'Error desconocido'));
    }
}