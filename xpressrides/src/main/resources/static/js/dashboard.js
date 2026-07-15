// dashboard.js — Lógica del dashboard del cliente
// Usa Google Maps y Places Autocomplete para seleccionar origen y destino libre.

let mapaGoogle = null;
let originMarker = null;
let destinationMarker = null;
let directionsService = null;
let directionsRenderer = null;
let originPlace = null;
let destinationPlace = null;
let origenAutocomplete = null;
let destinoAutocomplete = null;

document.addEventListener('DOMContentLoaded', async () => {
    if (!requireAuth()) return;
    configurarCalculadora();

    try {
        await cargarGoogleMaps();
        inicializarMapa();
        configurarFormularioViaje();
    } catch (error) {
        console.error("No se pudo cargar Google Maps:", error);
    }
    
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
                const response = await fetchAPI('/tasa-bcv/convertir?monto=' + monto + '&moneda=USD');
                if (response && response.ves) {
                    spanVes.textContent = 'Bs ' + response.ves.toFixed(2);
                } else if (response && response.data && response.data.ves) {
                    spanVes.textContent = 'Bs ' + response.data.ves.toFixed(2);
                }
            } catch (err) {
                console.error('Error calculando conversión:', err);
                spanVes.textContent = 'Error';
            }
        }, 500);
    });
}

function inicializarMapa() {
    const centroGuayana = { lat: 8.29, lng: -62.71 };

    mapaGoogle = new google.maps.Map(document.getElementById('map'), {
        center: centroGuayana,
        zoom: 12,
        mapTypeControl: true,
        streetViewControl: true,
        fullscreenControl: true,
        restriction: {
            latLngBounds: {
                north: 8.55,
                south: 7.95,
                east: -62.20,
                west: -63.10
            },
            strictBounds: false
        },
        styles: [
            { featureType: 'poi', stylers: [{ visibility: 'simplified' }] }
        ]
    });

    directionsService = new google.maps.DirectionsService();
    directionsRenderer = new google.maps.DirectionsRenderer({
        map: mapaGoogle,
        suppressMarkers: true,
        polylineOptions: {
            strokeColor: '#1F4E79',
            strokeOpacity: 0.7,
            strokeWeight: 4
        }
    });

    const geocoder = new google.maps.Geocoder();
    const infoWindow = new google.maps.InfoWindow();

    const placesService = new google.maps.places.PlacesService(mapaGoogle);

    mapaGoogle.addListener('click', (e) => {
        const modeEl = document.querySelector('input[name="map_click_mode"]:checked');
        const mode = modeEl ? modeEl.value : 'info';
        
        // En caso de que se haga click en un POI
        if (e.placeId) {
            // Si estamos en modo origen o destino, prevenimos que se abra el infowindow por defecto
            // Si estamos en info, queremos que se abra el default de Google (como el chofer)
            if (mode !== 'info') {
                e.stop(); 
            } else {
                // Dejamos que Google Maps haga lo suyo
                return;
            }
        }

        const clickedLat = e.latLng.lat();
        const clickedLng = e.latLng.lng();

        const handleLocationSelection = (direccion, latLng) => {
            if (mode === 'info') {
                infoWindow.setContent(`
                    <div style="padding: 8px; color: #333; font-family: 'Inter', sans-serif;">
                        <h4 style="margin: 0 0 4px 0; color: #1F4E79; font-size: 14px;">Ubicación seleccionada</h4>
                        <p style="margin: 0 0 8px 0; font-size: 12px;">${direccion}</p>
                    </div>
                `);
                infoWindow.setPosition(latLng);
                infoWindow.open(mapaGoogle);
            } else {
                const place = {
                    geometry: { location: latLng },
                    name: direccion
                };
                
                if (mode === 'origen') {
                    originPlace = place;
                    document.getElementById('origen').value = direccion;
                } else {
                    destinationPlace = place;
                    document.getElementById('destino').value = direccion;
                }
                actualizarMarcadoresYRuta();
            }
        };

        if (e.placeId) {
            placesService.getDetails({ placeId: e.placeId, fields: ['name', 'geometry', 'formatted_address'] }, (placeResult, status) => {
                if (status === google.maps.places.PlacesServiceStatus.OK && placeResult.geometry) {
                    const placeName = placeResult.name || placeResult.formatted_address;
                    handleLocationSelection(placeName, placeResult.geometry.location);
                } else {
                    fallbackGeocoder();
                }
            });
        } else {
            fallbackGeocoder();
        }

        function fallbackGeocoder() {
            geocoder.geocode({ location: e.latLng }, (results, status) => {
                const direccion = (status === 'OK' && results[0])
                    ? results[0].formatted_address
                    : `${clickedLat.toFixed(5)}, ${clickedLng.toFixed(5)}`;
                handleLocationSelection(direccion, e.latLng);
            });
        }
    });
}

function configurarFormularioViaje() {
    const inputOrigen = document.getElementById('origen');
    const inputDestino = document.getElementById('destino');
    const inputUsd = document.getElementById('conv-usd');
    
    // Evitar que el navegador auto-complete con "null" de sesiones anteriores rotas
    if (inputOrigen.value === 'null') inputOrigen.value = '';
    if (inputDestino.value === 'null') inputDestino.value = '';
    if (inputUsd && inputUsd.value === 'null') inputUsd.value = '';

    // Configurar Autocomplete para Puerto Ordaz / San Félix
    const guayanaBounds = new google.maps.LatLngBounds(
        new google.maps.LatLng(7.95, -63.10),
        new google.maps.LatLng(8.55, -62.20)
    );

    const autocompleteOptions = {
        bounds: guayanaBounds,
        strictBounds: true,
        fields: ["geometry", "name", "formatted_address"],
        componentRestrictions: { country: "VE" }
    };

    origenAutocomplete = new google.maps.places.Autocomplete(inputOrigen, autocompleteOptions);
    destinoAutocomplete = new google.maps.places.Autocomplete(inputDestino, autocompleteOptions);

    origenAutocomplete.addListener("place_changed", () => {
        const place = origenAutocomplete.getPlace();
        if (!place.geometry || !place.geometry.location) {
            originPlace = null;
            if(originMarker) originMarker.setMap(null);
            originMarker = null;
            inputOrigen.value = "";
            return;
        }
        originPlace = place;
        inputOrigen.value = place.name;
        actualizarMarcadoresYRuta();
    });

    destinoAutocomplete.addListener("place_changed", () => {
        const place = destinoAutocomplete.getPlace();
        if (!place.geometry || !place.geometry.location) {
            destinationPlace = null;
            if(destinationMarker) destinationMarker.setMap(null);
            destinationMarker = null;
            inputDestino.value = "";
            return;
        }
        destinationPlace = place;
        inputDestino.value = place.name;
        actualizarMarcadoresYRuta();
    });

    const form = document.getElementById('form-solicitar-viaje');
    form.addEventListener('submit', async (e) => {
        e.preventDefault();

        const pasajeros = parseInt(document.getElementById('pasajeros').value);
        if (!originPlace || !destinationPlace) {
            mostrarMensajeTemporal('Debe seleccionar origen y destino de la lista.', 'error');
            return;
        }

        const usuario = JSON.parse(localStorage.getItem('xpressUsuario'));
        if (!usuario) {
            window.location.href = '../views/login.html';
            return;
        }

        const btnSolicitar = document.getElementById('btn-solicitar');
        const textoOriginal = btnSolicitar.textContent;
        btnSolicitar.disabled = true;
        btnSolicitar.textContent = 'Calculando tarifa...';

        try {
            const payloadTarifa = {
                originLat: originPlace.geometry.location.lat(),
                originLng: originPlace.geometry.location.lng(),
                destinationLat: destinationPlace.geometry.location.lat(),
                destinationLng: destinationPlace.geometry.location.lng(),
                origenStr: inputOrigen.value,
                destinoStr: inputDestino.value,
                passengerCount: pasajeros
            };

            const responseTarifa = await fetchAPI('/traslados/calcular-tarifa', {
                method: 'POST',
                body: JSON.stringify(payloadTarifa)
            });

            const tarifa = responseTarifa.data;
            mostrarPreviewTarifa(tarifa, inputOrigen.value, inputDestino.value, pasajeros, payloadTarifa, textoOriginal, btnSolicitar);
        } catch (error) {
            console.error('Error calculando tarifa:', error);
            mostrarMensajeTemporal(error.message || 'No se pudo calcular la tarifa.', 'error');
            btnSolicitar.disabled = false;
            btnSolicitar.textContent = textoOriginal;
        }
    });
}

function actualizarMarcadoresYRuta() {
    if (directionsRenderer) directionsRenderer.set('directions', null);

    if (originPlace && originPlace.geometry) {
        if (!originMarker) {
            originMarker = new google.maps.Marker({
                map: mapaGoogle,
                title: 'Origen',
                icon: {
                    path: google.maps.SymbolPath.CIRCLE,
                    fillColor: '#4CAF50',
                    fillOpacity: 1,
                    strokeColor: '#FFFFFF',
                    strokeWeight: 2,
                    scale: 8
                }
            });
        }
        originMarker.setPosition(originPlace.geometry.location);
        mapaGoogle.setCenter(originPlace.geometry.location);
    } else if (originMarker) {
        originMarker.setMap(null);
        originMarker = null;
    }

    if (destinationPlace && destinationPlace.geometry) {
        if (!destinationMarker) {
            destinationMarker = new google.maps.Marker({
                map: mapaGoogle,
                title: 'Destino',
                icon: {
                    path: google.maps.SymbolPath.CIRCLE,
                    fillColor: '#F44336',
                    fillOpacity: 1,
                    strokeColor: '#FFFFFF',
                    strokeWeight: 2,
                    scale: 8
                }
            });
        }
        destinationMarker.setPosition(destinationPlace.geometry.location);
    } else if (destinationMarker) {
        destinationMarker.setMap(null);
        destinationMarker = null;
    }

    if (originPlace && destinationPlace) {
        const bounds = new google.maps.LatLngBounds();
        bounds.extend(originPlace.geometry.location);
        bounds.extend(destinationPlace.geometry.location);
        mapaGoogle.fitBounds(bounds, { top: 60, bottom: 60, left: 60, right: 60 });

        directionsService.route({
            origin: originPlace.geometry.location,
            destination: destinationPlace.geometry.location,
            travelMode: google.maps.TravelMode.DRIVING
        }, (result, status) => {
            if (status === google.maps.DirectionsStatus.OK) {
                directionsRenderer.setDirections(result);
            }
        });
    }
}

function mostrarPreviewTarifa(tarifa, origenNombre, destinoNombre, pasajeros, payloadTarifa, textoOriginalBtn, btnSolicitar) {
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
                </table>

                ${tarifa.cuponReferidoDisponible ? `
                <div id="oferta-cupon-referido" style="
                    background: #eafaf0; border: 2px solid var(--color-success);
                    border-radius: 10px; padding: 12px 14px; margin-bottom: 18px;">
                    <label style="display:flex; align-items:flex-start; gap:10px; cursor:pointer; font-size:14px;">
                        <input type="checkbox" id="chk-cupon-referido" checked style="margin-top:3px;">
                        <span>
                            🎁 <strong>Tienes un cupón de referido de $${tarifa.descuentoCuponReferido.toFixed(2)} de descuento.</strong>
                            Con el cupón pagarías <strong>$${tarifa.costoConCuponUsd.toFixed(2)}</strong> en vez de $${tarifa.costoFinalUsd.toFixed(2)}.
                            Desmarca para no usarlo en este viaje.
                        </span>
                    </label>
                </div>` : ''}

                <table style="width:100%; border-collapse:collapse; font-size:14px; margin-bottom: 20px;">
                    <tr style="border-top:2px solid var(--color-primary);">
                        <td style="padding:10px 0; font-weight:700;">Costo Final USD</td>
                        <td style="padding:10px 0; text-align:right; font-weight:700; color:var(--color-primary);">
                            <span id="costo-final-usd">$${(tarifa.cuponReferidoDisponible ? tarifa.costoConCuponUsd : tarifa.costoFinalUsd).toFixed(2)}</span>
                        </td>
                    </tr>
                    <tr>
                        <td style="padding:6px 0; font-weight:600;">Costo Final Bs</td>
                        <td style="padding:6px 0; text-align:right; font-weight:600;">
                            Bs <span id="costo-final-ves">${(tarifa.cuponReferidoDisponible ? tarifa.costoConCuponVes : tarifa.costoFinalVes).toFixed(2)}</span>
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
    let usarCupon = tarifa.cuponReferidoDisponible ? true : false;

    const chkCuponReferido = document.getElementById('chk-cupon-referido');
    if (chkCuponReferido) {
        chkCuponReferido.addEventListener('change', () => {
            usarCupon = chkCuponReferido.checked;
            document.getElementById('costo-final-usd').textContent =
                '$' + (usarCupon ? tarifa.costoConCuponUsd : tarifa.costoFinalUsd).toFixed(2);
            document.getElementById('costo-final-ves').textContent =
                (usarCupon ? tarifa.costoConCuponVes : tarifa.costoFinalVes).toFixed(2);
        });
    }

    document.getElementById('btn-cancelar-viaje').addEventListener('click', () => {
        modal.remove();
        btnSolicitar.disabled = false;
        btnSolicitar.textContent = textoOriginalBtn;
    });

    document.getElementById('btn-confirmar-viaje').addEventListener('click', async () => {
        const btnConfirm = document.getElementById('btn-confirmar-viaje');
        btnConfirm.disabled = true;
        btnConfirm.textContent = 'Solicitando...';

        try {
            const finalPayload = {
                originAddress: payloadTarifa.origenStr,
                destinationAddress: payloadTarifa.destinoStr,
                originLat: payloadTarifa.originLat,
                originLng: payloadTarifa.originLng,
                destinationLat: payloadTarifa.destinationLat,
                destinationLng: payloadTarifa.destinationLng,
                passengerCount: payloadTarifa.passengerCount,
                customerCouponId: usarCupon ? tarifa.idCuponUsado : null
            };

            const responseSolicitud = await fetchAPI('/traslados/solicitar', {
                method: 'POST',
                body: JSON.stringify(finalPayload)
            });

            if (responseSolicitud.success) {
                window.location.href = '../views/cliente-viaje-activo.html';
            } else {
                throw new Error(responseSolicitud.message);
            }
        } catch (error) {
            console.error('Error solicitando viaje:', error);
            mostrarMensajeTemporal(error.message || 'No se pudo solicitar el viaje.', 'error');
            btnConfirm.disabled = false;
            btnConfirm.textContent = 'Confirmar y Solicitar';
        }
    });
}

function iniciarPollingViajeActivo() {
    const verificarViaje = async () => {
        try {
            const res = await fetchAPI('/cliente/viaje-activo');
            if (res.data) {
                window.location.href = '../views/cliente-viaje-activo.html';
            }
        } catch (e) {
            console.warn('Error verificando viaje activo:', e);
        }
    };

    verificarViaje();
    setInterval(verificarViaje, 10000);
}

function mostrarMensajeTemporal(mensaje, tipo) {
    let container = document.getElementById('toast-container');
    if (!container) {
        container = document.createElement('div');
        container.id = 'toast-container';
        container.style.cssText = 'position: fixed; bottom: 20px; right: 20px; z-index: 10000;';
        document.body.appendChild(container);
    }
    const toast = document.createElement('div');
    toast.style.cssText = `
        background: ${tipo === 'error' ? '#F44336' : '#4CAF50'};
        color: white; padding: 12px 24px; border-radius: 8px;
        margin-top: 10px; box-shadow: 0 4px 12px rgba(0,0,0,0.15);
        font-family: inherit; font-size: 14px; opacity: 0; transition: opacity 0.3s;
    `;
    toast.textContent = mensaje;
    container.appendChild(toast);
    
    requestAnimationFrame(() => toast.style.opacity = '1');
    setTimeout(() => {
        toast.style.opacity = '0';
        setTimeout(() => toast.remove(), 300);
    }, 4000);
}