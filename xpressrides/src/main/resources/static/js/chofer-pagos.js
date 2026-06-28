document.addEventListener('DOMContentLoaded', async () => {
    // 1. Proteger la ruta (Regla de la Guía)
    if (!requireAuth()) return;

    await cargarFinanzas();
});

async function cargarFinanzas() {
    const saldoPendiente = document.getElementById('saldo-pendiente');
    const pagosContainer = document.getElementById('pagos-container');
    const btnSolicitar = document.getElementById('btn-solicitar-retiro');

    try {
        // 1. Cargar saldo pendiente (desde el perfil)
        const profileResponse = await fetchAPI('/chofer/perfil');
        const driverData = profileResponse.data;
        const saldo = Number(driverData.saldoAcumuladoUsd || 0);
        saldoPendiente.innerText = `$ ${saldo.toFixed(2)}`;

        // Deshabilitar botón si no hay saldo
        if (saldo <= 0) {
            btnSolicitar.disabled = true;
            btnSolicitar.style.opacity = '0.5';
        } else {
            btnSolicitar.disabled = false;
            btnSolicitar.style.opacity = '1';
        }

        // 2. Cargar historial de pagos
        const desde = document.getElementById('filtro-desde')?.value || '';
        const hasta = document.getElementById('filtro-hasta')?.value || '';

        let url = '/chofer/pagos';
        if (desde || hasta) {
            url += '?';
            if (desde) url += `desde=${desde}&`;
            if (hasta) url += `hasta=${hasta}&`;
            // Remove trailing & if needed, fetchAPI handles simple queries but we can format string
            url = url.endsWith('&') ? url.slice(0, -1) : url;
        }

        const pagosResponse = await fetchAPI(url);
        const pagos = pagosResponse.data || [];

        if (pagos.length === 0) {
            pagosContainer.innerHTML = '<p class="text-center text-muted mt-lg">No has recibido pagos todavía.</p>';
            return;
        }

        pagosContainer.innerHTML = '';
        pagos.forEach(pago => {
            const fecha = new Date(pago.dateTime).toLocaleDateString('es-VE', {
                day: '2-digit', month: 'short', year: 'numeric',
                hour: '2-digit', minute: '2-digit'
            });

            pagosContainer.innerHTML += `
                <div class="premium-card mb-md d-flex justify-between align-center" style="padding: 15px;">
                    <div>
                        <p class="trip-location">Transferencia Bancaria</p>
                        <p class="trip-time">${fecha}</p>
                        <p class="trip-time" style="font-size: 12px; margin-top: 5px;">Ref: ${pago.reference} | Banco: ${pago.bank.name}</p>
                    </div>
                    <div class="trip-amount">
                        <p class="trip-usd">+$ ${Number(pago.amountUsd).toFixed(2)}</p>
                        <p class="trip-time">Bs ${Number(pago.amountVes).toFixed(2)}</p>
                    </div>
                </div>
            `;
        });

    } catch (error) {
        pagosContainer.innerHTML = `<p class="text-center" style="color: var(--color-error);">Error: ${error.message}</p>`;
    }
}

async function solicitarRetiro() {
    const btn = document.getElementById('btn-solicitar-retiro');
    const successAlert = document.getElementById('retiro-success');
    const errorAlert = document.getElementById('retiro-error');

    successAlert.style.display = 'none';
    errorAlert.style.display = 'none';

    btn.innerText = "Enviando solicitud...";
    btn.disabled = true;

    try {
        const response = await fetchAPI('/chofer/solicitar-retiro', {
            method: 'POST'
        });

        successAlert.innerText = response.message || "Solicitud de retiro enviada correctamente.";
        successAlert.style.display = 'block';

    } catch (error) {
        errorAlert.innerText = error.message;
        errorAlert.style.display = 'block';
        btn.disabled = false;
    } finally {
        if(btn.disabled === false) btn.innerText = "Solicitar Retiro";
    }
}

// Eventos de filtro
document.getElementById('form-filtros-historial')?.addEventListener('submit', (e) => {
    e.preventDefault();
    cargarFinanzas();
});

document.getElementById('btn-limpiar-filtros')?.addEventListener('click', () => {
    document.getElementById('filtro-desde').value = '';
    document.getElementById('filtro-hasta').value = '';
    cargarFinanzas();
});
