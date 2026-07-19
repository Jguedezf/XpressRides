document.addEventListener('DOMContentLoaded', async () => {
    // Proteger ruta
    if (!requireAuth()) return;
    await cargarNotificaciones();
    await cargarIncidentes();
});

const ESTADO_INCIDENTE_TEXTO = { abierto: 'Abierto', en_proceso: 'En Proceso', cerrado: 'Cerrado' };

async function cargarIncidentes() {
    const container = document.getElementById('incidents-container');

    try {
        const response = await fetchAPI('/notificaciones/incidentes');
        const incidentes = response.data || [];

        if (incidentes.length === 0) {
            container.innerHTML = '<p class="text-center text-mutted">No hay incidentes reportados.</p>';
            return;
        }

        container.innerHTML = '';
        incidentes.forEach(inc => {
            const dateStr = new Date(inc.createdAt).toLocaleString();
            const reportante = inc.reportedBy ? `${inc.reportedBy.name || ''} ${inc.reportedBy.lastName || ''}`.trim() : 'Desconocido';

            const card = document.createElement('div');
            card.className = 'incident-card';
            card.innerHTML = `
                <div style="display:flex; justify-content:space-between; align-items:flex-start; gap:12px;">
                    <div>
                        <p style="margin:0; font-size:14px; font-weight:600; color: var(--color-text-main);">${inc.message}</p>
                        <p style="margin:4px 0 0 0; font-size:12px; color: var(--color-text-muted);">Reportado por ${reportante} — ${dateStr}</p>
                        ${inc.status === 'cerrado' && inc.resolutionNotes ? `<p style="margin:6px 0 0 0; font-size:12px; color: var(--color-text-muted);"><em>Resolución: ${inc.resolutionNotes}</em></p>` : ''}
                    </div>
                    <span class="incident-badge badge-${inc.status}">${ESTADO_INCIDENTE_TEXTO[inc.status] || inc.status}</span>
                </div>
                <div id="incident-actions-${inc.id}"></div>
            `;
            const actionsDiv = card.querySelector(`#incident-actions-${inc.id}`);

            if (inc.status === 'abierto') {
                const btnTomar = document.createElement('button');
                btnTomar.className = 'btn-mini';
                btnTomar.style.cssText = 'background:#856404;color:white;';
                btnTomar.textContent = 'Tomar Caso';
                btnTomar.addEventListener('click', () => tomarIncidente(inc.id));
                actionsDiv.appendChild(btnTomar);
            }

            if (inc.status === 'abierto' || inc.status === 'en_proceso') {
                const btnCerrar = document.createElement('button');
                btnCerrar.className = 'btn-mini';
                btnCerrar.style.cssText = 'background:#2E7D32;color:white;';
                btnCerrar.textContent = 'Cerrar Caso';
                btnCerrar.addEventListener('click', () => cerrarIncidente(inc.id));
                actionsDiv.appendChild(btnCerrar);
            }

            container.appendChild(card);
        });

    } catch (error) {
        container.innerHTML = `<p class="text-center" style="color: var(--color-error);">Error al cargar incidentes: ${error.message}</p>`;
    }
}

async function tomarIncidente(id) {
    try {
        await fetchAPI(`/notificaciones/incidentes/${id}/tomar`, { method: 'PATCH' });
        await cargarIncidentes();
    } catch (error) {
        alert('Error: ' + error.message);
    }
}

async function cerrarIncidente(id) {
    const notas = prompt('Notas de resolución (opcional):') || null;
    try {
        await fetchAPI(`/notificaciones/incidentes/${id}/cerrar`, {
            method: 'PATCH',
            body: JSON.stringify({ notas })
        });
        await cargarIncidentes();
    } catch (error) {
        alert('Error: ' + error.message);
    }
}

async function cargarNotificaciones() {
    const container = document.getElementById('notifications-container');
    
    try {
        const notificaciones = await fetchAPI('/notificaciones');
        
        if (!notificaciones || notificaciones.length === 0) {
            container.innerHTML = '<p class="text-center text-mutted">No tienes notificaciones por ahora.</p>';
            return;
        }

        container.innerHTML = '';
        notificaciones.forEach(notif => {
            const isUnread = !notif.read;
            const dateStr = new Date(notif.dateTime).toLocaleString();
            
            const card = document.createElement('div');
            card.className = `notification-card ${isUnread ? 'unread' : ''}`;
            
            card.innerHTML = `
                <div style="flex: 1;">
                    <p style="margin: 0; font-size: 14px; font-weight: ${isUnread ? '600' : '400'}; color: var(--color-text-main);">
                        ${notif.message}
                    </p>
                    <p style="margin: 4px 0 0 0; font-size: 12px; color: var(--color-text-mutted);">
                        ${dateStr}
                    </p>
                </div>
                ${isUnread ? `
                <button class="btn-primary" style="padding: 4px 12px; font-size: 12px; margin-left: 12px;" onclick="marcarLeida(${notif.id}, this)">
                    Marcar leída
                </button>
                ` : ''}
            `;
            container.appendChild(card);
        });

    } catch (error) {
        container.innerHTML = `<p class="text-center" style="color: var(--color-error);">Error al cargar notificaciones: ${error.message}</p>`;
    }
}

async function marcarLeida(id, btnElement) {
    try {
        await fetchAPI(`/notificaciones/${id}/leer`, { method: 'PUT' });
        const card = btnElement.closest('.notification-card');
        card.classList.remove('unread');
        
        // Cambiar peso de la fuente
        const textP = card.querySelector('div > p:first-child');
        textP.style.fontWeight = '400';
        
        btnElement.remove(); // Quitar el botón
    } catch (error) {
        alert('Error: ' + error.message);
    }
}
