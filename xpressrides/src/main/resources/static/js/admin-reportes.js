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
   MÓDULO: IMPRESIÓN DEL REPORTE
========================================== */
document.getElementById('btn-imprimir').addEventListener('click', () => {
    // 1. Eliminar versiones previas de impresión
    const prevPrint = document.getElementById('reporte-impresion');
    if (prevPrint) prevPrint.remove();
    const prevPrintStyle = document.getElementById('print-style-reporte');
    if (prevPrintStyle) prevPrintStyle.remove();

    // 2. Extraer datos actuales
    const fechaInicio = document.getElementById('fechaInicio').value || '---';
    const fechaFin = document.getElementById('fechaFin').value || '---';
    const tbodyHTML = document.getElementById('tbody-ganancias').innerHTML;
    const totalGanancias = document.getElementById('total-ganancias').innerText;

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
        
        <div class="print-title">Reporte de Ingresos de la Empresa (30%)</div>
        
        <table class="print-table">
            <thead>
                <tr>
                    <th>Viaje ID</th>
                    <th>Fecha</th>
                    <th>Costo Bruto</th>
                    <th>Descuento</th>
                    <th>Ganancia Empresa</th>
                    <th>Concepto</th>
                </tr>
            </thead>
            <tbody>
                ${tbodyHTML}
            </tbody>
        </table>
        
        <div class="print-footer">
            Total Ganancias: ${totalGanancias}
        </div>
    `;

    document.body.appendChild(printContainer);

    // 5. Ejecutar impresión y limpieza
    setTimeout(() => {
        window.print();
        printContainer.remove();
        document.getElementById('print-style-reporte').remove();
    }, 300);
});