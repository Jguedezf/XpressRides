// notifications.js — Módulo compartido de notificaciones
// Se carga en TODAS las páginas autenticadas.
// Responsabilidades:
//   1. Consultar notificaciones pendientes del usuario
//   2. Actualizar el badge de la campanita (#badge-count)
//   3. Mostrar/ocultar panel de notificaciones al hacer clic

document.addEventListener('DOMContentLoaded', async () => {
    // Solo ejecutar si el usuario está autenticado
    const usuario = getUsuario();
    if (!usuario) return;

    await cargarNotificaciones(usuario);
    configurarCampanita();
});

/**
 * Consulta GET /api/reportes/notificaciones y filtra por el ID del usuario.
 * Actualiza el badge con la cantidad de notificaciones pendientes.
 */
async function cargarNotificaciones(usuario) {
    try {
        // Intentar primero el endpoint seguro (si existe) que filtra por JWT
        let misNotificaciones = [];
        try {
            const responseSeguro = await fetchAPI('/notificaciones');
            misNotificaciones = Array.isArray(responseSeguro) ? responseSeguro : (responseSeguro.data || []);
        } catch (errorSeguro) {
            // Fallback: usar el endpoint público y filtrar del lado del cliente
            const response = await fetchAPI('/reportes/notificaciones');
            const todas = response.data || [];
            misNotificaciones = todas.filter(n => n.userId === usuario.id);
        }

        // Guardamos en variable global para que el panel las use
        window._xpressNotificaciones = misNotificaciones;

        // Actualizar el badge visual
        actualizarBadge(misNotificaciones.length);

    } catch (error) {
        // Si fallan ambos (backend apagado, etc.), mostramos 0 silenciosamente
        console.warn('No se pudieron cargar las notificaciones:', error.message);
        window._xpressNotificaciones = [];
        actualizarBadge(0);
    }
}

/**
 * Actualiza el badge numérico de la campanita.
 * Si count es 0, oculta el badge.
 */
function actualizarBadge(count) {
    const badge = document.getElementById('badge-count');
    if (!badge) return;

    if (count > 0) {
        badge.textContent = count > 99 ? '99+' : count;
        badge.style.display = 'flex';
    } else {
        badge.style.display = 'none';
    }
}

/**
 * Configura el onclick de TODAS las campanitas de la página.
 * Las campanitas que ya tienen onclick="abrirNotificaciones()" seguirán funcionando.
 * Las que no tienen onclick, se les agrega.
 */
function configurarCampanita() {
    const bells = document.querySelectorAll('.notification-bell');
    bells.forEach(bell => {
        // Si no tiene onclick asignado, agregamos el handler
        if (!bell.getAttribute('onclick')) {
            bell.style.cursor = 'pointer';
            bell.addEventListener('click', abrirNotificaciones);
        }
    });
}

/**
 * Función global — abre/cierra el panel de notificaciones.
 * Se llama desde onclick="abrirNotificaciones()" en los HTML.
 */
window.abrirNotificaciones = function () {
    // Si ya existe el panel, lo cerramos (toggle)
    const existente = document.getElementById('panel-notificaciones');
    if (existente) {
        existente.remove();
        return;
    }

    const notificaciones = window._xpressNotificaciones || [];

    // Construir contenido de la lista
    let listaHTML = '';
    if (notificaciones.length === 0) {
        listaHTML = `
            <div style="padding: 20px; text-align: center; color: #999; font-size: 14px;">
                No tienes notificaciones pendientes 🎉
            </div>
        `;
    } else {
        notificaciones.forEach(n => {
            const fecha = new Date(n.dateTime);
            const fechaStr = fecha.toLocaleDateString('es-VE', {
                day: '2-digit', month: 'short', hour: '2-digit', minute: '2-digit'
            });

            // Ícono según tipo de notificación
            let icono = '🔔';
            if (n.type === 'viaje') icono = '🚗';
            else if (n.type === 'pago') icono = '💰';
            else if (n.type === 'sistema') icono = '⚙️';

            listaHTML += `
                <div style="padding: 12px 16px; border-bottom: 1px solid #f0f0f0; display: flex; gap: 10px; align-items: flex-start;">
                    <span style="font-size: 18px; flex-shrink: 0;">${icono}</span>
                    <div style="flex: 1; min-width: 0;">
                        <p style="margin: 0 0 4px 0; font-size: 14px; color: #333; line-height: 1.4;">${n.message || 'Sin mensaje'}</p>
                        <span style="font-size: 11px; color: #999;">${fechaStr}</span>
                    </div>
                </div>
            `;
        });
    }

    // Crear el panel flotante
    const panelHTML = `
        <div id="panel-notificaciones" style="
            position: fixed; top: 0; right: 0; bottom: 0; left: 0;
            z-index: 9998; background: transparent;"
            onclick="if(event.target === this) this.remove();">

            <div style="
                position: absolute; top: 56px; right: 16px;
                width: 320px; max-width: calc(100vw - 32px);
                background: #fff; border-radius: 12px;
                box-shadow: 0 8px 30px rgba(0,0,0,0.18);
                overflow: hidden; z-index: 9999;
                animation: slideDown 0.2s ease-out;">

                <div style="padding: 14px 16px; background: linear-gradient(135deg, #1F4E79 0%, #C55A11 100%);
                    color: white; font-weight: 700; font-size: 15px; display: flex; justify-content: space-between; align-items: center;">
                    <span>Notificaciones</span>
                    <span style="font-size: 12px; opacity: 0.9;">${notificaciones.length} pendiente${notificaciones.length !== 1 ? 's' : ''}</span>
                </div>

                <div style="max-height: 360px; overflow-y: auto;">
                    ${listaHTML}
                </div>
            </div>
        </div>
    `;

    document.body.insertAdjacentHTML('beforeend', panelHTML);

    // Marcar todas como leídas en background
    if (notificaciones.length > 0) {
        Promise.all(notificaciones.map(n =>
            fetchAPI(`/notificaciones/${n.id}/leer`, { method: 'PUT' })
                .catch(e => console.warn('No se pudo marcar como leída:', e.message))
        )).then(() => {
            window._xpressNotificaciones = [];
            actualizarBadge(0);
        });
    }
};

// Estilos de animación para el panel
(function inyectarEstilosNotificaciones() {
    if (document.getElementById('notif-styles')) return;
    const style = document.createElement('style');
    style.id = 'notif-styles';
    style.textContent = `
        @keyframes slideDown {
            from { opacity: 0; transform: translateY(-10px); }
            to   { opacity: 1; transform: translateY(0); }
        }
    `;
    document.head.appendChild(style);
})();
