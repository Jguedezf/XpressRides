// Función central que busca los datos y abre el modal
async function cargarYMostrarFactura(trasladoId) {
    const btn = document.getElementById('btn-ver-factura');
    const errorBox = document.getElementById('error-factura');
    const originalText = btn.innerText;

    // Feedback visual
    btn.innerText = 'Consultando al SENIAT...';
    btn.disabled = true;
    errorBox.style.display = 'none';

    try {
        // 1. Validar sesión
        if (!requireAuth()) return;

        // 2. Consumimos el endpoint oficial
        const response = await fetchAPI(`/facturas/${trasladoId}`);
        const factura = response.data; // Aquí viene el objeto con todos los datos

        if (!factura) {
            throw new Error("No se encontraron datos fiscales para este viaje.");
        }

        // 3. Inyectamos los datos reales en el HTML del Modal Visual
        document.getElementById('fact-nro').innerText = factura.numeroDocumento;
        document.getElementById('fact-fecha').innerText = factura.fechaEmision + " " + factura.horaEmision;
        document.getElementById('fact-tasa').innerText = factura.tasaVes.toFixed(2);

        document.getElementById('fact-control').innerText = factura.control;
        document.getElementById('fact-serie').innerText = factura.serie;

        document.getElementById('fact-cliente').innerText = factura.clienteNombre;
        document.getElementById('fact-cedula').innerText = factura.clienteCedula;
        document.getElementById('fact-dir').innerText = factura.clienteDireccion;

        // Finanzas Modal Visual
        document.getElementById('fact-costo').innerText = factura.costoUsd.toFixed(2);
        document.getElementById('fact-subtotal').innerText = factura.costoUsd.toFixed(2);
        document.getElementById('fact-igtf').innerText = factura.montoIgtfUsd.toFixed(2);

        // Totales Modal Visual
        document.getElementById('fact-total-usd').innerText = factura.totalUsd.toFixed(2);
        document.getElementById('fact-total-ves').innerText = factura.totalVes.toLocaleString('es-VE', {minimumFractionDigits: 2});

        // -------------------------------------------------------------
        // 3.1. Inyectamos los datos en la Plantilla de Impresión Fiscal
        // -------------------------------------------------------------
        document.getElementById('print-fact-nro').innerText = factura.numeroDocumento;
        document.getElementById('print-fact-serie').innerText = factura.serie;
        document.getElementById('print-fact-fecha').innerText = factura.fechaEmision;
        document.getElementById('print-fact-control').innerText = factura.control;
        document.getElementById('print-fact-tasa').innerText = factura.tasaVes.toLocaleString('es-VE', {minimumFractionDigits: 4});
        
        document.getElementById('print-fact-cliente').innerText = factura.clienteNombre;
        document.getElementById('print-fact-cedula').innerText = factura.clienteCedula;
        document.getElementById('print-fact-dir').innerText = factura.clienteDireccion;

        // Montos e Items
        document.getElementById('print-fact-punit').innerText = factura.costoUsd.toFixed(2);
        document.getElementById('print-fact-monto').innerText = factura.costoUsd.toFixed(2);

        // Cálculos Bs
        const baseBs = factura.costoUsd * factura.tasaVes;
        const igtfBs = factura.montoIgtfUsd * factura.tasaVes;

        document.getElementById('print-fact-base-usd').innerText = factura.costoUsd.toFixed(2);
        document.getElementById('print-fact-base-bs').innerText = baseBs.toLocaleString('es-VE', {minimumFractionDigits: 2});
        
        document.getElementById('print-fact-sub-usd').innerText = factura.costoUsd.toFixed(2);
        document.getElementById('print-fact-sub-bs').innerText = baseBs.toLocaleString('es-VE', {minimumFractionDigits: 2});

        document.getElementById('print-fact-igtf-usd').innerText = factura.montoIgtfUsd.toFixed(2);
        document.getElementById('print-fact-igtf-bs').innerText = igtfBs.toLocaleString('es-VE', {minimumFractionDigits: 2});

        document.getElementById('print-fact-total-usd').innerText = factura.totalUsd.toFixed(2);
        document.getElementById('print-fact-total-bs').innerText = factura.totalVes.toLocaleString('es-VE', {minimumFractionDigits: 2});

        // 4. Abrimos el modal
        document.getElementById('modalFactura').style.display = 'flex';

    } catch (error) {
        // Manejo de errores estándar de la Guía
        console.error("Error cargando factura:", error);
        errorBox.innerText = `Error fiscal: ${error.message}`;
        errorBox.style.display = 'block';
    } finally {
        // Restaurar el botón
        btn.innerText = originalText;
        btn.disabled = false;
    }
}

function imprimirFactura() {
    window.print();
}

function cerrarFactura() {
    document.getElementById('modalFactura').style.display = 'none';
}