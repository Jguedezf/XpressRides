// dashboard.js — Lógica del dashboard del cliente
// Carga las zonas para el formulario de solicitud de viaje
// e inicializa el mapa Leaflet centrado en Ciudad Guayana.

document.addEventListener('DOMContentLoaded', async () => {
    if (!requireAuth()) return;

    await cargarZonas();
    inicializarMapa();
    configurarFormularioViaje();
});

// ─── Variables globales del módulo ───────────────────────
let mapaLeaflet = null;
let marcadores = [];
let zonasData = [];

/**
 * Carga las zonas activas desde GET /api/zonas
 * y llena los selects de origen y destino.
 */
async function cargarZonas() {
    try {
        const response = await fetchAPI('../zonas');
        zonasData = response.data || [];

        const selectOrigen = document.getElementById('origen');
        const selectDestino = document.getElementById('destino');

        selectOrigen.innerHTML = '<option value="" disabled selected>Selecciona un punto de origen</option>';
        selectDestino.innerHTML = '<option value="" disabled selected>Selecciona un punto de destino</option>';

        zonasData.forEach(zona => {
            // Los campos del modelo Java Zone usan nombres en inglés
            selectOrigen.add(new Option(zona.name, zona.id));
            selectDestino.add(new Option(zona.name, zona.id));
        });

    } catch (error) {
        console.error('Error cargando zonas:', error);
        const selectOrigen = document.getElementById('origen');
        if (selectOrigen) {
            selectOrigen.innerHTML = '<option value="">Error al cargar zonas</option>';
        }
    }
}

/**
 * Inicializa el mapa Leaflet centrado en Ciudad Guayana
 * y coloca marcadores por cada zona.
 */
function inicializarMapa() {
    // Centro de Ciudad Guayana (Puerto Ordaz / San Félix)
    mapaLeaflet = L.map('map').setView([8.3535, -62.6328], 12);

    // Tiles de OpenStreetMap
    L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
        attribution: '© OpenStreetMap contributors',
        maxZoom: 18
    }).addTo(mapaLeaflet);

    // Agregar marcadores de todas las zonas
    zonasData.forEach(zona => {
        if (zona.latitude && zona.longitude) {
            const marcador = L.marker([zona.latitude, zona.longitude])
                .addTo(mapaLeaflet)
                .bindPopup(`<b>${zona.name}</b><br>${zona.parish || ''}`);
            marcadores.push({ id: zona.id, marker: marcador });
        }
    });

    // Cuando el usuario selecciona origen o destino, destacamos los marcadores
    document.getElementById('origen').addEventListener('change', resaltarRuta);
    document.getElementById('destino').addEventListener('change', resaltarRuta);
}

/**
 * Resalta los marcadores de origen (verde) y destino (rojo)
 * cuando el usuario selecciona zonas en los selects.
 */
function resaltarRuta() {
    const origenId = parseInt(document.getElementById('origen').value);
    const destinoId = parseInt(document.getElementById('destino').value);

    // Restaurar todos los marcadores al icono por defecto
    marcadores.forEach(m => {
        m.marker.setIcon(L.icon({
            iconUrl: 'https://unpkg.com/leaflet@1.9.4/dist/images/marker-icon.png',
            iconSize: [25, 41],
            iconAnchor: [12, 41],
            popupAnchor: [1, -34],
            shadowUrl: 'https://unpkg.com/leaflet@1.9.4/dist/images/marker-shadow.png',
            shadowSize: [41, 41]
        }));
    });

    // Resaltar origen con ícono verde
    if (origenId) {
        const origenMarcador = marcadores.find(m => m.id === origenId);
        if (origenMarcador) {
            origenMarcador.marker.setIcon(crearIconoColor('green'));
            origenMarcador.marker.openPopup();
        }
    }

    // Resaltar destino con ícono rojo
    if (destinoId) {
        const destinoMarcador = marcadores.find(m => m.id === destinoId);
        if (destinoMarcador) {
            destinoMarcador.marker.setIcon(crearIconoColor('red'));
        }
    }

    // Si ambos están seleccionados, ajustar el zoom para verlos ambos
    if (origenId && destinoId) {
        const origenZona = zonasData.find(z => z.id === origenId);
        const destinoZona = zonasData.find(z => z.id === destinoId);
        if (origenZona && destinoZona) {
            const bounds = L.latLngBounds(
                [origenZona.latitude, origenZona.longitude],
                [destinoZona.latitude, destinoZona.longitude]
            );
            mapaLeaflet.fitBounds(bounds, { padding: [60, 60] });
        }
    }
}

/**
 * Crea un ícono de Leaflet con un color específico usando un div personalizado.
 */
function crearIconoColor(color) {
    const colores = {
        green: '#1E6B3C',
        red: '#C00000',
        orange: '#C55A11'
    };

    return L.divIcon({
        html: `<div style="
            background-color: ${colores[color] || color};
            width: 24px; height: 24px;
            border-radius: 50%;
            border: 3px solid white;
            box-shadow: 0 2px 6px rgba(0,0,0,0.35);
        "></div>`,
        iconSize: [24, 24],
        iconAnchor: [12, 12],
        popupAnchor: [0, -14],
        className: '' // Evitar clases por defecto de Leaflet
    });
}

/**
 * Configura el handler del formulario de solicitud de viaje.
 * Llama al endpoint POST /api/solicitar-viaje que invoca el
 * Stored Procedure sp_solicitar_traslado en MySQL.
 */
function configurarFormularioViaje() {
    const form = document.getElementById('form-solicitar-viaje');
    if (!form) return;

    form.addEventListener('submit', async (e) => {
        e.preventDefault();

        const origen = document.getElementById('origen').value;
        const destino = document.getElementById('destino').value;
        const pasajeros = parseInt(document.getElementById('pasajeros').value) || 1;

        if (!origen || !destino) {
            mostrarMensajeTemporal('Selecciona un punto de origen y destino.', 'warning');
            return;
        }

        if (origen === destino) {
            mostrarMensajeTemporal('El origen y destino no pueden ser iguales.', 'warning');
            return;
        }

        // Obtener usuario autenticado
        const usuario = getUsuario();
        if (!usuario) {
            window.location.href = '../views/login.html';
            return;
        }

        // Fase 1: Calcular tarifa
        const btnSolicitar = document.getElementById('btn-solicitar');
        const textoOriginal = btnSolicitar.textContent;
        btnSolicitar.disabled = true;
        btnSolicitar.textContent = 'Calculando tarifa...';

        try {
            const payloadTarifa = {
                idZoneOrigin: parseInt(origen),
                idZoneDestiny: parseInt(destino),
                passengerCount: pasajeros
            };

            const responseTarifa = await fetchAPI('../traslados/calcular-tarifa', {
                method: 'POST',
                body: JSON.stringify(payloadTarifa)
            });

            const tarifa = responseTarifa.data;

            // Mostrar el modal de confirmación
            mostrarPreviewTarifa(tarifa, parseInt(origen), parseInt(destino), pasajeros, textoOriginal, btnSolicitar, form);
            
        } catch (error) {
            console.error('Error calculando tarifa:', error);
            mostrarMensajeTemporal(
                error.message || 'No se pudo calcular la tarifa. Intenta de nuevo.',
                'error'
            );
            btnSolicitar.disabled = false;
            btnSolicitar.textContent = textoOriginal;
        }
    });
}

function mostrarPreviewTarifa(tarifa, origenId, destinoId, pasajeros, textoOriginalBtn, btnSolicitar, form) {
    const origenNombre = document.getElementById('origen').options[document.getElementById('origen').selectedIndex].text;
    const destinoNombre = document.getElementById('destino').options[document.getElementById('destino').selectedIndex].text;

    // Construir el modal
    const modalHTML = `
        <div id="modal-tarifa" style="
            position: fixed; inset: 0; z-index: 9999;
            display: flex; align-items: center; justify-content: center;
            background: rgba(0,0,0,0.5);">
            <div style="
                background: #fff; border-radius: 12px; padding: 28px 32px;
                max-width: 480px; width: 90%; box-shadow: 0 8px 30px rgba(0,0,0,0.25);
                position: relative; font-family: inherit;">
                
                <h3 style="margin:0 0 16px 0; color: var(--color-primary);">Confirmar Viaje</h3>
                
                <div style="margin-bottom: 16px; font-size: 14px;">
                    <p style="margin: 4px 0;"><strong>Origen:</strong> ${origenNombre}</p>
                    <p style="margin: 4px 0;"><strong>Destino:</strong> ${destinoNombre}</p>
                    <p style="margin: 4px 0;"><strong>Pasajeros:</strong> ${pasajeros}</p>
                </div>

                <table style="width:100%; border-collapse:collapse; font-size:14px; margin-bottom: 20px;">
                    <tr>
                        <td style="padding:6px 0; color:var(--color-text-muted);">Tarifa Base</td>
                        <td style="padding:6px 0; text-align:right;">$${tarifa.tarifaBase.toFixed(2)}</td>
                    </tr>
                    ${tarifa.costoDistancia > 0 ? `
                    <tr>
                        <td style="padding:6px 0; color:var(--color-text-muted);">Distancia (${tarifa.distanciaKm} km)</td>
                        <td style="padding:6px 0; text-align:right;">$${tarifa.costoDistancia.toFixed(2)}</td>
                    </tr>` : ''}
                    ${tarifa.recargoHoraPico > 0 ? `
                    <tr>
                        <td style="padding:6px 0; color:var(--color-text-muted);">Hora Pico</td>
                        <td style="padding:6px 0; text-align:right;">+$${tarifa.recargoHoraPico.toFixed(2)}</td>
                    </tr>` : ''}
                    ${tarifa.recargoNocturnoFinSemana > 0 ? `
                    <tr>
                        <td style="padding:6px 0; color:var(--color-text-muted);">Nocturno/FDS</td>
                        <td style="padding:6px 0; text-align:right;">+$${tarifa.recargoNocturnoFinSemana.toFixed(2)}</td>
                    </tr>` : ''}
                    ${tarifa.descuentoAplicado > 0 ? `
                    <tr>
                        <td style="padding:6px 0; color:var(--color-success); font-weight:bold;">
                            Descuento ${tarifa.primerViajeGratis ? '(1er Viaje)' : (tarifa.descuentoEstudiantil ? '(Estudiante)' : '')}
                        </td>
                        <td style="padding:6px 0; text-align:right; color:var(--color-success); font-weight:bold;">
                            -$${tarifa.descuentoAplicado.toFixed(2)}
                        </td>
                    </tr>` : ''}
                    <tr style="border-top:2px solid var(--color-primary);">
                        <td style="padding:10px 0; font-weight:700;">Costo Final USD</td>
                        <td style="padding:10px 0; text-align:right; font-weight:700; color:var(--color-primary);">
                            $${tarifa.costoFinalUsd.toFixed(2)}
                        </td>
                    </tr>
                    <tr>
                        <td style="padding:6px 0; font-weight:600;">Costo Final Bs</td>
                        <td style="padding:6px 0; text-align:right; font-weight:600;">
                            Bs ${tarifa.costoFinalVes.toFixed(2)}
                        </td>
                    </tr>
                </table>

                <div style="display: flex; gap: 10px;">
                    <button id="btn-cancelar-viaje" class="btn-secondary" style="flex:1;">Cancelar</button>
                    <button id="btn-confirmar-viaje" class="btn-primary" style="flex:1;">Confirmar y Solicitar</button>
                </div>
            </div>
        </div>
    `;

    document.body.insertAdjacentHTML('beforeend', modalHTML);

    const modal = document.getElementById('modal-tarifa');
    
    document.getElementById('btn-cancelar-viaje').addEventListener('click', () => {
        modal.remove();
        btnSolicitar.disabled = false;
        btnSolicitar.textContent = textoOriginalBtn;
    });

    document.getElementById('btn-confirmar-viaje').addEventListener('click', async () => {
        const btnConfirmar = document.getElementById('btn-confirmar-viaje');
        btnConfirmar.disabled = true;
        btnConfirmar.textContent = 'Solicitando...';
        
        try {
            const payloadViaje = {
                idZoneOrigin: origenId,
                idZoneDestiny: destinoId,
                passengerCount: pasajeros,
                customerCouponId: null
            };

            const response = await fetchAPI('../traslado/solicitar', {
                method: 'POST',
                body: JSON.stringify(payloadViaje)
            });

            const data = response.data || {};
            let mensaje = '🚗 ¡Viaje solicitado exitosamente!';
            if (data.choferNombre) {
                mensaje += ` Tu chofer ${data.choferNombre} va en camino.`;
            }

            mostrarMensajeTemporal(mensaje, 'info');

            // Resetear
            form.reset();
            document.getElementById('origen').selectedIndex = 0;
            document.getElementById('destino').selectedIndex = 0;
            resaltarRuta();
            
        } catch (error) {
            console.error('Error solicitando viaje:', error);
            
            let errMsg = error.message || 'No se pudo solicitar el viaje. Intenta de nuevo.';
            if (errMsg.includes('viaje activo en curso')) {
                errMsg = '⚠️ Ya tienes un viaje activo en curso. Por favor, finalízalo antes de solicitar otro.';
            }
            // Limpiar "ERROR: " del mensaje si viene del backend
            errMsg = errMsg.replace(/^ERROR:\s*/i, '');

            mostrarMensajeTemporal(errMsg, 'error');
        } finally {
            modal.remove();
            btnSolicitar.disabled = false;
            btnSolicitar.textContent = textoOriginalBtn;
        }
    });
}

/**
 * Muestra un mensaje temporal estilizado sobre la tarjeta flotante.
 * Se auto-oculta después de 4 segundos.
 */
function mostrarMensajeTemporal(texto, tipo) {
    // Remover mensajes anteriores
    const previo = document.getElementById('msg-temporal');
    if (previo) previo.remove();

    const colores = {
        info: { bg: '#E8F4FD', border: '#1F4E79', text: '#1F4E79' },
        warning: { bg: '#FFF3E0', border: '#C55A11', text: '#C55A11' },
        error: { bg: '#FDEDED', border: '#C00000', text: '#C00000' }
    };
    const c = colores[tipo] || colores.info;

    const div = document.createElement('div');
    div.id = 'msg-temporal';
    div.style.cssText = `
        position: fixed; top: 70px; left: 50%; transform: translateX(-50%);
        z-index: 2000; padding: 12px 20px; border-radius: 8px;
        background: ${c.bg}; border: 1px solid ${c.border}; color: ${c.text};
        font-size: 14px; font-weight: 600; box-shadow: 0 4px 12px rgba(0,0,0,0.15);
        animation: slideDown 0.3s ease-out; max-width: 90%;
    `;
    div.textContent = texto;
    document.body.appendChild(div);

    setTimeout(() => {
        div.style.transition = 'opacity 0.3s ease';
        div.style.opacity = '0';
        setTimeout(() => div.remove(), 300);
    }, 4000);
}

// ─── Polling de Viaje Activo ───────────────────────────────
let viajeActivoInterval = null;
let viajeEstadoPrevio = null;

function iniciarPollingViajeActivo() {
    // Primera llamada inmediata
    consultarViajeActivo();
    
    // Polling cada 5 segundos
    viajeActivoInterval = setInterval(consultarViajeActivo, 5000);
}

async function consultarViajeActivo() {
    try {
        const response = await fetchAPI('/cliente/viaje-activo');
        const data = response.data;

        if (data) {
            viajeEstadoPrevio = data;
            mostrarTarjetaViajeActivo(data);
        } else {
            // Si data es null pero antes teníamos un viaje activo, significa que finalizó (completado/cancelado)
            if (viajeEstadoPrevio) {
                ocultarTarjetaViajeActivo();
                window.location.href = '/views/cliente-record.html';
            } else {
                ocultarTarjetaViajeActivo();
            }
        }
    } catch (error) {
        console.error('Error al consultar viaje activo:', error);
    }
}

function mostrarTarjetaViajeActivo(data) {
    let card = document.getElementById('viaje-activo-card');
    if (!card) {
        card = document.createElement('div');
        card.id = 'viaje-activo-card';
        card.style.cssText = `
            position: fixed; bottom: 20px; right: 20px; z-index: 2000;
            background: #fff; border-radius: 12px; padding: 20px;
            box-shadow: 0 8px 30px rgba(0,0,0,0.15); width: 320px;
            border-left: 5px solid var(--color-primary);
        `;
        document.body.appendChild(card);
    }

    card.style.display = 'block';
    
    const estadoFormateado = data.estado.replace('_', ' ').toUpperCase();
    const tiempoLlegadaHTML = data.tiempoEstimadoLlegadaMinutos 
        ? `<p style="margin:8px 0 0 0; font-size:14px; font-weight:bold; color:var(--color-accent);">Llegada en ~${data.tiempoEstimadoLlegadaMinutos} min</p>` 
        : '';
        
    const choferHTML = data.chofer ? `
        <hr style="border:0; border-top:1px solid #eee; margin:10px 0;">
        <p style="margin:4px 0; font-size:14px;"><strong>Chofer:</strong> ${data.chofer.nombre}</p>
        <p style="margin:4px 0; font-size:14px;"><strong>Vehículo:</strong> ${data.chofer.vehiculo} (${data.chofer.color})</p>
        <p style="margin:4px 0; font-size:14px;"><strong>Placa:</strong> ${data.chofer.placa}</p>
    ` : '';

    card.innerHTML = `
        <h3 style="margin:0 0 10px 0; color:var(--color-primary); font-size:16px;">Viaje en curso: ${estadoFormateado}</h3>
        <p style="margin:4px 0; font-size:14px;"><strong>Origen:</strong> ${data.origen}</p>
        <p style="margin:4px 0; font-size:14px;"><strong>Destino:</strong> ${data.destino}</p>
        ${choferHTML}
        ${tiempoLlegadaHTML}
    `;
}

function ocultarTarjetaViajeActivo() {
    const card = document.getElementById('viaje-activo-card');
    if (card) card.style.display = 'none';
}