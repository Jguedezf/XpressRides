document.addEventListener('DOMContentLoaded', async () => {
    // Proteger ruta
    if (!requireAuth()) return;
    await cargarNotificaciones();
});

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
