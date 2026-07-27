// dashboard-offline.js — Lógica del dashboard del cliente (Modo Offline)
// Usa Leaflet (mapa open-source) + selectores de zonas estáticas
// como fallback para presentaciones sin internet confiable.

document.addEventListener('DOMContentLoaded', async () => {
    if (!requireAuth()) return;

    await cargarZonas();
    configurarFormularioViaje();
    configurarCalculadora();

    // Inicializar mapa Leaflet (no requiere API key)
    inicializarMapaLeaflet();

    // Iniciar el polling para mostrar viajes activos (ej: si fue asignado desde SQL)
    iniciarPollingViajeActivo();
});

function configurarCalculadora() {
    const inputUsd = document.getElementById('conv-usd');
    const spanVes = document.getElementById('conv-ves');
    if (!inputUsd || !spanVes) return;

    let debounceTimer;
    inputUsd.addEventListener('input', (e) => {
        clearTimeout(debounceTimer);
        const monto = parseFloat(e.target.value);
        if (!monto || monto <= 0) {
            spanVes.textContent = 'Bs 0.00';
            return;
        }

        debounceTimer = setTimeout(async () => {
            try {
                const response = await fetchAPI(`/tasa-bcv/convertir?monto=${monto}&moneda=USD`);
                if (response && response.ves) {
                    spanVes.textContent = `Bs ${response.ves.toFixed(2)}`;
                } else if (response && response.data && response.data.ves) {
                    spanVes.textContent = `Bs ${response.data.ves.toFixed(2)}`;
                }
            } catch (err) {
                console.error('Error calculando conversión:', err);
                spanVes.textContent = 'Error';
            }
        }, 500);
    });
}

// ─── Variables globales del módulo ───────────────────────
let mapaLeaflet = null;
let marcadores = [];
let zonasData = [];
let rutaPolyline = null;

/**
 * Carga las zonas activas desde GET /api/zonas
 * y llena los selects de origen y destino.
 */
async function cargarZonas() {
    try {
        const response = await fetchAPI('/zonas');
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
 * Inicializa el mapa Leaflet centrado en Puerto Ordaz / San Félix
 * y coloca marcadores por cada zona.
 */
function inicializarMapaLeaflet() {
    // Centro de Ciudad Guayana (Puerto Ordaz / San Félix)
    const centroGuayana = [8.29, -62.71];

    mapaLeaflet = L.map('map', {
        center: centroGuayana,
        zoom: 12,
        maxBounds: L.latLngBounds([7.95, -63.10], [8.55, -62.20]),
        maxBoundsViscosity: 0.8,
        zoomControl: true,
        attributionControl: true
    });

    // Capa de tiles OpenStreetMap
    L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
        maxZoom: 18,
        attribution: '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a>'
    }).addTo(mapaLeaflet);

    // Agregar marcadores de todas las zonas
    zonasData.forEach(zona => {
        if (zona.latitude && zona.longitude) {
            const marcador = L.marker([zona.latitude, zona.longitude], {
                icon: crearIconoLeaflet('default'),
                title: zona.name
            }).addTo(mapaLeaflet);

            const popupContent = `<b>${zona.name}</b><br>${zona.parish || ''}`;
            marcador.bindPopup(popupContent);

            marcadores.push({ id: zona.id, marker: marcador, content: popupContent });
        }
    });

    // Cuando el usuario selecciona origen o destino, destacamos los marcadores
    document.getElementById('origen').addEventListener('change', resaltarRuta);
    document.getElementById('destino').addEventListener('change', resaltarRuta);

    setTimeout(() => {
        if (mapaLeaflet) mapaLeaflet.invalidateSize();
    }, 100);
    window.addEventListener('resize', () => {
        if (mapaLeaflet) mapaLeaflet.invalidateSize();
    });
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
        m.marker.setIcon(crearIconoLeaflet('default'));
    });

    // Limpiar la ruta previa
    if (rutaPolyline) {
        mapaLeaflet.removeLayer(rutaPolyline);
        rutaPolyline = null;
    }

    // Resaltar origen con ícono verde y centrar
    if (origenId) {
        const origenMarcador = marcadores.find(m => m.id === origenId);
        if (origenMarcador) {
            origenMarcador.marker.setIcon(crearIconoLeaflet('green'));
            origenMarcador.marker.openPopup();
            if (!destinoId) {
                const zona = zonasData.find(z => z.id === origenId);
                if (zona) mapaLeaflet.setView([zona.latitude, zona.longitude], 14);
            }
        }
    }

    // Resaltar destino con ícono rojo y centrar
    if (destinoId) {
        const destinoMarcador = marcadores.find(m => m.id === destinoId);
        if (destinoMarcador) {
            destinoMarcador.marker.setIcon(crearIconoLeaflet('red'));
            if (!origenId) {
                const zona = zonasData.find(z => z.id === destinoId);
                if (zona) mapaLeaflet.setView([zona.latitude, zona.longitude], 14);
            }
        }
    }

    // Si ambos están seleccionados, ajustar el zoom para verlos ambos y dibujar línea
    if (origenId && destinoId) {
        const origenZona = zonasData.find(z => z.id === origenId);
        const destinoZona = zonasData.find(z => z.id === destinoId);
        if (origenZona && destinoZona) {
            const bounds = L.latLngBounds(
                [origenZona.latitude, origenZona.longitude],
                [destinoZona.latitude, destinoZona.longitude]
            );
            mapaLeaflet.fitBounds(bounds.pad(0.3));

            // Dibujar línea simple entre origen y destino
            rutaPolyline = L.polyline(
                [
                    [origenZona.latitude, origenZona.longitude],
                    [destinoZona.latitude, destinoZona.longitude]
                ],
                {
                    color: '#1F4E79',
                    weight: 4,
                    opacity: 0.7,
                    dashArray: '10 6'
                }
            ).addTo(mapaLeaflet);
        }
    }
}

/**
 * Crea un ícono circular coloreado para Leaflet usando L.divIcon.
 */
function crearIconoLeaflet(color) {
    const colores = {
        green: '#1E6B3C',
        red: '#C00000',
        orange: '#C55A11',
        default: '#1F4E79'
    };
    const hex = colores[color] || colores.default;

    return L.divIcon({
        className: '',
        html: `<div style="
            background: ${hex};
            width: 20px;
            height: 20px;
            border-radius: 50%;
            border: 3px solid #FFFFFF;
            box-shadow: 0 2px 6px rgba(0,0,0,0.35);
        "></div>`,
        iconSize: [20, 20],
        iconAnchor: [10, 10],
        popupAnchor: [0, -12]
    });
}

/**
 * Configura el handler del formulario de solicitud de viaje.
 * Llama al endpoint POST /api/traslados/solicitar que invoca el
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

            const responseTarifa = await fetchAPI('/traslados/calcular-tarifa', {
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

    // Construir opciones del selector de cupones
    const cupones = tarifa.cuponesDisponibles || [];
    const cuponesValidos = cupones.filter(c => c.valido);
    const tieneCupones = cuponesValidos.length > 0;

    // Preseleccionar el cupón con mayor descuento
    let mejorCuponIdx = -1;
    let mejorDescuento = 0;
    cuponesValidos.forEach((c, i) => {
        if (c.descuentoUsd > mejorDescuento) {
            mejorDescuento = c.descuentoUsd;
            mejorCuponIdx = i;
        }
    });

    const tipoLabel = (tipo) => {
        switch(tipo) {
            case 'referido': return '🤝 Referido';
            case 'bienvenida': return '👋 Bienvenida';
            case 'promocional': return '🎉 Promoción';
            case 'estudiante': return '🎓 Estudiante';
            default: return '🎫 ' + tipo;
        }
    };

    let cuponSelectorHTML = '';
    if (cupones.length > 0) {
        let optionsHTML = '<option value="">No usar cupón</option>';
        cupones.forEach((c) => {
            const disabled = !c.valido ? 'disabled' : '';
            const label = c.valido
                ? `${tipoLabel(c.tipo)} — ${c.codigo} (-$${Number(c.descuentoUsd).toFixed(2)})`
                : `${tipoLabel(c.tipo)} — ${c.codigo} (${c.motivoInvalido})`;
            const selected = (c.valido && mejorCuponIdx >= 0 && c.idCuponCliente === cuponesValidos[mejorCuponIdx].idCuponCliente) ? 'selected' : '';
            optionsHTML += `<option value="${c.idCuponCliente}" data-usd="${c.costoConCuponUsd}" data-ves="${c.costoConCuponVes}" data-descuento="${c.descuentoUsd}" ${disabled} ${selected}>${label}</option>`;
        });

        cuponSelectorHTML = `
            <div style="background: #eafaf0; border: 2px solid var(--color-success); border-radius: 10px; padding: 12px 14px; margin-bottom: 18px;">
                <div style="font-size:14px; font-weight:600; margin-bottom:8px; color:var(--color-success);">🎫 Cupones de Descuento</div>
                <select id="select-cupon-viaje" style="
                    width:100%; padding:10px 12px; border-radius:8px; border:1px solid #ccc;
                    font-size:14px; font-family:inherit; background:white; cursor:pointer;
                    outline:none; transition: border-color 0.2s;">
                    ${optionsHTML}
                </select>
                <div id="cupon-descuento-detalle" style="margin-top:8px; font-size:13px; color:var(--color-text-muted);"></div>
            </div>
        `;
    }

    // Calcular costos iniciales considerando el mejor cupón preseleccionado
    const costoInicialUsd = (tieneCupones && mejorCuponIdx >= 0)
        ? cuponesValidos[mejorCuponIdx].costoConCuponUsd
        : tarifa.costoFinalUsd;
    const costoInicialVes = (tieneCupones && mejorCuponIdx >= 0)
        ? cuponesValidos[mejorCuponIdx].costoConCuponVes
        : tarifa.costoFinalVes;

    // Construir el modal
    const modalHTML = `
        <div id="modal-tarifa" style="
            position: fixed; inset: 0; z-index: 9999;
            display: flex; align-items: center; justify-content: center;
            background: rgba(0,0,0,0.5);">
            <div style="
                background: white; border-radius: 16px; padding: 24px;
                max-width: 380px; width: 90%; max-height: 90vh; overflow-y: auto;
                box-shadow: 0 20px 60px rgba(0,0,0,0.3);
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
                </table>

                ${cuponSelectorHTML}

                <table style="width:100%; border-collapse:collapse; font-size:14px; margin-bottom: 20px;">
                    <tr style="border-top:2px solid var(--color-primary);">
                        <td style="padding:10px 0; font-weight:700;">Costo Final USD</td>
                        <td style="padding:10px 0; text-align:right; font-weight:700; color:var(--color-primary);">
                            <span id="costo-final-usd">$${Number(costoInicialUsd).toFixed(2)}</span>
                        </td>
                    </tr>
                    <tr>
                        <td style="padding:6px 0; font-weight:600;">Costo Final Bs</td>
                        <td style="padding:6px 0; text-align:right; font-weight:600;">
                            Bs <span id="costo-final-ves">${Number(costoInicialVes).toFixed(2)}</span>
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

    // Selector de cupones — actualiza precios en tiempo real
    const selectCupon = document.getElementById('select-cupon-viaje');
    if (selectCupon) {
        actualizarDetalleCuponOffline(selectCupon, tarifa);

        selectCupon.addEventListener('change', () => {
            actualizarDetalleCuponOffline(selectCupon, tarifa);
            const selected = selectCupon.options[selectCupon.selectedIndex];
            if (selected.value) {
                document.getElementById('costo-final-usd').textContent = '$' + Number(selected.dataset.usd).toFixed(2);
                document.getElementById('costo-final-ves').textContent = Number(selected.dataset.ves).toFixed(2);
            } else {
                document.getElementById('costo-final-usd').textContent = '$' + tarifa.costoFinalUsd.toFixed(2);
                document.getElementById('costo-final-ves').textContent = tarifa.costoFinalVes.toFixed(2);
            }
        });
    }

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
            // Capturar el cupón seleccionado
            const cuponSelect = document.getElementById('select-cupon-viaje');
            const selectedCouponId = cuponSelect ? (cuponSelect.value ? parseInt(cuponSelect.value) : null) : null;

            const payloadViaje = {
                idZoneOrigin: origenId,
                idZoneDestiny: destinoId,
                passengerCount: pasajeros,
                customerCouponId: selectedCouponId
            };

            const response = await fetchAPI('/traslados/solicitar', {
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

function actualizarDetalleCuponOffline(selectEl, tarifa) {
    const detalle = document.getElementById('cupon-descuento-detalle');
    if (!detalle) return;
    const selected = selectEl.options[selectEl.selectedIndex];
    if (selected.value) {
        const descuento = Number(selected.dataset.descuento).toFixed(2);
        detalle.innerHTML = `✅ Descuento de <strong>$${descuento}</strong> aplicado. Pagarás <strong>$${Number(selected.dataset.usd).toFixed(2)}</strong> en vez de $${tarifa.costoFinalUsd.toFixed(2)}.`;
    } else {
        detalle.innerHTML = '';
    }
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
            viajeEstadoPrevio = data.estado;
            mostrarTarjetaViajeActivo(data);
            bloquearFormulario(true);
        } else {
            if (viajeEstadoPrevio) {
                ocultarTarjetaViajeActivo();
                viajeEstadoPrevio = null;
                bloquearFormulario(false);
                mostrarMensajeTemporal('Tu viaje ha finalizado. Puedes ver tu historial.', 'info');
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
        <button onclick="document.getElementById('viaje-activo-card').style.display='none'"
            style="position:absolute; top:10px; right:12px; background:none; border:none;
                   font-size:20px; cursor:pointer; color:#aaa; line-height:1;" title="Minimizar">×</button>
        <h3 style="margin:0 0 10px 0; color:var(--color-primary); font-size:16px;">Viaje en curso: ${estadoFormateado}</h3>
        <p style="margin:4px 0; font-size:14px;"><strong>Origen:</strong> ${data.origen}</p>
        <p style="margin:4px 0; font-size:14px;"><strong>Destino:</strong> ${data.destino}</p>
        ${choferHTML}
        ${tiempoLlegadaHTML}
    `;

    const puedeCancelar = (data.estado === 'solicitado' || data.estado === 'aceptado');

    const btnVerDetalles = document.createElement('a');
    btnVerDetalles.href = '/views/cliente-viaje-activo-offline.html';
    btnVerDetalles.className = 'btn-primary';
    btnVerDetalles.style.cssText = 'display:block; width:100%; margin-top:10px; text-align:center; text-decoration:none; box-sizing:border-box;';
    btnVerDetalles.textContent = 'Ver detalles del viaje';
    card.appendChild(btnVerDetalles);

    if (puedeCancelar) {
        const btnCancelar = document.createElement('button');
        btnCancelar.className = 'btn-secondary';
        btnCancelar.style.cssText = 'width:100%; margin-top:10px; border-color:var(--color-error); color:var(--color-error);';
        btnCancelar.textContent = 'Cancelar Viaje';
        btnCancelar.onclick = async () => {
            if (confirm('¿Estás seguro de que deseas cancelar este viaje?')) {
                btnCancelar.disabled = true;
                btnCancelar.textContent = 'Cancelando...';
                try {
                    await fetchAPI(`/cliente/traslados/${data.idTraslado}/cancelar`, {
                        method: 'PUT',
                        body: JSON.stringify({ motivo: 'Cancelado por el cliente' })
                    });
                    mostrarMensajeTemporal('Viaje cancelado', 'info');
                    ocultarTarjetaViajeActivo();
                    window.location.href = '/views/cliente-record.html';
                } catch (error) {
                    console.error('Error al cancelar viaje:', error);
                    mostrarMensajeTemporal(error.message || 'Error al cancelar', 'error');
                    btnCancelar.disabled = false;
                    btnCancelar.textContent = 'Cancelar Viaje';
                }
            }
        };
        card.appendChild(btnCancelar);
    }
}

function ocultarTarjetaViajeActivo() {
    const card = document.getElementById('viaje-activo-card');
    if (card) card.style.display = 'none';
}

function bloquearFormulario(bloqueado) {
    const btn = document.getElementById('btn-solicitar');
    if (!btn) return;
    btn.disabled = bloqueado;
    btn.textContent = bloqueado ? 'Ya tienes un viaje activo' : 'Solicitar Viaje';
}
