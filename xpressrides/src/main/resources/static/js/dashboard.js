// dashboard.js — Lógica del dashboard del cliente
// Usa Google Maps y Places Autocomplete para seleccionar origen y destino libre.

let mapaGoogle = null;
let originMarker = null;
let destinationMarker = null;
let directionsService = null;
let directionsRenderer = null;
let fallbackPolyline = null;
let originPlace = null;
let destinationPlace = null;
let origenAutocomplete = null;
let destinoAutocomplete = null;
let geocoder = null;   // se instancia en inicializarMapa(); a scope de módulo para reusarlo desde dragend
let infoWindow = null; // idem — lo usa mostrarInfoPOI() para clics sobre POI
let placesService = null; // a scope de módulo para buscar POIs al soltar el pin
let isInfoWindowOpen = false; // rastrea si nuestro InfoWindow personalizado está abierto

// Detecta si formatted_address es un Plus Code (ej. "CWC8+R9 Ciudad Guayana, Venezuela"):
// bloque de 4-8 caracteres del alfabeto de Plus Codes + '+' + 2-3 caracteres, sin espacios.
function esPlusCode(direccion) {
    return /\b[23456789CFGHJMPQRVWX]{4,8}\+[23456789CFGHJMPQRVWX]{2,3}\b/i.test(direccion);
}

// La tarjeta ".floating-request-card" (bottom:80px, ver cliente-dashboard.html) se
// solapa a propósito con la parte inferior del mapa, así que un InfoWindow que Google
// abre ahí queda tapado sin importar su z-index interno (#map y la tarjeta son hermanos
// en el mismo stacking context, y #map ya pierde esa pelea). En vez de pelear con
// z-index, desplazamos el mapa hacia arriba solo cuando el punto clicado cae en esa
// franja, para que el popup se abra en una zona visible.
const ALTO_ZONA_TAPADA_PX = 220; // bottom:80px de la tarjeta + alto aproximado de su contenido
function evitarPopupTapado(latLng) {
    const projection = mapaGoogle.getProjection();
    if (!projection) return;

    const bounds = mapaGoogle.getBounds();
    if (!bounds) return;

    const scale = Math.pow(2, mapaGoogle.getZoom());
    const topRight = projection.fromLatLngToPoint(bounds.getNorthEast());
    const bottomLeft = projection.fromLatLngToPoint(bounds.getSouthWest());
    const point = projection.fromLatLngToPoint(latLng);

    const pixelY = (point.y - topRight.y) * scale;
    const alturaMapa = mapaGoogle.getDiv().clientHeight;

    if (pixelY > alturaMapa - ALTO_ZONA_TAPADA_PX) {
        mapaGoogle.panBy(0, pixelY - (alturaMapa - ALTO_ZONA_TAPADA_PX));
    }
}

// Abre el InfoWindow propio (no el nativo de Google) para clics sobre un POI —
// necesitamos control manual para poder aplicar evitarPopupTapado() antes de abrirlo.
function mostrarInfoPOI(direccion, latLng) {
    infoWindow.setContent(`
        <div style="padding: 8px; color: #333; font-family: 'Inter', sans-serif;">
            <h4 style="margin: 0 0 4px 0; color: #1F4E79; font-size: 14px;">Ubicación seleccionada</h4>
            <p style="margin: 0 0 8px 0; font-size: 12px;">${direccion}</p>
        </div>
    `);
    infoWindow.setPosition(latLng);
    evitarPopupTapado(latLng);
    infoWindow.open(mapaGoogle);
    isInfoWindowOpen = true;
}

// Reverse geocoding compartido por el dragend de ambos pines y por el click derecho.
// Intenta primero buscar un POI exacto. Si no lo hay, cae a la calle exacta (backend),
// y finalmente al fallback clásico ( Plus Code -> localidad ).
async function reverseGeocodeAmigable(latLng, callback) {
    if (placesService) {
        placesService.nearbySearch({ location: latLng, radius: 30 }, async (results, status) => {
            if (status === google.maps.places.PlacesServiceStatus.OK && results.length > 0) {
                // Filtrar resultados genéricos (ciudades, barrios, calles) para quedarnos solo con POIs reales
                const best = results.find(r => r.types && 
                    !r.types.includes('political') && 
                    !r.types.includes('locality') && 
                    !r.types.includes('sublocality') && 
                    !r.types.includes('neighborhood') &&
                    !r.types.includes('route')
                );

                if (best) {
                    const nombreLugar = best.name + (best.vicinity && !best.name.includes(best.vicinity) ? ', ' + best.vicinity : '');
                    callback(nombreLugar);
                    return;
                }
            }
            // Si no hay resultados o todos eran genéricos, seguimos con el geocoding de calle
            continuarGeocoding();
        });
    } else {
        continuarGeocoding();
    }

    async function continuarGeocoding() {
        try {
            const response = await fetchAPI(`/geocoding/reverse?lat=${latLng.lat()}&lng=${latLng.lng()}`);
            if (response && response.data) {
                callback(response.data);
                return;
            }
        } catch (e) {
            // Sin resultado preciso a nivel de calle — seguimos con el fallback.
        }

        geocoder.geocode({ location: latLng }, (results, status) => {
            let direccion;
            if (status === 'OK' && results[0] && !esPlusCode(results[0].formatted_address)) {
                direccion = results[0].formatted_address;
            } else if (status === 'OK' && results[0]) {
                const comp = results[0].address_components.find(c =>
                    c.types.includes('sublocality') || c.types.includes('locality') || c.types.includes('administrative_area_level_2')
                );
                direccion = comp
                    ? `Cerca de ${comp.long_name}`
                    : `Ubicación aproximada (${latLng.lat().toFixed(5)}, ${latLng.lng().toFixed(5)})`;
            } else {
                direccion = `Ubicación aproximada (${latLng.lat().toFixed(5)}, ${latLng.lng().toFixed(5)})`;
            }
            callback(direccion);
        });
    }
}

// Distancia aproximada (proporcional, no en metros reales) solo para decidir cuál de
// los 2 pines ya puestos está más cerca de un clic nuevo — no hace falta más precisión
// que esa para esta decisión, así que no se carga la librería geometry.
function distanciaAprox(latLngA, latLngB) {
    const dLat = latLngA.lat() - latLngB.lat();
    const dLng = latLngA.lng() - latLngB.lng();
    return dLat * dLat + dLng * dLng;
}

// Umbral conservador para distinguir un arrastre deliberado de un micro-movimiento
// accidental (2-3px de jitter de mouse/trackpad sobre un pin recién centrado por
// Autocomplete). EN PÍXELES DE PANTALLA, no metros — corrección del 14/07/2026:
// un umbral en metros resultó inútil (a zoom 12, el zoom con el que Autocomplete
// centra el mapa, 1px ya son ~38 metros reales, así que cualquier jitter normal
// lo superaba sin filtrar nada). El jitter de mouse/trackpad es un fenómeno de
// hardware, prácticamente constante en píxeles sin importar el zoom — por eso
// píxeles es la unidad correcta aquí. Valor de partida a validar con pruebas
// reales (Johanna, 14/07/2026): si se siente muy sensible o muy laxo, se ajusta
// este número, no la lógica de alrededor.
const UMBRAL_DRAG_ACCIDENTAL_PX = 8;

// Distancia en píxeles de pantalla entre 2 LatLng — misma proyección que ya usa
// evitarPopupTapado(), así el umbral tiene el mismo significado (jitter de mouse)
// sin importar el nivel de zoom actual.
function distanciaPixeles(latLngA, latLngB) {
    const projection = mapaGoogle.getProjection();
    if (!projection) return Infinity; // sin proyección disponible, no filtramos
    const scale = Math.pow(2, mapaGoogle.getZoom());
    const pointA = projection.fromLatLngToPoint(latLngA);
    const pointB = projection.fromLatLngToPoint(latLngB);
    const dx = (pointA.x - pointB.x) * scale;
    const dy = (pointA.y - pointB.y) * scale;
    return Math.sqrt(dx * dx + dy * dy);
}

// Bloquea el arrastre del pin por ~400ms tras crearlo/reposicionarlo (clic o
// Autocomplete) — es la ventana de mayor riesgo, porque el mapa se recentra sobre
// el pin justo ahí y el mouse del usuario suele estar cerca. Capa complementaria
// al umbral de distancia, no lo reemplaza (por si el mouse sigue cerca del pin
// después de esos 400ms).
function bloquearDragTemporal(marker) {
    marker.setDraggable(false);
    setTimeout(() => marker.setDraggable(true), 400);
}

function aplicarSeleccion(mode, direccion, latLng) {
    const place = { geometry: { location: latLng }, name: direccion };
    if (mode === 'origen') {
        originPlace = place;
        document.getElementById('origen').value = direccion;
    } else {
        destinationPlace = place;
        document.getElementById('destino').value = direccion;
    }
    actualizarMarcadoresYRuta();
}

// Pin tipo Google Maps/Uber (gota + degradado sutil + contorno blanco + punto central
// + sombra elíptica), construido en SVG puro — sin imágenes externas. Los 4 colores son
// los mismos --color-success/--color-success-bg/--color-error/--color-error-bg de
// estilos.css (una SVG data URI no puede leer variables CSS de la página, así que se
// copian los valores hex tal cual están definidos ahí, no son colores nuevos).
function crearIconoPin(colorClaro, colorOscuro) {
    const svg = `
        <svg xmlns="http://www.w3.org/2000/svg" width="30" height="42" viewBox="0 0 24 36">
            <defs>
                <linearGradient id="grad" x1="0" y1="0" x2="0" y2="1">
                    <stop offset="0%" stop-color="${colorClaro}"/>
                    <stop offset="100%" stop-color="${colorOscuro}"/>
                </linearGradient>
            </defs>
            <ellipse cx="12" cy="34" rx="5" ry="2" fill="rgba(0,0,0,0.25)"/>
            <path d="M12 0C5.373 0 0 5.373 0 12c0 9 12 24 12 24s12-15 12-24C24 5.373 18.627 0 12 0z"
                  fill="url(#grad)" stroke="#FFFFFF" stroke-width="1.5"/>
            <circle cx="12" cy="12" r="4.5" fill="#FFFFFF"/>
        </svg>
    `;
    return {
        url: 'data:image/svg+xml;charset=UTF-8,' + encodeURIComponent(svg),
        scaledSize: new google.maps.Size(30, 42),
        anchor: new google.maps.Point(15, 40)
    };
}

const COLOR_ORIGEN_CLARO   = '#E2EFDA'; // --color-success-bg (estilos.css)
const COLOR_ORIGEN_OSCURO  = '#1E6B3C'; // --color-success
const COLOR_DESTINO_CLARO  = '#FCE4D6'; // --color-error-bg
const COLOR_DESTINO_OSCURO = '#C00000'; // --color-error

document.addEventListener('DOMContentLoaded', async () => {
    if (!requireAuth()) return;
    configurarCalculadora();

    // Mostrar notificación si se redirigió desde un viaje completado o cancelado
    const urlParams = new URLSearchParams(window.location.search);
    const viajeStatus = urlParams.get('viaje');
    if (viajeStatus === 'completado') {
        mostrarMensajeTemporal('✅ ¡Viaje completado con éxito! Gracias por usar XpressRides.', 'success');
        // Limpiar URL
        window.history.replaceState({}, document.title, window.location.pathname);
    } else if (viajeStatus === 'cancelado') {
        mostrarMensajeTemporal('❌ El viaje fue cancelado.', 'error');
        window.history.replaceState({}, document.title, window.location.pathname);
    }

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

    geocoder = new google.maps.Geocoder();
    infoWindow = new google.maps.InfoWindow();

    infoWindow.addListener('closeclick', () => {
        isInfoWindowOpen = false;
    });

    placesService = new google.maps.places.PlacesService(mapaGoogle);

    mapaGoogle.addListener('click', (e) => {
        // Si nuestra ventana está abierta, el click en el mapa solo la cierra
        if (isInfoWindowOpen) {
            infoWindow.close();
            isInfoWindowOpen = false;
            // Si además clickearon un POI, evitamos que Google abra su ventana nativa
            if (e.placeId) {
                e.stop();
            }
            return;
        }

        // Clic sobre un POI: dejamos que Google muestre su InfoWindow nativo rico
        if (e.placeId) {
            evitarPopupTapado(e.latLng);
            return;
        }

        // Clic en terreno vacío: mostramos nuestro InfoWindow con la info, sin colocar pines
        reverseGeocodeAmigable(e.latLng, (direccion) => {
            mostrarInfoPOI(direccion, e.latLng);
        });
    });

    mapaGoogle.addListener('rightclick', (e) => {
        // Click derecho: colocar o mover pines de origen/destino
        let mode;
        if (!originPlace) {
            mode = 'origen';
        } else if (!destinationPlace) {
            mode = 'destino';
        } else {
            mode = distanciaAprox(e.latLng, originPlace.geometry.location) <=
                   distanciaAprox(e.latLng, destinationPlace.geometry.location)
                   ? 'origen' : 'destino';
        }

        reverseGeocodeAmigable(e.latLng, (direccion) => aplicarSeleccion(mode, direccion, e.latLng));
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
    if (fallbackPolyline) fallbackPolyline.setMap(null);

    if (originPlace && originPlace.geometry) {
        if (!originMarker) {
            originMarker = new google.maps.Marker({
                map: mapaGoogle,
                title: 'Origen (arrastra para ajustar)',
                draggable: true,
                animation: google.maps.Animation.DROP,
                icon: crearIconoPin(COLOR_ORIGEN_CLARO, COLOR_ORIGEN_OSCURO)
            });
            originMarker.addListener('dragend', () => {
                const nuevaPos = originMarker.getPosition();
                if (originPlace && distanciaPixeles(nuevaPos, originPlace.geometry.location) < UMBRAL_DRAG_ACCIDENTAL_PX) {
                    originMarker.setPosition(originPlace.geometry.location); // revierte el micro-movimiento
                    return;
                }
                reverseGeocodeAmigable(nuevaPos, (direccion) => aplicarSeleccion('origen', direccion, nuevaPos));
            });

            originMarker.addListener('rightclick', () => {
                originPlace = null;
                document.getElementById('origen').value = '';
                actualizarMarcadoresYRuta();
            });
        }
        originMarker.setPosition(originPlace.geometry.location);
        mapaGoogle.setCenter(originPlace.geometry.location);
        bloquearDragTemporal(originMarker);
    } else if (originMarker) {
        originMarker.setMap(null);
        originMarker = null;
    }

    if (destinationPlace && destinationPlace.geometry) {
        if (!destinationMarker) {
            destinationMarker = new google.maps.Marker({
                map: mapaGoogle,
                title: 'Destino (arrastra para ajustar)',
                draggable: true,
                animation: google.maps.Animation.DROP,
                icon: crearIconoPin(COLOR_DESTINO_CLARO, COLOR_DESTINO_OSCURO)
            });
            destinationMarker.addListener('dragend', () => {
                const nuevaPos = destinationMarker.getPosition();
                if (destinationPlace && distanciaPixeles(nuevaPos, destinationPlace.geometry.location) < UMBRAL_DRAG_ACCIDENTAL_PX) {
                    destinationMarker.setPosition(destinationPlace.geometry.location); // revierte el micro-movimiento
                    return;
                }
                reverseGeocodeAmigable(nuevaPos, (direccion) => aplicarSeleccion('destino', direccion, nuevaPos));
            });

            destinationMarker.addListener('rightclick', () => {
                destinationPlace = null;
                document.getElementById('destino').value = '';
                actualizarMarcadoresYRuta();
            });
        }
        destinationMarker.setPosition(destinationPlace.geometry.location);
        bloquearDragTemporal(destinationMarker);
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
            } else {
                console.warn('Directions request failed due to ' + status + '. Drawing straight line instead.');
                if (fallbackPolyline) fallbackPolyline.setMap(null);
                fallbackPolyline = new google.maps.Polyline({
                    path: [originPlace.geometry.location, destinationPlace.geometry.location],
                    geodesic: true,
                    strokeColor: '#1F4E79',
                    strokeOpacity: 0.7,
                    strokeWeight: 4,
                    map: mapaGoogle
                });
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