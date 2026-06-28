document.addEventListener('DOMContentLoaded', async () => {
    // 1. Proteger la ruta (Regla de la Guía)
    if (!requireAuth()) return;

    // 2. Cargar listas
    await cargarPagosPendientes();
    await cargarHistorialPagos();
});

/* ==========================================
   MÓDULO: PAGOS A CHOFERES (Pendientes)
========================================== */
async function cargarPagosPendientes() {
    const tbodyPagos = document.getElementById('tbody-pagos');

    try {
        const response = await fetchAPI('/reportes/pendientes-pago');
        const deudas = response.data || [];

        if (deudas.length === 0) {
            tbodyPagos.innerHTML = '<tr><td colspan="5" class="text-center" style="color: var(--color-success);">¡Todo al día! No hay pagos pendientes.</td></tr>';
            return;
        }

        tbodyPagos.innerHTML = ''; 

        deudas.forEach(deuda => {
            tbodyPagos.innerHTML += `
                <tr>
                    <td>${deuda.driverName}</td>
                    <td>${deuda.pendingTrips} viajes</td>
                    <td style="font-weight: bold; color: var(--color-success);">$ ${Number(deuda.accumulatedBalanceUsd).toFixed(2)}</td>
                    <td><span style="background-color: #FCE4D6; color: #C00000; padding: 4px 8px; border-radius: 4px; font-size: 11px; font-weight: bold;">PENDIENTE</span></td>
                    <td>
                        <button class="btn-secondary" style="padding: 6px 12px; font-size: 13px;" onclick="abrirModalPago(${deuda.driverId}, '${deuda.driverName}', ${deuda.accumulatedBalanceUsd})">Registrar Pago</button>
                    </td>
                </tr>
            `;
        });
    } catch (error) {
        tbodyPagos.innerHTML = `<tr><td colspan="5" class="text-center" style="color: var(--color-error);">Error: ${error.message}</td></tr>`;
    }
}

/* ==========================================
   MÓDULO: HISTORIAL DE PAGOS
========================================== */
async function cargarHistorialPagos() {
    const tbodyHistorial = document.getElementById('tbody-historial');
    const desde = document.getElementById('filtro-desde').value;
    const hasta = document.getElementById('filtro-hasta').value;
    const nombre = document.getElementById('filtro-nombre').value;

    try {
        let url = '/reportes/pagos-chofer?';
        if (desde) url += `desde=${desde}&`;
        if (hasta) url += `hasta=${hasta}&`;
        if (nombre) url += `nombre=${encodeURIComponent(nombre)}`;

        const response = await fetchAPI(url);
        const pagos = response.data || [];

        if (pagos.length === 0) {
            tbodyHistorial.innerHTML = '<tr><td colspan="6" class="text-center">No se encontraron pagos con los filtros aplicados.</td></tr>';
            return;
        }

        tbodyHistorial.innerHTML = '';

        pagos.forEach(pago => {
            let fechaStr = 'N/A';
            let horaStr = '';
            if (pago.dateTime) {
                const d = new Date(pago.dateTime);
                fechaStr = d.toLocaleDateString('es-VE');
                horaStr = d.toLocaleTimeString('es-VE', { hour: '2-digit', minute: '2-digit', hour12: true });
            }
            
            tbodyHistorial.innerHTML += `
                <tr>
                    <td>
                        ${fechaStr}
                        <div style="font-size: 0.85em; color: #64748b; margin-top: 2px;">${horaStr}</div>
                    </td>
                    <td style="font-weight: 500;">${pago.driverName}</td>
                    <td style="color: var(--color-success); font-weight: bold;">$ ${Number(pago.amountUsd).toFixed(2)}</td>
                    <td>Bs. ${Number(pago.amountVes).toFixed(2)}</td>
                    <td>${pago.bankName}</td>
                    <td style="font-family: monospace;">${pago.reference}</td>
                </tr>
            `;
        });
    } catch (error) {
        tbodyHistorial.innerHTML = `<tr><td colspan="6" class="text-center" style="color: var(--color-error);">Error: ${error.message}</td></tr>`;
    }
}

// Eventos de filtro
document.getElementById('form-filtros-historial')?.addEventListener('submit', (e) => {
    e.preventDefault();
    cargarHistorialPagos();
});

document.getElementById('btn-limpiar-filtros')?.addEventListener('click', () => {
    document.getElementById('filtro-desde').value = '';
    document.getElementById('filtro-hasta').value = '';
    document.getElementById('filtro-nombre').value = '';
    cargarHistorialPagos();
});

/* ==========================================
   MÓDULO: MODAL DE PAGO
========================================== */
async function abrirModalPago(choferId, choferName, totalUsd) {
    document.getElementById('modal-pago-chofer-id').value = choferId;
    document.getElementById('modal-pago-subtitle').innerText = `Chofer: ${choferName}`;
    document.getElementById('modal-pago-monto').value = `$ ${Number(totalUsd).toFixed(2)}`;
    
    // Obtener tasa BCV para calcular monto en VES
    const inputVes = document.getElementById('modal-pago-monto-ves');
    inputVes.value = "Calculando...";
    try {
        const rateResponse = await fetchAPI('/tasa-bcv/vigente');
        if (rateResponse && rateResponse.data && rateResponse.data.rateVes) {
            const tasa = rateResponse.data.rateVes;
            const totalVes = (Number(totalUsd) * tasa).toFixed(2);
            inputVes.value = `Bs. ${totalVes}`;
        } else {
            inputVes.value = "Tasa no disponible";
        }
    } catch (e) {
        inputVes.value = "Error al obtener tasa";
    }
    
    document.getElementById('modal-pago-banco').value = '';
    document.getElementById('modal-pago-referencia').value = '';
    
    document.getElementById('modal-pago-chofer').style.display = 'flex';
}

function cerrarModalPago() {
    document.getElementById('modal-pago-chofer').style.display = 'none';
}

// Evento submit del form dentro del modal
document.getElementById('form-registrar-pago').addEventListener('submit', async (e) => {
    e.preventDefault();

    const btn = document.getElementById('btn-confirmar-pago');
    const successAlert = document.getElementById('pago-success');
    const errorAlert = document.getElementById('pago-error');

    successAlert.style.display = 'none';
    errorAlert.style.display = 'none';

    btn.innerText = "Procesando...";
    btn.disabled = true;

    try {
        const payload = {
            driver: { id: document.getElementById('modal-pago-chofer-id').value },
            bank: { id: document.getElementById('modal-pago-banco').value },
            reference: document.getElementById('modal-pago-referencia').value
        };

        await fetchAPI('/pagos-chofer', {
            method: 'POST',
            body: JSON.stringify(payload)
        });

        cerrarModalPago();
        successAlert.style.display = 'block';
        
        // Recargar ambas tablas
        await cargarPagosPendientes();
        await cargarHistorialPagos();
        
        setTimeout(() => successAlert.style.display = 'none', 3000);

    } catch (error) {
        errorAlert.innerText = error.message;
        errorAlert.style.display = 'block';
        cerrarModalPago();
    } finally {
        btn.innerText = "Confirmar Pago";
        btn.disabled = false;
    }
});
