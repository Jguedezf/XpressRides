document.addEventListener('DOMContentLoaded', async () => {
    // 1. Proteger la ruta (Regla de la Guía)
    if (!requireAuth()) return;

    // 2. Cargar automáticamente la lista de choferes a los que se les debe dinero
    await cargarPagosPendientes();
});

/* ==========================================
   MÓDULO: PAGOS A CHOFERES
========================================== */
async function cargarPagosPendientes() {
    const tbodyPagos = document.getElementById('tbody-pagos');

    try {
        // Consumimos el endpoint de pagos pendientes
        const response = await fetchAPI('/admin/pagos/pendientes');
        const deudas = response.data || [];

        if (deudas.length === 0) {
            tbodyPagos.innerHTML = '<tr><td colspan="5" class="text-center" style="color: var(--color-success);">¡Todo al día! No hay pagos pendientes.</td></tr>';
            return;
        }

        tbodyPagos.innerHTML = ''; // Limpiamos el "Cargando..."

        // Inyectamos las filas reales
        deudas.forEach(deuda => {
            tbodyPagos.innerHTML += `
                <tr>
                    <td>${deuda.choferNombre} (V-${deuda.choferCedula})</td>
                    <td>${deuda.viajesPendientes} viajes</td>
                    <td style="font-weight: bold;">$ ${deuda.montoPendiente.toFixed(2)}</td>
                    <td><span style="background-color: #FCE4D6; color: #C00000; padding: 4px 8px; border-radius: 4px; font-size: 11px; font-weight: bold;">PENDIENTE</span></td>
                    <td>
                        <button class="premium-btn btn-sm" onclick="registrarPago(event, ${deuda.choferId})">Registrar Pago</button>
                    </td>
                </tr>
            `;
        });
    } catch (error) {
        tbodyPagos.innerHTML = `<tr><td colspan="5" class="text-center" style="color: var(--color-error);">Error: ${error.message}</td></tr>`;
    }
}

// Función accionada por el botón de la tabla (POST / PUT)
async function registrarPago(event, choferId) {
    const btn = event.target;
    const successAlert = document.getElementById('pago-success');
    const errorAlert = document.getElementById('pago-error');

    successAlert.style.display = 'none';
    errorAlert.style.display = 'none';

    // Feedback visual (Regla 5 de la Guía)
    btn.innerText = "Procesando...";
    btn.disabled = true;
    btn.style.opacity = "0.7";

    try {
        // Objeto que enviaremos a Java
        const payload = { choferId: choferId };

        // Enviar petición POST usando fetchAPI
        await fetchAPI('/admin/pagos/registrar', {
            method: 'POST',
            body: JSON.stringify(payload)
        });

        successAlert.style.display = 'block';

        // Refrescamos la tabla para que desaparezca la deuda pagada
        await cargarPagosPendientes();

        // Ocultamos la alerta a los 3 segundos
        setTimeout(() => successAlert.style.display = 'none', 3000);

    } catch (error) {
        errorAlert.innerText = error.message;
        errorAlert.style.display = 'block';

        // Restauramos el botón si hubo error
        btn.innerText = "Registrar Pago";
        btn.disabled = false;
        btn.style.opacity = "1";
    }
}

/* ==========================================
   MÓDULO: GANANCIAS DE LA EMPRESA
========================================== */
document.getElementById('form-filtro-ganancias').addEventListener('submit', async (e) => {
    e.preventDefault();

    const btn = document.getElementById('btn-filtrar');
    const tbodyGanancias = document.getElementById('tbody-ganancias');
    const totalSpan = document.getElementById('total-ganancias');
    const originalText = btn.innerText;

    btn.innerText = 'Buscando...';
    btn.disabled = true;

    const fechaInicio = document.getElementById('fechaInicio').value;
    const fechaFin = document.getElementById('fechaFin').value;

    try {
        // Petición GET con variables en la URL
        const response = await fetchAPI(`/admin/reportes/ganancias?inicio=${fechaInicio}&fin=${fechaFin}`);
        const registros = response.data || [];

        if (registros.length === 0) {
            tbodyGanancias.innerHTML = '<tr><td colspan="4" class="text-center">No hay viajes en este rango de fechas.</td></tr>';
            totalSpan.innerText = "$ 0.00";
            return;
        }

        tbodyGanancias.innerHTML = '';
        let granTotal = 0;

        registros.forEach(reg => {
            granTotal += reg.gananciaEmpresa;
            tbodyGanancias.innerHTML += `
                <tr>
                    <td>${reg.fecha}</td>
                    <td>${reg.cantidadViajes} viajes</td>
                    <td>$ ${reg.costoTotal.toFixed(2)}</td>
                    <td style="color: var(--color-success); font-weight: bold;">+ $ ${reg.gananciaEmpresa.toFixed(2)}</td>
                </tr>
            `;
        });

        // Actualizamos el gran total abajo de la tabla
        totalSpan.innerText = `$ ${granTotal.toFixed(2)}`;

    } catch (error) {
        tbodyGanancias.innerHTML = `<tr><td colspan="4" class="text-center" style="color: var(--color-error);">Error: ${error.message}</td></tr>`;
    } finally {
        btn.innerText = originalText;
        btn.disabled = false;
    }
});