// js/cliente-record.js
// Historial de viajes del cliente con opción de ver factura

document.addEventListener('DOMContentLoaded', async () => {
    await cargarHistorial();
});

async function cargarHistorial() {
    const container = document.getElementById('historial-container');

    // 1. Obtener los datos del usuario logueado desde LocalStorage
    const usuarioString = localStorage.getItem('xpressUsuario');
    if (!usuarioString) {
        // Sin sesión activa, redirigir al login
        window.location.href = '../views/login.html';
        return;
    }

    const usuario = JSON.parse(usuarioString);

    // Mostramos estado de carga
    container.innerHTML = '<p class="text-center mt-md" style="color: var(--color-text-muted);">Cargando tu historial de viajes...</p>';

    try {
        // 2. Consumir el endpoint que trae los traslados del cliente (filtrado por JWT en el backend)
        const response = await fetchAPI('/cliente/traslados');
        const viajes = Array.isArray(response) ? response : (response.data || []);

        if (viajes.length === 0) {
            container.innerHTML = '<p class="text-center mt-md">Aún no tienes viajes registrados. ¡Solicita tu primer XpressRide!</p>';
            return;
        }

        // 3. Limpiar contenedor e inyectar tarjetas dinámicas
        container.innerHTML = '';

        viajes.forEach(viaje => {
            // Evaluamos clases CSS dinámicas según el estado del viaje
            const esCompletado = viaje.status && viaje.status.toLowerCase() === 'completado';
            const statusClass = esCompletado ? 'status-completado' : 'status-cancelado';

            // Construir info del vehículo a partir de la entidad anidada
            const vehiculoInfo = viaje.vehicle 
                ? [viaje.vehicle.marca || viaje.vehicle.brand, viaje.vehicle.modelo || viaje.vehicle.model, viaje.vehicle.color].filter(Boolean).join(' ') 
                : '';

            // Formatear fecha "19 jun 2026, 02:30 p.m."
            const fechaObj = new Date(viaje.requestDate);
            const opcionesFecha = { day: '2-digit', month: 'short', year: 'numeric', hour: '2-digit', minute: '2-digit' };
            const fechaFormateada = fechaObj.toLocaleDateString('es-VE', opcionesFecha);

            const originName = viaje.originZone ? (viaje.originZone.name || viaje.originZone.nombre) : 'Zona Origen';
            const destName = viaje.destinationZone ? (viaje.destinationZone.name || viaje.destinationZone.nombre) : 'Zona Destino';
            const driverName = viaje.driver && viaje.driver.user ? `${viaje.driver.user.nombre} ${viaje.driver.user.apellido}` : (viaje.driverName || '');

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
                        <span class="trip-price" ${!esCompletado ? 'style="text-decoration: line-through; color: var(--color-text-muted);"' : ''}>
                            $${viaje.customerCostUsd ? viaje.customerCostUsd.toFixed(2) : '0.00'}
                        </span>
                        
                        ${esCompletado ? `
                            <button class="btn-secondary" style="padding: 6px 12px; font-size: 12px; width: auto;" onclick="verFactura(${viaje.id})">
                                Ver Factura
                            </button>
                        ` : `
                            <span style="font-size: 12px; color: var(--color-error);">Cancelado</span>
                        `}
                    </div>
                </div>
            `;
            container.innerHTML += cardHTML;
        });

    } catch (error) {
        console.error("Error cargando historial:", error);
        container.innerHTML = `<div class="alert-error">No pudimos cargar tu historial: ${error.message}</div>`;
    }
}

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
                        <tr style="border-top:1px solid #eee;">
                            <td style="padding:8px 0; color:var(--color-text-muted);">Costo USD</td>
                            <td style="padding:8px 0; text-align:right; font-weight:600;">$${f.costoUsd != null ? Number(f.costoUsd).toFixed(2) : '0.00'}</td>
                        </tr>
                        <tr>
                            <td style="padding:6px 0; color:var(--color-text-muted);">Tasa BCV (Bs)</td>
                            <td style="padding:6px 0; text-align:right;">${f.tasaVes != null ? Number(f.tasaVes).toFixed(2) : '—'}</td>
                        </tr>
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