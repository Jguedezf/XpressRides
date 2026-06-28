document.addEventListener('DOMContentLoaded', async () => {
    // 1. Proteger la ruta (Regla de la Guía)
    if (!requireAuth()) return;
});

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
        const response = await fetchAPI(`/reportes/ganancias?desde=${fechaInicio}&hasta=${fechaFin}`);
        const registros = response.data || [];

        if (registros.length === 0) {
            tbodyGanancias.innerHTML = '<tr><td colspan="4" class="text-center">No hay viajes en este rango de fechas.</td></tr>';
            totalSpan.innerText = "$ 0.00";
            return;
        }

        tbodyGanancias.innerHTML = '';
        let granTotal = 0;

        registros.forEach(reg => {
            const ganancia = Number(reg.totalCompanyUsd || 0);
            const costoMovido = Number(reg.totalCostUsd || 0);
            const descuento = Number(reg.discountUsd || 0);
            
            granTotal += ganancia;
            tbodyGanancias.innerHTML += `
                <tr>
                    <td>#${reg.id}</td>
                    <td>${reg.date}</td>
                    <td>$ ${costoMovido.toFixed(2)}</td>
                    <td style="color: var(--color-error);">- $ ${descuento.toFixed(2)}</td>
                    <td style="color: ${ganancia < 0 ? 'var(--color-error)' : 'var(--color-success)'}; font-weight: bold;">
                        ${ganancia < 0 ? '' : '+ '} $ ${ganancia.toFixed(2)}
                    </td>
                    <td style="font-size: 13px;">${reg.concept}</td>
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