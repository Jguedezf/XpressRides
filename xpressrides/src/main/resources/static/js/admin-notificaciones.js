document.addEventListener('DOMContentLoaded', async () => {
    // Proteger ruta
    if (!requireAuth()) return;
    await cargarNotificaciones();
    await cargarIncidentes();
});

let todosIncidentes = [];
let todasNotificaciones = [];
let incidentesFiltrados = [];
let notificacionesFiltradas = [];

const PAGE_SIZE = 10;
let currentPageIncidentes = 1;
let currentPageNotificaciones = 1;

function renderPaginatedTable(data, currentPage, containerId, paginationId, pageInfoId, renderItemFn) {
    const container = document.getElementById(containerId);
    const paginationDiv = document.getElementById(paginationId);
    const pageInfo = document.getElementById(pageInfoId);
    
    if (data.length === 0) {
        paginationDiv.style.display = 'none';
        return;
    }

    const totalPages = Math.ceil(data.length / PAGE_SIZE);
    
    if (currentPage < 1) currentPage = 1;
    if (currentPage > totalPages) currentPage = totalPages;

    const startIdx = (currentPage - 1) * PAGE_SIZE;
    const endIdx = startIdx + PAGE_SIZE;
    const pageData = data.slice(startIdx, endIdx);

    container.innerHTML = '';
    pageData.forEach(renderItemFn);

    paginationDiv.style.display = 'flex';
    pageInfo.innerText = `Página ${currentPage} de ${totalPages}`;
    
    const baseName = containerId.split('-')[0]; // incidents or notifications
    const suffix = baseName === 'incidents' ? 'incidentes' : 'notificaciones';
    const btnPrev = document.getElementById(`btn-prev-${suffix}`);
    const btnNext = document.getElementById(`btn-next-${suffix}`);
    
    btnPrev.disabled = currentPage === 1;
    btnNext.disabled = currentPage === totalPages;
}

const ESTADO_INCIDENTE_TEXTO = { abierto: 'Abierto', en_proceso: 'En Proceso', cerrado: 'Cerrado' };

async function cargarIncidentes() {
    const container = document.getElementById('incidents-container');

    try {
        const response = await fetchAPI('/notificaciones/incidentes');
        todosIncidentes = response.data || [];
        filtrarIncidentes();
    } catch (error) {
        container.innerHTML = `<p class="text-center" style="color: var(--color-error);">Error al cargar incidentes: ${error.message}</p>`;
    }
}

function filtrarIncidentes() {
    const filtroEstado = document.getElementById('filtro-incidentes').value;
    if (filtroEstado === 'todos') {
        incidentesFiltrados = [...todosIncidentes];
    } else {
        incidentesFiltrados = todosIncidentes.filter(inc => inc.status === filtroEstado);
    }

    const container = document.getElementById('incidents-container');
    if (incidentesFiltrados.length === 0) {
        container.innerHTML = '<p class="text-center text-muted">No hay incidentes reportados con este filtro.</p>';
        document.getElementById('pagination-incidentes').style.display = 'none';
        return;
    }

    currentPageIncidentes = 1;
    renderPaginatedTable(incidentesFiltrados, currentPageIncidentes, 'incidents-container', 'pagination-incidentes', 'page-info-incidentes', renderRowIncidente);
}

document.getElementById('filtro-incidentes')?.addEventListener('change', filtrarIncidentes);

document.getElementById('btn-prev-incidentes').addEventListener('click', () => {
    if (currentPageIncidentes > 1) {
        currentPageIncidentes--;
        renderPaginatedTable(incidentesFiltrados, currentPageIncidentes, 'incidents-container', 'pagination-incidentes', 'page-info-incidentes', renderRowIncidente);
    }
});
document.getElementById('btn-next-incidentes').addEventListener('click', () => {
    const totalPages = Math.ceil(incidentesFiltrados.length / PAGE_SIZE);
    if (currentPageIncidentes < totalPages) {
        currentPageIncidentes++;
        renderPaginatedTable(incidentesFiltrados, currentPageIncidentes, 'incidents-container', 'pagination-incidentes', 'page-info-incidentes', renderRowIncidente);
    }
});

function renderRowIncidente(inc) {
    const container = document.getElementById('incidents-container');
    const dateStr = new Date(inc.createdAt).toLocaleString();
    const reportante = inc.reportedBy ? `${inc.reportedBy.name || ''} ${inc.reportedBy.lastName || ''}`.trim() : 'Desconocido';
    const phone = inc.reportedBy && inc.reportedBy.phone ? inc.reportedBy.phone : 'N/A';
    const email = inc.reportedBy && inc.reportedBy.email ? inc.reportedBy.email : 'N/A';

    let tripHtml = '';
    if (inc.trip) {
        const origen = inc.trip.originAddress || 'N/A';
        const destino = inc.trip.destinationAddress || 'N/A';
        const costo = inc.trip.customerCostUsd != null ? `$${inc.trip.customerCostUsd}` : 'N/A';
        
        let driverLocationHtml = '';
        if (inc.trip.driver && inc.trip.driver.latActual && inc.trip.driver.lngActual) {
            const lat = inc.trip.driver.latActual;
            const lng = inc.trip.driver.lngActual;
            driverLocationHtml = `<br><span style="color: var(--color-text-muted);">Ubicación Chofer:</span> <a href="https://www.google.com/maps?q=${lat},${lng}" target="_blank" style="color: var(--color-primary); font-weight: 600; text-decoration: none;">Ver en el Mapa 📍</a>`;
        }

        tripHtml = `
            <div style="margin-top: 8px; padding: 10px; background: #f0f0f0; border-radius: 6px; font-size: 13px;">
                <strong style="color: var(--color-primary);">Detalles del Viaje (#${inc.trip.id})</strong><br>
                <span style="color: var(--color-text-muted);">Origen:</span> ${origen}<br>
                <span style="color: var(--color-text-muted);">Destino:</span> ${destino}<br>
                <span style="color: var(--color-text-muted);">Costo:</span> ${costo}${driverLocationHtml}
            </div>
        `;
    }

    const card = document.createElement('div');
    card.className = 'incident-card';
    card.innerHTML = `
        <div style="display:flex; justify-content:space-between; align-items:flex-start; gap:12px;">
            <div style="flex:1;">
                <p style="margin:0; font-size:15px; font-weight:700; color: var(--color-error);">${inc.message}</p>
                <p style="margin:6px 0 0 0; font-size:13px; color: var(--color-text-main);">
                    <strong>Reportado por:</strong> ${reportante}<br>
                    <strong>Contacto:</strong> ${phone} | ${email}<br>
                    <strong>Fecha:</strong> ${dateStr}
                </p>
                ${tripHtml}
                ${inc.status === 'cerrado' && inc.resolutionNotes ? `<div style="margin-top:8px; padding:8px; background:#e8f5e9; border-left:3px solid #4caf50; font-size:13px;"><strong>Resolución:</strong> ${inc.resolutionNotes}</div>` : ''}
            </div>
            <span class="incident-badge badge-${inc.status}" style="font-size: 12px;">${ESTADO_INCIDENTE_TEXTO[inc.status] || inc.status}</span>
        </div>
        <div id="incident-actions-${inc.id}" style="margin-top:12px; display:flex; gap:8px;"></div>
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
        todasNotificaciones = notificaciones || [];
        notificacionesFiltradas = [...todasNotificaciones];
        
        renderizarNotificacionesActuales();

    } catch (error) {
        container.innerHTML = `<p class="text-center" style="color: var(--color-error);">Error al cargar notificaciones: ${error.message}</p>`;
    }
}

function renderizarNotificacionesActuales() {
    const container = document.getElementById('notifications-container');
    if (!notificacionesFiltradas || notificacionesFiltradas.length === 0) {
        container.innerHTML = '<p class="text-center text-muted">No tienes notificaciones por ahora.</p>';
        document.getElementById('pagination-notificaciones').style.display = 'none';
        return;
    }

    const totalPages = Math.ceil(notificacionesFiltradas.length / PAGE_SIZE);
    if (currentPageNotificaciones > totalPages) currentPageNotificaciones = totalPages;
    if (currentPageNotificaciones < 1) currentPageNotificaciones = 1;

    renderPaginatedTable(notificacionesFiltradas, currentPageNotificaciones, 'notifications-container', 'pagination-notificaciones', 'page-info-notificaciones', renderRowNotificacion);
}

function renderRowNotificacion(notif) {
    const container = document.getElementById('notifications-container');
    const isUnread = !notif.read;
    const dateStr = new Date(notif.dateTime).toLocaleString();
    
    const card = document.createElement('div');
    card.className = `notification-card ${isUnread ? 'unread' : ''}`;
    
    card.innerHTML = `
        <div style="width: 100%;">
            <p style="margin: 0; font-size: 14px; font-weight: ${isUnread ? '600' : '400'}; color: var(--color-text-main);">
                ${notif.message}
            </p>
            <p style="margin: 4px 0 0 0; font-size: 12px; color: var(--color-text-muted);">
                ${dateStr}
            </p>
        </div>
        ${isUnread ? `
        <button class="btn-primary" style="padding: 4px 12px; font-size: 12px; margin-top: 10px;" onclick="marcarLeida(${notif.id}, this)">
            Marcar leída
        </button>
        ` : ''}
    `;
    container.appendChild(card);
}

document.getElementById('btn-prev-notificaciones').addEventListener('click', () => {
    if (currentPageNotificaciones > 1) {
        currentPageNotificaciones--;
        renderizarNotificacionesActuales();
    }
});
document.getElementById('btn-next-notificaciones').addEventListener('click', () => {
    const totalPages = Math.ceil(notificacionesFiltradas.length / PAGE_SIZE);
    if (currentPageNotificaciones < totalPages) {
        currentPageNotificaciones++;
        renderizarNotificacionesActuales();
    }
});

document.getElementById('btn-limpiar-leidas')?.addEventListener('click', () => {
    notificacionesFiltradas = todasNotificaciones.filter(n => !n.read);
    renderizarNotificacionesActuales();
});

async function marcarLeida(id, btnElement) {
    try {
        await fetchAPI(`/notificaciones/${id}/leer`, { method: 'PUT' });
        
        const notifLocal = todasNotificaciones.find(n => n.id === id);
        if (notifLocal) notifLocal.read = true;
        
        const notifFilt = notificacionesFiltradas.find(n => n.id === id);
        if (notifFilt) notifFilt.read = true;
        
        const card = btnElement.closest('.notification-card');
        card.classList.remove('unread');
        
        const textP = card.querySelector('div > p:first-child');
        textP.style.fontWeight = '400';
        
        btnElement.remove();
    } catch (error) {
        alert('Error: ' + error.message);
    }
}
