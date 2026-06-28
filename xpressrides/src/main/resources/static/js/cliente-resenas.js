let resenasCompletas = [];

document.addEventListener('DOMContentLoaded', async () => {
    if (!requireAuth()) return;
    await cargarResenas();
});

async function cargarResenas() {
    const container = document.getElementById('reviews-container');
    
    try {
        const urlParams = new URLSearchParams(window.location.search);
        const tripIdFilter = urlParams.get('tripId');

        const response = await fetchAPI('/cliente/resenas');
        resenasCompletas = response.data || response;
        
        let resenasAMostrar = resenasCompletas;
        if (tripIdFilter) {
            resenasAMostrar = resenasCompletas.filter(r => r.tripId == tripIdFilter);
        }
        
        if (!resenasAMostrar || resenasAMostrar.length === 0) {
            container.innerHTML = '<p class="text-center text-muted mt-lg">No se encontraron reseñas.</p>';
            return;
        }

        container.innerHTML = '';
        
        resenasAMostrar.forEach((resena, index) => {
            let timeStr = resena.date || '';
            if (timeStr) {
                const d = new Date(timeStr);
                timeStr = d.toLocaleDateString() + ' ' + d.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
            }

            const stars = parseInt(resena.starRating) || 0;
            let starsHtml = '';
            for(let i=0; i<5; i++) {
                if (i < stars) starsHtml += '★';
                else starsHtml += '☆';
            }

            const comment = resena.comment || '<span class="text-muted">Sin comentario</span>';
            const driverName = resena.driverName || 'Desconocido';
            const route = resena.route || 'Ruta Desconocida';

            const html = `
                <div class="review-card">
                    <div class="d-flex justify-between align-center mb-sm">
                        <span style="font-weight: 600; font-size: 14px;">${route}</span>
                        <span style="font-size: 12px; color: var(--color-text-muted);">${timeStr}</span>
                    </div>
                    <div class="d-flex justify-between align-center mb-sm">
                        <span style="font-size: 14px; color: var(--color-text-muted);">Chofer: ${driverName}</span>
                    </div>
                    <div class="stars mb-sm">${starsHtml}</div>
                    <p style="font-size: 14px; margin: 0; margin-bottom: 15px;">${comment}</p>
                    <button class="btn-secondary" style="padding: 6px 12px; font-size: 12px; width: auto;" onclick="abrirModalChofer(${index})">Ver Detalles del Chofer</button>
                </div>
            `;
            container.insertAdjacentHTML('beforeend', html);
        });

    } catch (err) {
        container.innerHTML = `<p class="text-center text-error mt-lg">Error al cargar reseñas: ${err.message}</p>`;
    }
}

function abrirModalChofer(index) {
    const resena = resenasCompletas[index];
    if (!resena) return;
    
    document.getElementById('detalle-modal-chofer-nombre').textContent = resena.driverName || 'Desconocido';
    document.getElementById('detalle-modal-chofer-telefono').textContent = resena.driverPhone || '—';
    
    const partes = (resena.driverName || '').split(' ');
    document.getElementById('detalle-modal-chofer-iniciales').textContent = ((partes[0]?.[0] || '') + (partes[1]?.[0] || '')).toUpperCase() || 'CH';

    const tel = (resena.driverPhone || '').replace(/\D/g, '');
    const waBtn = document.getElementById('detalle-modal-chofer-whatsapp');
    if (tel) {
        waBtn.href = `https://wa.me/${tel.startsWith('58') ? tel : '58' + tel}`;
        waBtn.style.display = 'flex';
    } else {
        waBtn.style.display = 'none';
    }

    if (resena.vehicle) {
        document.getElementById('detalle-modal-vehiculo-modelo').textContent = `${resena.vehicle.brand || ''} ${resena.vehicle.model || ''}`.trim() || '—';
        document.getElementById('detalle-modal-vehiculo-color').textContent = resena.vehicle.color || '—';
        document.getElementById('detalle-modal-vehiculo-placa').textContent = resena.vehicle.plate || '—';
        document.getElementById('detalle-modal-vehiculo-revision').textContent = resena.vehicle.inspection || '—';
    } else {
        document.getElementById('detalle-modal-vehiculo-modelo').textContent = '—';
        document.getElementById('detalle-modal-vehiculo-color').textContent = '—';
        document.getElementById('detalle-modal-vehiculo-placa').textContent = '—';
        document.getElementById('detalle-modal-vehiculo-revision').textContent = '—';
    }
    
    if (resena.driverDetails) {
        document.getElementById('detalle-modal-chofer-psicologica').textContent = resena.driverDetails.psychEval || '—';
    } else {
        document.getElementById('detalle-modal-chofer-psicologica').textContent = '—';
    }

    document.getElementById('modal-detalles-chofer').style.display = 'flex';
}

function cerrarModalChofer() {
    document.getElementById('modal-detalles-chofer').style.display = 'none';
}
