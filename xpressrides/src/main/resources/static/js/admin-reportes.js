document.addEventListener('DOMContentLoaded', async () => {
    // 1. Proteger la ruta (Regla de la Guía)
    if (!requireAuth()) return;
});

let ultimosRegistrosIngresos = [];

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
        ultimosRegistrosIngresos = registros;

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

/* ==========================================
   MÓDULO: TRASLADOS CANCELADOS
========================================== */
document.getElementById('form-filtro-cancelados').addEventListener('submit', async (e) => {
    e.preventDefault();

    const btn = document.getElementById('btn-filtrar-cancelados');
    const tbodyCancelados = document.getElementById('tbody-cancelados');
    const originalText = btn.innerText;

    btn.innerText = 'Buscando...';
    btn.disabled = true;

    const fechaInicio = document.getElementById('fechaInicioCancel').value;
    const fechaFin = document.getElementById('fechaFinCancel').value;

    try {
        const response = await fetchAPI(`/reportes/cancelados?desde=${fechaInicio}&hasta=${fechaFin}`);
        const registros = response.data || [];

        if (registros.length === 0) {
            tbodyCancelados.innerHTML = '<tr><td colspan="8" class="text-center">No hay traslados cancelados en este rango de fechas.</td></tr>';
            return;
        }

        tbodyCancelados.innerHTML = '';

        registros.forEach(reg => {
            const fecha = reg.requestDate ? new Date(reg.requestDate).toLocaleString('es-VE') : '';
            tbodyCancelados.innerHTML += `
                <tr>
                    <td>#${reg.id}</td>
                    <td>${fecha}</td>
                    <td>${reg.customerName || ''}</td>
                    <td>${reg.driverName || ''}</td>
                    <td>${reg.originZone || ''}</td>
                    <td>${reg.destinationZone || ''}</td>
                    <td style="text-transform: capitalize;">${reg.cancelledBy || ''}</td>
                    <td>${reg.cancellationReason || ''}</td>
                </tr>
            `;
        });

    } catch (error) {
        tbodyCancelados.innerHTML = `<tr><td colspan="8" class="text-center" style="color: var(--color-error);">Error: ${error.message}</td></tr>`;
    } finally {
        btn.innerText = originalText;
        btn.disabled = false;
    }
});

/* ==========================================
   MÓDULO: TRASLADOS DE LA EMPRESA POR PERÍODO
========================================== */
document.getElementById('form-filtro-historial').addEventListener('submit', async (e) => {
    e.preventDefault();

    const btn = document.getElementById('btn-filtrar-historial');
    const tbodyHistorial = document.getElementById('tbody-historial');
    const originalText = btn.innerText;

    btn.innerText = 'Buscando...';
    btn.disabled = true;

    const fechaInicio = document.getElementById('fechaInicioHistorial').value;
    const fechaFin = document.getElementById('fechaFinHistorial').value;

    try {
        const response = await fetchAPI(`/reportes/historial-traslados?desde=${fechaInicio}&hasta=${fechaFin}`);
        const registros = response.data || [];

        if (registros.length === 0) {
            tbodyHistorial.innerHTML = '<tr><td colspan="8" class="text-center">No hay traslados en este rango de fechas.</td></tr>';
            return;
        }

        tbodyHistorial.innerHTML = '';

        registros.forEach(reg => {
            const fecha = reg.requestDate ? new Date(reg.requestDate).toLocaleString('es-VE') : '';
            const costo = reg.customerCostUsd != null ? Number(reg.customerCostUsd).toFixed(2) : '0.00';
            tbodyHistorial.innerHTML += `
                <tr>
                    <td>#${reg.id}</td>
                    <td>${fecha}</td>
                    <td>${reg.customerName || ''}</td>
                    <td>${reg.driverName || ''}</td>
                    <td>${reg.originZone || ''}</td>
                    <td>${reg.destinationZone || ''}</td>
                    <td style="text-transform: capitalize;">${reg.status || ''}</td>
                    <td>$ ${costo}</td>
                </tr>
            `;
        });

    } catch (error) {
        tbodyHistorial.innerHTML = `<tr><td colspan="8" class="text-center" style="color: var(--color-error);">Error: ${error.message}</td></tr>`;
    } finally {
        btn.innerText = originalText;
        btn.disabled = false;
    }
});

/* ==========================================
   MÓDULO: IMPRESIÓN DEL REPORTE (reutilizable por las 3 secciones)
========================================== */
function imprimirReporte({ fechaInicioId, fechaFinId, tbodyId, titulo, headers, footerHtml }) {
    // 1. Eliminar versiones previas de impresión
    const prevPrint = document.getElementById('reporte-impresion');
    if (prevPrint) prevPrint.remove();
    const prevPrintStyle = document.getElementById('print-style-reporte');
    if (prevPrintStyle) prevPrintStyle.remove();

    // 2. Extraer datos actuales
    const fechaInicio = document.getElementById(fechaInicioId).value || '---';
    const fechaFin = document.getElementById(fechaFinId).value || '---';
    const tbodyHTML = document.getElementById(tbodyId).innerHTML;

    // 3. Crear estilo de impresión aislado
    const printStyles = `
        <style id="print-style-reporte">
            @media print {
                body { display: block !important; height: auto !important; min-height: 0 !important; background: white !important; padding: 0 !important; }
                body * { visibility: hidden; }
                #reporte-impresion, #reporte-impresion * { visibility: visible; }
                #reporte-impresion { display: block !important; position: absolute; left: 0; top: 0; width: 100%; margin: 0; padding: 20px; box-sizing: border-box; }

                .print-header { display: flex; justify-content: space-between; align-items: flex-start; border-bottom: 2px solid #1F4E79; padding-bottom: 20px; margin-bottom: 20px; }
                .print-logo { height: 60px; object-fit: contain; }
                .print-company-info { text-align: center; font-size: 14px; }
                .print-doc-info { text-align: right; font-size: 14px; }

                .print-title { text-align: center; color: #1F4E79; margin: 20px 0; font-size: 22px; font-weight: bold; }

                .print-table { width: 100%; border-collapse: collapse; margin-top: 20px; font-size: 12px; }
                .print-table th { background-color: #1F4E79 !important; color: white !important; padding: 10px; text-align: left; -webkit-print-color-adjust: exact; print-color-adjust: exact; }
                .print-table td { border-bottom: 1px solid #ccc; padding: 10px; }

                .print-footer { margin-top: 30px; text-align: right; font-size: 18px; font-weight: bold; color: #1F4E79; }

                @page { margin: 1cm; size: auto; }
            }
        </style>
    `;

    document.head.insertAdjacentHTML('beforeend', printStyles);

    // 4. Construir contenedor de impresión
    const printContainer = document.createElement('div');
    printContainer.id = 'reporte-impresion';
    printContainer.style.display = 'none'; // Oculto en pantalla normal

    const fechaActual = new Date().toLocaleDateString('es-VE', { year: 'numeric', month: '2-digit', day: '2-digit' });
    const headersHTML = headers.map(h => `<th>${h}</th>`).join('');

    printContainer.innerHTML = `
        <div class="print-header">
            <img src="/img/logo.png" alt="XpressRides Logo" class="print-logo">
            <div class="print-company-info">
                <strong>XpressRides, C.A.</strong><br>
                RIF: J-50301732-5<br>
                Domicilio Fiscal: Ciudad Guayana
            </div>
            <div class="print-doc-info">
                <strong>Reporte Administrativo</strong><br>
                Generado: ${fechaActual}<br>
                Periodo: ${fechaInicio} al ${fechaFin}
            </div>
        </div>

        <div class="print-title">${titulo}</div>

        <table class="print-table">
            <thead>
                <tr>${headersHTML}</tr>
            </thead>
            <tbody>
                ${tbodyHTML}
            </tbody>
        </table>

        ${footerHtml || ''}
    `;

    document.body.appendChild(printContainer);

    // 5. Ejecutar impresión y limpieza
    setTimeout(() => {
        window.print();
        printContainer.remove();
        document.getElementById('print-style-reporte').remove();
    }, 300);
}

function imprimirReporteIngresos() {
    const prevPrint = document.getElementById('reporte-impresion');
    if (prevPrint) prevPrint.remove();
    const prevPrintStyle = document.getElementById('print-style-reporte');
    if (prevPrintStyle) prevPrintStyle.remove();

    const fechaInicio = document.getElementById('fechaInicio').value || '---';
    const fechaFin = document.getElementById('fechaFin').value || '---';

    // Agrupar los datos
    let regularesCant = 0;
    let regularesCosto = 0;
    let regularesDcto = 0;
    let regularesGanancia = 0;

    let descuentoCant = 0;
    let descuentoCosto = 0;
    let descuentoDcto = 0;
    let descuentoGanancia = 0;

    ultimosRegistrosIngresos.forEach(reg => {
        const costo = Number(reg.totalCostUsd || 0);
        const dcto = Number(reg.discountUsd || 0);
        const ganancia = Number(reg.totalCompanyUsd || 0);
        const concepto = reg.discountUsd > 0 ? "Viaje con descuento" : "Viaje regular";

        if (concepto === "Viaje regular") {
            regularesCant++;
            regularesCosto += costo;
            regularesDcto += dcto;
            regularesGanancia += ganancia;
        } else {
            descuentoCant++;
            descuentoCosto += costo;
            descuentoDcto += dcto;
            descuentoGanancia += ganancia;
        }
    });

    const granTotal = regularesGanancia + descuentoGanancia;
    const fechaActual = new Date().toLocaleDateString('es-VE', { year: 'numeric', month: '2-digit', day: '2-digit' });

    const printStyles = `
        <style id="print-style-reporte">
            @media print {
                body { display: block !important; height: auto !important; min-height: 0 !important; background: white !important; padding: 0 !important; }
                body * { visibility: hidden; }
                #reporte-impresion, #reporte-impresion * { visibility: visible; }
                #reporte-impresion { display: block !important; position: absolute; left: 0; top: 0; width: 100%; margin: 0; padding: 20px; box-sizing: border-box; }

                .print-header { display: flex; justify-content: space-between; align-items: flex-start; border-bottom: 2px solid #1F4E79; padding-bottom: 20px; margin-bottom: 20px; }
                .print-logo { height: 60px; object-fit: contain; }
                .print-company-info { text-align: center; font-size: 14px; }
                .print-doc-info { text-align: right; font-size: 14px; }

                .print-client-info { border: 1px solid #1F4E79; padding: 15px; margin-bottom: 20px; font-size: 14px; }

                .print-table { width: 100%; border-collapse: collapse; margin-top: 20px; font-size: 12px; }
                .print-table th { background-color: #1F4E79 !important; color: white !important; padding: 10px; text-align: center; -webkit-print-color-adjust: exact; print-color-adjust: exact; border: 1px solid #ccc; }
                .print-table td { border: 1px solid #ccc; padding: 10px; text-align: center; }

                .print-footer-totals { display: flex; justify-content: space-between; margin-top: 20px; align-items: flex-start; }
                .print-legal-notes { width: 55%; font-size: 10px; color: #555; text-align: justify; }
                .print-totals-table { width: 40%; border-collapse: collapse; font-size: 14px; font-weight: bold; }
                .print-totals-table td, .print-totals-table th { padding: 8px; border-bottom: 1px solid #ccc; }
                .print-totals-table .total-row { background-color: #1F4E79 !important; color: white !important; -webkit-print-color-adjust: exact; print-color-adjust: exact; }

                .text-right { text-align: right !important; }
                .text-left { text-align: left !important; }

                @page { margin: 1cm; size: auto; }
            }
        </style>
    `;
    document.head.insertAdjacentHTML('beforeend', printStyles);

    const printContainer = document.createElement('div');
    printContainer.id = 'reporte-impresion';
    printContainer.style.display = 'none';

    printContainer.innerHTML = `
        <div class="print-header">
            <div>
                <img src="/img/logo.png" alt="XpressRides Logo" class="print-logo">
            </div>
            <div class="print-company-info">
                <strong>XpressRides, C.A.</strong><br>
                RIF: J-50301732-5<br>
                Domicilio Fiscal: Ciudad Guayana<br>
                Código de Actividad: 9609
            </div>
            <div class="print-doc-info">
                <strong>Reporte de Ingresos (30%)</strong><br>
                Fecha de Emisión: <span>${fechaActual}</span><br>
                Moneda Base: USD ($)
            </div>
        </div>

        <div class="print-client-info">
            Período Evaluado: <span>${fechaInicio} al ${fechaFin}</span><br>
            Total de Viajes: <span>${regularesCant + descuentoCant}</span>
        </div>

        <table class="print-table">
            <thead>
                <tr>
                    <th class="text-left">CONCEPTO</th>
                    <th>CANTIDAD</th>
                    <th>COSTO BRUTO</th>
                    <th>DESCUENTOS</th>
                    <th>GANANCIA EMPRESA</th>
                </tr>
            </thead>
            <tbody>
                <tr>
                    <td class="text-left">Viajes Regulares</td>
                    <td>${regularesCant}</td>
                    <td>$${regularesCosto.toFixed(2)}</td>
                    <td style="color: red;">-$${regularesDcto.toFixed(2)}</td>
                    <td>$${regularesGanancia.toFixed(2)}</td>
                </tr>
                <tr>
                    <td class="text-left">Viajes con Descuento</td>
                    <td>${descuentoCant}</td>
                    <td>$${descuentoCosto.toFixed(2)}</td>
                    <td style="color: red;">-$${descuentoDcto.toFixed(2)}</td>
                    <td>$${descuentoGanancia.toFixed(2)}</td>
                </tr>
            </tbody>
        </table>

        <div class="print-footer-totals">
            <div class="print-legal-notes">
                <p><strong>Nota:</strong> Este reporte es un resumen administrativo de los ingresos obtenidos por la plataforma (comisión del 30%) sobre los viajes completados en el período indicado. Los descuentos aplicados reducen la ganancia neta de la empresa pero no afectan el monto pagado a los choferes.</p>
            </div>
            <table class="print-totals-table">
                <tbody>
                    <tr>
                        <td class="text-left">Costo Bruto Total:</td>
                        <td class="text-right">$${(regularesCosto + descuentoCosto).toFixed(2)}</td>
                    </tr>
                    <tr>
                        <td class="text-left">Descuentos Totales:</td>
                        <td class="text-right">-$${(regularesDcto + descuentoDcto).toFixed(2)}</td>
                    </tr>
                    <tr class="total-row">
                        <td class="text-left" style="color: white !important;">TOTAL GANANCIA:</td>
                        <td class="text-right" style="color: white !important;">$${granTotal.toFixed(2)}</td>
                    </tr>
                </tbody>
            </table>
        </div>
    `;

    document.body.appendChild(printContainer);

    setTimeout(() => {
        window.print();
        printContainer.remove();
        document.getElementById('print-style-reporte').remove();
    }, 300);
}

document.getElementById('btn-imprimir').addEventListener('click', () => {
    imprimirReporteIngresos();
});

document.getElementById('btn-imprimir-cancelados').addEventListener('click', () => {
    imprimirReporte({
        fechaInicioId: 'fechaInicioCancel',
        fechaFinId: 'fechaFinCancel',
        tbodyId: 'tbody-cancelados',
        titulo: 'Traslados Cancelados',
        headers: ['Viaje ID', 'Fecha', 'Cliente', 'Chofer', 'Origen', 'Destino', 'Cancelado por', 'Motivo']
    });
});

document.getElementById('btn-imprimir-historial').addEventListener('click', () => {
    imprimirReporte({
        fechaInicioId: 'fechaInicioHistorial',
        fechaFinId: 'fechaFinHistorial',
        tbodyId: 'tbody-historial',
        titulo: 'Traslados de la Empresa por Período',
        headers: ['Viaje ID', 'Fecha', 'Cliente', 'Chofer', 'Origen', 'Destino', 'Estado', 'Costo Cliente (USD)']
    });
});