// js/cliente-recharge.js
// Formulario de recarga de saldo (transferencia/pago móvil → TopUp)
// Endpoints correctos:
//   GET  /api/tasa-bcv/vigente → tasa BCV del día
//   GET  /api/bancos           → lista de bancos
//   POST /api/recargas         → registrar recarga (TopUp)

let tasaBcvActual = 1.0;
let exchangeRateId = null; // ID de la tasa vigente, necesario para el POST

document.addEventListener('DOMContentLoaded', async () => {
    if (!requireAuth()) return;

    await cargarDatosIniciales();
    configurarFormulario();
});

async function cargarDatosIniciales() {
    try {
        // 1. Obtener Tasa BCV vigente (ExchangeRateController)
        const responseTasa = await fetchAPI('/tasa-bcv/vigente');
        const tasaData = responseTasa.data;
        tasaBcvActual = tasaData.rateVesToUsd || tasaData.tasaVes || tasaData.rateVes || 1;
        exchangeRateId = tasaData.id || null;
        document.getElementById('tasa-bcv-display').innerText = `Bs. ${Number(tasaBcvActual).toFixed(2)}`;

    } catch (error) {
        console.error("Error cargando tasa BCV:", error);
        document.getElementById('tasa-bcv-display').innerText = 'No disponible';
    }

    try {
        // 2. Obtener Bancos disponibles (CatalogController)
        const responseBancos = await fetchAPI('/bancos');
        const selectBanco = document.getElementById('banco');

        selectBanco.innerHTML = '<option value="">Selecciona tu banco...</option>';
        (responseBancos.data || []).forEach(banco => {
            // El modelo Bank usa campo 'name' (inglés)
            selectBanco.add(new Option(banco.name || banco.nombre, banco.id));
        });

    } catch (error) {
        console.error("Error cargando bancos:", error);
    }
}

function configurarFormulario() {
    // A. Evitar que seleccionen fechas futuras
    const fechaInput = document.getElementById('fecha');
    if (fechaInput) {
        const hoy = new Date().toISOString().split('T')[0];
        fechaInput.max = hoy;
    }

    // B. Manejo del toggle entre VES (Bolívares) y USD
    const tipoRecarga = document.getElementById('tipo_recarga');
    const vesFields = document.getElementById('ves-fields');
    const usdFields = document.getElementById('usd-fields');

    // Mostrar campos VES por defecto
    if (tipoRecarga.value === 'ves') {
        vesFields.style.display = 'block';
        usdFields.style.display = 'none';
    }

    tipoRecarga.addEventListener('change', () => {
        if (tipoRecarga.value === 'usd') {
            usdFields.style.display = 'block';
            vesFields.style.display = 'none';
            document.getElementById('banco').required = false;
            document.getElementById('monto_ves').required = false;
            document.getElementById('monto_usd_directo').required = true;
        } else {
            usdFields.style.display = 'none';
            vesFields.style.display = 'block';
            document.getElementById('banco').required = true;
            document.getElementById('monto_ves').required = true;
            document.getElementById('monto_usd_directo').required = false;
        }
    });

    // C. Cálculo dinámico de USD a medida que el cliente escribe en VES
    document.getElementById('monto_ves').addEventListener('input', function(e) {
        const bolivares = parseFloat(e.target.value);
        const usdField = document.getElementById('monto_usd_equivalente');

        if (bolivares > 0 && tasaBcvActual > 0) {
            const dolares = bolivares / tasaBcvActual;
            usdField.value = `$ ${dolares.toFixed(2)}`;
        } else {
            usdField.value = '';
        }
    });

    // D. Capturar y enviar el formulario de recarga
    document.getElementById('form-recarga').addEventListener('submit', async function(e) {
        e.preventDefault();

        // Verificar autenticación
        const usuario = getUsuario();
        if (!usuario) return window.location.href = '../views/login.html';

        const btnSubmit = document.getElementById('btn-submit');
        const alertSuccess = document.getElementById('recharge-success');
        const formRecarga = document.getElementById('form-recarga');

        btnSubmit.innerText = 'Procesando...';
        btnSubmit.disabled = true;

        try {
            let montoVes = 0;
            let montoUsd = 0;
            let bankId = null;

            if (tipoRecarga.value === 'ves') {
                montoVes = parseFloat(document.getElementById('monto_ves').value);
                montoUsd = tasaBcvActual > 0 ? montoVes / tasaBcvActual : 0;
                bankId = parseInt(document.getElementById('banco').value);
            } else {
                montoUsd = parseFloat(document.getElementById('monto_usd_directo').value);
                montoVes = montoUsd * tasaBcvActual;
            }

            // Payload mapeado al modelo TopUp del backend (campos en inglés)
            const payload = {
                customerId: usuario.id,
                bankId: bankId,
                exchangeRateId: exchangeRateId,
                amountUsd: parseFloat(montoUsd.toFixed(2)),
                amountVes: parseFloat(montoVes.toFixed(2)),
                reference: document.getElementById('referencia').value,
                dateTime: document.getElementById('fecha').value + 'T00:00:00',
                paymentCurrency: tipoRecarga.value.toUpperCase() // 'VES' o 'USD'
            };

            // POST /api/recargas → endpoint correcto del backend
            await fetchAPI('/recargas', {
                method: 'POST',
                body: JSON.stringify(payload)
            });

            // Animación de éxito
            formRecarga.style.display = 'none';
            alertSuccess.style.display = 'block';

            // Volver al perfil después de 2.5 segundos
            setTimeout(() => {
                window.location.href = '../views/user-profile.html';
            }, 2500);

        } catch (error) {
            console.error("Error al registrar recarga:", error);
            alert("No se pudo registrar la recarga: " + error.message);
            btnSubmit.innerText = 'Confirmar Recarga';
            btnSubmit.disabled = false;
        }
    });
}