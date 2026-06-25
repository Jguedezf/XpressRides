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
            window.location.href = '/views/login.html';
            return;
        }

        // Feedback visual: deshabilitar botón
        const btnSolicitar = document.getElementById('btn-solicitar');
        const textoOriginal = btnSolicitar.textContent;
        btnSolicitar.disabled = true;
        btnSolicitar.textContent = 'Buscando chofer...';

        try {
            const payload = {
                clienteId: usuario.id,
                zonaOrigenId: parseInt(origen),
                zonaDestinoId: parseInt(destino),
                cantPasajeros: pasajeros,
                codigoCupon: null // Por ahora sin cupón
            };

            const response = await fetchAPI('/solicitar-viaje', {
                method: 'POST',
                body: JSON.stringify(payload)
            });

            // Éxito — mostrar datos del viaje
            const data = response.data || {};
            let mensaje = '🚗 ¡Viaje solicitado exitosamente!';
            if (data.choferNombre) {
                mensaje += ` Tu chofer ${data.choferNombre} va en camino.`;
            }
            if (data.costoUsd) {
                mensaje += ` Costo: $${Number(data.costoUsd).toFixed(2)} USD.`;
            }

            mostrarMensajeTemporal(mensaje, 'info');

            // Resetear formulario
            form.reset();
            document.getElementById('origen').selectedIndex = 0;
            document.getElementById('destino').selectedIndex = 0;

        } catch (error) {
            console.error('Error solicitando viaje:', error);
            mostrarMensajeTemporal(
                error.message || 'No se pudo solicitar el viaje. Intenta de nuevo.',
                'error'
            );
        } finally {
            btnSolicitar.disabled = false;
            btnSolicitar.textContent = textoOriginal;
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