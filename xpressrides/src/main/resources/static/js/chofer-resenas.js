document.addEventListener('DOMContentLoaded', async () => {
    if (!requireAuth()) return;
    await cargarResenas();
});

async function cargarResenas() {
    const container = document.getElementById('reviews-container');
    
    try {
        const response = await fetchAPI('/chofer/resenas');
        const resenas = response.data || response;
        
        if (!resenas || resenas.length === 0) {
            container.innerHTML = '<p class="text-center text-muted mt-lg">No has recibido ninguna reseña aún.</p>';
            return;
        }

        container.innerHTML = '';
        
        resenas.forEach(resena => {
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
            const customerName = resena.customerName || 'Desconocido';

            const html = `
                <div class="review-card">
                    <div class="d-flex justify-between align-center mb-sm">
                        <span style="font-weight: 600;">De: ${customerName}</span>
                        <span style="font-size: 12px; color: var(--color-text-muted);">${timeStr}</span>
                    </div>
                    <div class="stars mb-sm">${starsHtml}</div>
                    <p style="font-size: 14px; margin: 0;">${comment}</p>
                </div>
            `;
            container.insertAdjacentHTML('beforeend', html);
        });

    } catch (err) {
        container.innerHTML = `<p class="text-center text-error mt-lg">Error al cargar reseñas: ${err.message}</p>`;
    }
}
