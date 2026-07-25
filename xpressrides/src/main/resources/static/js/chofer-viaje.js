// js/chofer-viaje.js — Integración real con el backend XpressRides (Google Maps)

document.addEventListener('DOMContentLoaded', async () => {
    if (!requireAuth()) return;
    configurarBotonesEstado();
    configurarBotonEmergencia();
    configurarModoUbicacion();

    // Cargar Google Maps API y el mapa ANTES de cargar el viaje
    try {
        await Promise.all([cargarGoogleMaps(), cargarImagenAutoBase()]);
        inicializarMapaChofer();
    } catch (error) {
        console.error("No se pudo cargar el mapa:", error);
    }
    
    if (modoUbicacion === 'automatico') iniciarTrackingAutomatico();

    // AHORA que el mapa existe, cargar viaje y SSE
    cargarViajeActivo();
    iniciarStreamViajeActivo();
});

let mapaChofer = null;
let marcadorChofer = null;
let circuloPrecision = null;
let watchId = null;
let daemonIntervalId = null;
let ultimaPosicion = getUltimaPosicionGuardada();
let viajeActual = null;
let countdownInterval = null;

let directionsService = null;
let directionsRenderer = null;
let originMarker = null;
let destinationMarker = null;
let fallbackPolyline = null;
let idTrasladoConViewportAjustado = null; // idTraslado ya ajustado una vez en dibujarRutaViaje()
const RESPONSE_TIMEOUT_SECONDS = 30; // debe coincidir con TripTimeoutScheduler (backend)

function getDriverLocationKey() {
    const usuario = getUsuario();
    const id = usuario ? (usuario.username || usuario.id || usuario.idUsuario || 'default') : 'default';
    return 'driverLocation_' + id;
}

function setUltimaPosicion(pos) {
    ultimaPosicion = pos;
    localStorage.setItem(getDriverLocationKey(), JSON.stringify({ lat: pos.lat, lng: pos.lng, time: Date.now() }));
}

function getUltimaPosicionGuardada() {
    const dataStr = localStorage.getItem(getDriverLocationKey());
    if (dataStr) {
        try {
            const data = JSON.parse(dataStr);
            // Considerar válida solo si tiene menos de 2 horas
            if (Date.now() - data.time < 2 * 60 * 60 * 1000) {
                return { lat: data.lat, lng: data.lng };
            }
        } catch (e) {}
    }
    return null;
}

// ─── 1. MAPA ────────────────────────────────────────

// Ícono del vehículo — imagen diseñada por Johanna (docs referencias/auto-icono-johanna.png),
// vista desde arriba con el frente apuntando "hacia arriba" (heading=0). Un PNG no puede
// llevar transform="rotate()" como el SVG anterior, así que se rota dinámicamente dibujándolo
// en un <canvas> oculto en cada paso de la simulación (ver calcularRumbo() más abajo).
let imagenAutoBase = null;

function cargarImagenAutoBase() {
    return new Promise((resolve, reject) => {
        if (imagenAutoBase) return resolve(imagenAutoBase);
        const img = new Image();
        img.crossOrigin = "Anonymous";
        img.onload = () => { imagenAutoBase = img; resolve(img); };
        img.onerror = reject;
        img.src = '/img/auto-icono.png';
    });
}

function crearIconoAutoRotado(headingDegrees = 0) {
    const size = 40;
    const canvas = document.createElement('canvas');
    canvas.width = size;
    canvas.height = size;
    const ctx = canvas.getContext('2d');
    ctx.translate(size / 2, size / 2);
    ctx.rotate(headingDegrees * Math.PI / 180);
    ctx.drawImage(imagenAutoBase, -size / 2, -size / 2, size, size);
    return {
        url: canvas.toDataURL(),
        scaledSize: new google.maps.Size(size, size),
        anchor: new google.maps.Point(size / 2, size / 2)
    };
}

// Rumbo (bearing) inicial entre 2 coordenadas, en grados 0-360 (0 = norte) — usado para
// rotar el ícono del auto durante la simulación, recalculado en cada paso de la ruta.
function calcularRumbo(lat1, lng1, lat2, lng2) {
    const toRad = deg => deg * Math.PI / 180;
    const y = Math.sin(toRad(lng2 - lng1)) * Math.cos(toRad(lat2));
    const x = Math.cos(toRad(lat1)) * Math.sin(toRad(lat2)) -
              Math.sin(toRad(lat1)) * Math.cos(toRad(lat2)) * Math.cos(toRad(lng2 - lng1));
    return (Math.atan2(y, x) * 180 / Math.PI + 360) % 360;
}

function inicializarMapaChofer() {
    const centroGuayana = ultimaPosicion || { lat: 8.29, lng: -62.71 };

    mapaChofer = new google.maps.Map(document.getElementById('map'), {
        center: centroGuayana,
        zoom: 14,
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
        }
    });

    // Interactividad al hacer click en el mapa
    const infoWindow = new google.maps.InfoWindow();
    const geocoder = new google.maps.Geocoder();

    mapaChofer.addListener('click', (e) => {
        infoWindow.close();

        if (e.placeId) {
            return;
        }

        const clickedLat = e.latLng.lat();
        const clickedLng = e.latLng.lng();

        geocoder.geocode({ location: e.latLng }, (results, status) => {
            const direccion = (status === 'OK' && results[0])
                ? results[0].formatted_address
                : `${clickedLat.toFixed(5)}, ${clickedLng.toFixed(5)}`;

            // Crear un ID único para el botón de fijar ubicación
            const btnId = 'btn-fijar-ubicacion-' + Date.now();

            infoWindow.setContent(`
                <div style="padding: 8px; color: #333; font-family: 'Inter', sans-serif;">
                    <h4 style="margin: 0 0 4px 0; color: #1F4E79; font-size: 14px;">Ubicación seleccionada</h4>
                    <p style="margin: 0 0 8px 0; font-size: 12px;">${direccion}</p>
                    <button id="${btnId}" style="
                        background: #1F4E79; color: white; border: none; border-radius: 6px;
                        padding: 6px 12px; font-size: 12px; font-weight: 600; cursor: pointer;
                        width: 100%; font-family: 'Inter', sans-serif;
                    ">📍 Fijar como mi ubicación</button>
                </div>
            `);
            infoWindow.setPosition(e.latLng);
            infoWindow.open(mapaChofer);

            // Esperar a que el DOM del InfoWindow se renderice para agregar el listener
            google.maps.event.addListenerOnce(infoWindow, 'domready', () => {
                const btnFijar = document.getElementById(btnId);
                if (btnFijar) {
                    btnFijar.addEventListener('click', () => {
                        const nuevaPos = { lat: clickedLat, lng: clickedLng };

                        // 1. Actualizar ultimaPosicion
                        setUltimaPosicion(nuevaPos);

                        // 2. Mover marcadorChofer
                        if (marcadorChofer) {
                            marcadorChofer.setPosition(nuevaPos);
                        } else {
                            marcadorChofer = new google.maps.Marker({
                                position: nuevaPos,
                                map: mapaChofer,
                                title: 'Tu ubicación',
                                icon: crearIconoAutoRotado(),
                                animation: google.maps.Animation.DROP
                            });
                        }

                        // 3. Actualizar circuloPrecision
                        if (circuloPrecision) {
                            circuloPrecision.setCenter(nuevaPos);
                            circuloPrecision.setRadius(50); // Precisión simulada
                        }

                        // 4. Centrar mapa
                        mapaChofer.setCenter(nuevaPos);

                        // 5. Reportar ubicación al backend
                        reportarUbicacion();

                        // 6. Cerrar InfoWindow
                        infoWindow.close();
                    });
                }
            });
        });
    });

    // Si ya tenemos posición del seguimiento previo, crear marcador inmediatamente
    if (ultimaPosicion) {
        marcadorChofer = new google.maps.Marker({
            position: ultimaPosicion,
            map: mapaChofer,
            title: 'Tu ubicación',
            icon: crearIconoAutoRotado(),
            animation: google.maps.Animation.DROP
        });
    }

    // Dibujar ruta si el viaje ya fue cargado antes de que el mapa estuviera listo
    if (viajeActual) {
        dibujarRutaViaje();
    }
}

let modoUbicacion = 'manual'; // 'manual' | 'automatico'

function configurarModoUbicacion() {
    const toggle = document.getElementById('ubicacion-mode-toggle');
    const label = document.getElementById('ubicacion-mode-label');
    if (!toggle) return;

    toggle.addEventListener('change', () => {
        detenerTrackingAutomatico();
        if (toggle.checked) {
            modoUbicacion = 'automatico';
            if (label) label.textContent = 'GPS automático';
            iniciarTrackingAutomatico();
        } else {
            modoUbicacion = 'manual';
            if (label) label.textContent = 'Manual';
        }
    });
}

// watchPosition actualiza la posición y el marcador en cada callback; ya no aplica la
// cautela de "nunca tocar el mapa" del commit 9386be4 (ese bug era por los controles
// nativos de Google Maps deshabilitados, ya reactivados en inicializarMapaChofer()) —
// no se toca el zoom/centro del mapa aquí, solo se mueve el marcador. El reporte al
// backend sigue aparte, cada 15s, con la última posición conocida.
function iniciarTrackingAutomatico() {
    if (!navigator.geolocation) return;
    if (!watchId) {
        watchId = navigator.geolocation.watchPosition(
            (pos) => {
                ultimaPosicion = { lat: pos.coords.latitude, lng: pos.coords.longitude };
                if (marcadorChofer) {
                    marcadorChofer.setPosition(ultimaPosicion);
                } else {
                    marcadorChofer = new google.maps.Marker({
                        position: ultimaPosicion,
                        map: mapaChofer,
                        title: 'Tu ubicación',
                        icon: crearIconoAutoRotado(),
                        animation: google.maps.Animation.DROP
                    });
                    mapaChofer.setCenter(ultimaPosicion);
                }
            },
            (err) => console.warn('Error de geolocalización:', err.message),
            { enableHighAccuracy: true, maximumAge: 5000, timeout: 10000 }
        );
    }
    if (!daemonIntervalId) {
        reportarUbicacion();
        daemonIntervalId = setInterval(reportarUbicacion, 15000);
    }
}

function detenerTrackingAutomatico() {
    if (watchId) {
        navigator.geolocation.clearWatch(watchId);
        watchId = null;
    }
    if (daemonIntervalId) {
        clearInterval(daemonIntervalId);
        daemonIntervalId = null;
    }
}

async function reportarUbicacion() {
    if (!ultimaPosicion) return;
    try {
        await fetchAPI('/chofer/ubicacion', {
            method: 'PUT',
            body: JSON.stringify({ lat: ultimaPosicion.lat, lng: ultimaPosicion.lng })
        });
    } catch (e) {
        console.warn('Error reportando ubicación al backend:', e);
    }
}

// ─── 2. CARGAR VIAJE ACTIVO ─────────────────────────

// Carga inicial única por fetch — evita esperar el handshake del EventSource
// antes de mostrar el primer estado del viaje.
async function cargarViajeActivo() {
    try {
        const response = await fetchAPI('/chofer/viaje-activo');
        procesarViajeActivo(response.data);
    } catch (error) {
        console.error('Error cargando viaje activo:', error);
    }
}

let eventSourceViajeActivo = null;

function iniciarStreamViajeActivo() {
    const usuario = getUsuario();
    if (!usuario || !usuario.token) return;

    eventSourceViajeActivo = new EventSource(`/api/chofer/viaje-activo/stream?token=${encodeURIComponent(usuario.token)}`);
    eventSourceViajeActivo.addEventListener('viaje', (e) => {
        procesarViajeActivo(JSON.parse(e.data));
    });
    eventSourceViajeActivo.onerror = (e) => {
        console.warn('Conexión SSE de viaje activo interrumpida, reintentando...', e);
    };
}

function procesarViajeActivo(viaje) {
    if (!viaje) {
        if (viajeActual !== null) {
            ocultarPaneles();
        }
        return;
    }

    // Solo actualizar UI si el estado cambió para no parpadear
    if (!viajeActual || viajeActual.estado !== viaje.estado || viajeActual.idTraslado !== viaje.idTraslado) {
        viajeActual = viaje;
        renderizarEstado(viaje);
    }
}

function ocultarPaneles() {
    document.getElementById('push-notification').classList.add('hidden');
    document.getElementById('state-buttons').classList.add('hidden');
    viajeActual = null;
    detenerCuentaRegresiva();
    
    if (originMarker) { originMarker.setMap(null); originMarker = null; }
    if (destinationMarker) { destinationMarker.setMap(null); destinationMarker = null; }
    if (directionsRenderer) { directionsRenderer.setMap(null); directionsRenderer = null; }
    if (fallbackPolyline) { fallbackPolyline.setMap(null); fallbackPolyline = null; }
}

function renderizarEstado(viaje) {
    const { estado, origen, destino, tiempoEstimadoLlegadaMinutos, duracionEstimadaMinutos } = viaje;

    // Poblar datos del viaje en la notificación
    document.getElementById('push-origen').textContent = origen;
    document.getElementById('push-destino').textContent = destino;

    // Ocultar todo primero
    document.getElementById('push-notification').classList.add('hidden');
    document.getElementById('state-buttons').classList.add('hidden');
    detenerCuentaRegresiva();

    const btnCancelar = document.getElementById('btn-cancelar');
    if (btnCancelar) btnCancelar.classList.add('hidden');
    
    const btnRealista = document.getElementById('btn-sim-realista');
    const btnRapida = document.getElementById('btn-sim-rapida');
    
    if (btnRealista && btnRapida) {
        btnRealista.disabled = false;
        btnRapida.disabled = false;
    }

    switch (estado) {
        case 'solicitado':
            document.getElementById('push-notification').classList.remove('hidden');
            iniciarCuentaRegresiva(viaje.fechaAsignacionActual || viaje.fechaSolicitud);
            dibujarRutaViaje();
            break;

        case 'aceptado':
            document.getElementById('state-buttons').classList.remove('hidden');
            if (btnCancelar) btnCancelar.classList.remove('hidden');
            if (btnRealista && btnRapida) {
                btnRealista.textContent = '🚗 Ir al Origen (Real)';
                btnRapida.textContent = '🏎️ Ir al Origen (Rápido)';
                btnRealista.onclick = () => iniciarSimulacionHacia('origen', false);
                btnRapida.onclick = () => iniciarSimulacionHacia('origen', true);
            }
            mostrarMensaje(`Viaje aceptado — dirígete a ${origen}`);
            dibujarRutaViaje();
            break;

        case 'en_camino':
            document.getElementById('state-buttons').classList.remove('hidden');
            if (btnCancelar) btnCancelar.classList.remove('hidden');
            if (btnRealista && btnRapida) {
                btnRealista.textContent = 'Simulando...';
                btnRapida.textContent = 'Simulando...';
                btnRealista.disabled = true;
                btnRapida.disabled = true;
            }
            mostrarMensaje(`En camino al origen${tiempoEstimadoLlegadaMinutos ? ' (~' + tiempoEstimadoLlegadaMinutos + ' min)' : ''}`);
            dibujarRutaViaje();
            break;

        case 'chofer_llego':
            document.getElementById('state-buttons').classList.remove('hidden');
            if (btnCancelar) btnCancelar.classList.remove('hidden');
            if (btnRealista && btnRapida) {
                btnRealista.textContent = '🚗 Ir al Destino (Real)';
                btnRapida.textContent = '🏎️ Ir al Destino (Rápido)';
                btnRealista.onclick = () => iniciarSimulacionHacia('destino', false);
                btnRapida.onclick = () => iniciarSimulacionHacia('destino', true);
            }
            mostrarMensaje('Esperando que el cliente aborde');
            dibujarRutaViaje();
            break;

        case 'en_progreso':
            document.getElementById('state-buttons').classList.remove('hidden');
            if (btnCancelar) btnCancelar.classList.remove('hidden');
            if (btnRealista && btnRapida) {
                btnRealista.textContent = 'Simulando...';
                btnRapida.textContent = 'Simulando...';
                btnRealista.disabled = true;
                btnRapida.disabled = true;
            }
            mostrarMensaje(`En progreso → ${destino}${duracionEstimadaMinutos ? ' (~' + duracionEstimadaMinutos + ' min)' : ''}`);
            dibujarRutaViaje();
            break;
            
        case 'completado':
        case 'cancelado':
            viajeActual = null;
            if (originMarker) originMarker.setMap(null);
            if (destinationMarker) destinationMarker.setMap(null);
            if (directionsRenderer) directionsRenderer.setMap(null);
            if (fallbackPolyline) fallbackPolyline.setMap(null);
            break;
    }
}

function dibujarRutaViaje() {
    if (!viajeActual || !mapaChofer) return;

    if (!directionsService) directionsService = new google.maps.DirectionsService();
    if (!directionsRenderer) {
        directionsRenderer = new google.maps.DirectionsRenderer({
            map: mapaChofer,
            suppressMarkers: true,
            polylineOptions: { strokeColor: '#2E7D32', strokeWeight: 4 }
        });
    }

    // Solo la primera vez que se dibuja la ruta de ESTE viaje dejamos que el mapa
    // ajuste zoom/centro para mostrarla completa. En redibujos posteriores del mismo
    // viaje (cambios de estado: en_camino, chofer_llego, en_progreso), el chofer
    // mantiene el encuadre que tenía — no se vuelve a mover el zoom.
    const esPrimerDibujo = idTrasladoConViewportAjustado !== viajeActual.idTraslado;
    directionsRenderer.setOptions({ preserveViewport: !esPrimerDibujo });
    if (esPrimerDibujo) idTrasladoConViewportAjustado = viajeActual.idTraslado;

    const orgLatLng = { lat: viajeActual.origenLat, lng: viajeActual.origenLng };
    const dstLatLng = { lat: viajeActual.destinoLat, lng: viajeActual.destinoLng };

    if (!originMarker) {
        originMarker = new google.maps.Marker({
            position: orgLatLng,
            map: mapaChofer,
            title: 'Origen',
            label: { text: 'A', color: 'white', fontWeight: 'bold' }
        });
    } else {
        originMarker.setPosition(orgLatLng);
        originMarker.setMap(mapaChofer);
    }

    if (!destinationMarker) {
        destinationMarker = new google.maps.Marker({
            position: dstLatLng,
            map: mapaChofer,
            title: 'Destino',
            label: { text: 'B', color: 'white', fontWeight: 'bold' }
        });
    } else {
        destinationMarker.setPosition(dstLatLng);
        destinationMarker.setMap(mapaChofer);
    }

    directionsService.route({
        origin: orgLatLng,
        destination: dstLatLng,
        travelMode: google.maps.TravelMode.DRIVING
    }, (res, status) => {
        if (status === 'OK') {
            directionsRenderer.setDirections(res);
            directionsRenderer.setMap(mapaChofer);
        } else {
            console.warn('Directions request failed due to ' + status + '. Drawing straight line instead.');
            if (fallbackPolyline) fallbackPolyline.setMap(null);
            fallbackPolyline = new google.maps.Polyline({
                path: [orgLatLng, dstLatLng],
                geodesic: true,
                strokeColor: '#2E7D32',
                strokeOpacity: 0.7,
                strokeWeight: 4,
                map: mapaChofer
            });
            if (esPrimerDibujo) {
                const bounds = new google.maps.LatLngBounds();
                bounds.extend(orgLatLng);
                bounds.extend(dstLatLng);
                mapaChofer.fitBounds(bounds, { top: 60, bottom: 60, left: 60, right: 60 });
            }
        }
    });
}

window.cerrarPushNotification = function () {
    document.getElementById('push-notification').classList.add('hidden');
    detenerCuentaRegresiva();
};

// Cuenta regresiva visual de los 30s que tiene el chofer para responder antes de
// que el backend (TripTimeoutScheduler) reasigne el viaje automáticamente.
// No dispara ninguna acción por sí sola: solo refleja el plazo real del servidor,
// que se aplica igual aunque esta pestaña esté cerrada.
function iniciarCuentaRegresiva(fechaAsignacionIso) {
    detenerCuentaRegresiva();
    if (!fechaAsignacionIso) return;

    const asignadoEnMs = new Date(fechaAsignacionIso).getTime();
    const barEl = document.getElementById('push-timer-bar');
    const textEl = document.getElementById('push-timer-text');

    const actualizar = () => {
        const transcurridoSeg = Math.floor((Date.now() - asignadoEnMs) / 1000);
        const restante = Math.max(0, RESPONSE_TIMEOUT_SECONDS - transcurridoSeg);

        if (textEl) textEl.textContent = `${restante} segundos restantes`;
        if (barEl) {
            barEl.style.width = `${(restante / RESPONSE_TIMEOUT_SECONDS) * 100}%`;
            barEl.classList.toggle('expired', restante <= 0);
        }

        if (restante <= 0) detenerCuentaRegresiva();
    };

    actualizar();
    countdownInterval = setInterval(actualizar, 1000);
}

function detenerCuentaRegresiva() {
    if (countdownInterval) {
        clearInterval(countdownInterval);
        countdownInterval = null;
    }
}

// ─── 3. BOTONES DE ESTADO ───────────────────────────

function configurarBotonesEstado() {
    document.getElementById('push-btn-aceptar').addEventListener('click', () => {
        detenerCuentaRegresiva();
        cambiarEstado('aceptado');
    });
    document.getElementById('push-btn-rechazar').addEventListener('click', rechazarViaje);

    const btnCancelar = document.getElementById('btn-cancelar');
    if (btnCancelar) {
        btnCancelar.addEventListener('click', cancelarViajeActivo);
    }
}

// SIMULACION DE MOVIMIENTO
let simuladorInterval = null;

async function iniciarSimulacionHacia(target, isFast) {
    if (!viajeActual || !ultimaPosicion || !mapaChofer) return;

    let destinationLatLng;
    let siguienteAccionEstado = '';
    
    if (target === 'origen') {
        await cambiarEstado('en_camino'); // Notificar al servidor que empezamos
        destinationLatLng = { lat: viajeActual.origenLat, lng: viajeActual.origenLng };
        siguienteAccionEstado = 'chofer_llego';
    } else {
        await cambiarEstado('en_progreso'); // Notificar que subió el pasajero
        destinationLatLng = { lat: viajeActual.destinoLat, lng: viajeActual.destinoLng };
        siguienteAccionEstado = 'completado';
    }

    const directionsService = new google.maps.DirectionsService();
    directionsService.route({
        origin: ultimaPosicion,
        destination: destinationLatLng,
        travelMode: google.maps.TravelMode.DRIVING
    }, (result, status) => {
        if (status === 'OK') {
            const steps = result.routes[0].overview_path;
            let currentStep = 0;
            
            // Si es "Realista", vamos cada 1.5s y avanzamos 1 step. 
            // Si es "Rapida", vamos cada 300ms y avanzamos 1 step.
            const intervalMs = isFast ? 300 : 1500;
            
            if (simuladorInterval) clearInterval(simuladorInterval);
            
            simuladorInterval = setInterval(() => {
                if (currentStep >= steps.length) {
                    clearInterval(simuladorInterval);
                    cambiarEstado(siguienteAccionEstado);
                    return;
                }
                
                const posicionAnterior = ultimaPosicion;
                const nextPos = { lat: steps[currentStep].lat(), lng: steps[currentStep].lng() };
                const rumbo = calcularRumbo(posicionAnterior.lat, posicionAnterior.lng, nextPos.lat, nextPos.lng);
                setUltimaPosicion(nextPos);

                if (marcadorChofer) {
                    marcadorChofer.setPosition(ultimaPosicion);
                    marcadorChofer.setIcon(crearIconoAutoRotado(rumbo));
                }
                if (circuloPrecision) circuloPrecision.setCenter(ultimaPosicion);
                mapaChofer.panTo(ultimaPosicion);
                
                reportarUbicacion();
                currentStep++;
            }, intervalMs);
            
        } else {
            console.error('No se pudo calcular la ruta para simular: ', status);
            // Fallback: teleport directo
            setUltimaPosicion(destinationLatLng);
            reportarUbicacion();
            cambiarEstado(siguienteAccionEstado);
        }
    });
}

async function cambiarEstado(nuevoEstado) {
    if (!viajeActual) return;
    try {
        await fetchAPI(`/chofer/traslados/${viajeActual.idTraslado}/estado`, {
            method: 'PUT',
            body: JSON.stringify({ status: nuevoEstado })
        });
        if (nuevoEstado === 'completado') {
            ocultarPaneles();
            mostrarMensaje('✅ Viaje completado exitosamente');
            renderInterfazPorEstado('completado'); // Para limpiar mapa
            setTimeout(() => {
                window.location.href = '/views/chofer-dashboard.html?viaje=completado';
            }, 2000);
        } else {
            await cargarViajeActivo();
        }
    } catch (error) {
        mostrarMensaje('Error: ' + error.message);
    }
}

async function rechazarViaje() {
    if (!viajeActual) return;
    try {
        await fetchAPI(`/chofer/traslados/${viajeActual.idTraslado}/rechazar`, { method: 'PUT' });
        document.getElementById('push-notification').classList.add('hidden');
        viajeActual = null;
        detenerCuentaRegresiva();
        mostrarMensaje('Viaje rechazado');
    } catch (error) {
        mostrarMensaje('Error: ' + error.message);
    }
}

async function cancelarViajeActivo() {
    if (!viajeActual) return;
    if (confirm('¿Estás seguro de que deseas cancelar este viaje?')) {
        try {
            await fetchAPI(`/chofer/traslados/${viajeActual.idTraslado}/cancelar`, {
                method: 'PUT',
                body: JSON.stringify({ motivo: 'Cancelado por el chofer' })
            });
            ocultarPaneles();
            mostrarMensaje('Viaje cancelado');
        } catch (error) {
            mostrarMensaje('Error al cancelar: ' + error.message);
        }
    }
}

// ─── 4. EMERGENCIA ──────────────────────────────────

function configurarBotonEmergencia() {}

window.mostrarEmergencia = async function () {
    const modalHTML = `
        <div id="modal-emergencia" class="modal-overlay" onclick="if(event.target===this)this.remove();">
            <div class="modal-content text-center">
                <h3 class="h2-subtitle" style="color:var(--color-error);">🚨 Emergencia</h3>
                <p class="text-normal mt-md mb-md">Si estás en peligro, contacta a las autoridades:</p>
                <p class="text-highlight" style="font-size:24px;color:var(--color-error);">911</p>
                <p class="text-small mt-sm">Se ha enviado una alerta de emergencia a soporte.</p>
                <button class="btn-secondary mt-md" onclick="document.getElementById('modal-emergencia').remove();">Cerrar</button>
            </div>
        </div>
    `;
    document.body.insertAdjacentHTML('beforeend', modalHTML);

    try {
        const payload = viajeActual ? { tripId: viajeActual.idTraslado } : {};
        await fetchAPI('/notificaciones/emergencia', {
            method: 'POST',
            body: JSON.stringify(payload)
        });
    } catch (e) {
        console.error("Error al enviar alerta de emergencia:", e);
    }
};

// ─── 5. MENSAJES TEMPORALES ─────────────────────────

function mostrarMensaje(texto) {
    const previo = document.getElementById('msg-temporal');
    if (previo) previo.remove();

    const div = document.createElement('div');
    div.id = 'msg-temporal';
    div.style.cssText = `
        position:fixed;top:70px;left:50%;transform:translateX(-50%);
        z-index:2000;padding:12px 20px;border-radius:8px;
        background:#E8F4FD;border:1px solid #1F4E79;color:#1F4E79;
        font-size:14px;font-weight:600;box-shadow:0 4px 12px rgba(0,0,0,0.15);
        max-width:90%;
    `;
    div.textContent = texto;
    document.body.appendChild(div);

    setTimeout(() => {
        div.style.transition = 'opacity 0.3s ease';
        div.style.opacity = '0';
        setTimeout(() => div.remove(), 300);
    }, 3000);
}

// ─── 6. LIMPIEZA ────────────────────────────────────

window.addEventListener('beforeunload', () => {
    if (watchId) navigator.geolocation.clearWatch(watchId);
    if (daemonIntervalId) clearInterval(daemonIntervalId);
});
