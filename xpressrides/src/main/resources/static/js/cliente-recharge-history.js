// cliente-recharge-history.js — Historial de recargas del cliente
// Consume GET /api/recargas/cliente/{id} y renderiza tarjetas dinámicas.

document.addEventListener('DOMContentLoaded', async () => {
    if (!requireAuth()) return;

    const usuario = getUsuario();
    await cargarHistorialRecargas(usuario);
});

/**
 * Carga los bancos y las recargas del cliente, luego renderiza las cards.
 */
async function cargarHistorialRecargas(usuario) {
    const container = document.getElementById('recharges-container');
    if (!container) return;

    // Mostramos estado de carga
    container.innerHTML = '<p class="text-center mt-md" style="color: var(--color-text-muted);">Cargando tu historial de recargas...</p>';

    try {
        // Cargamos bancos en paralelo para resolver bankId → nombre
        let bancos = {};
        try {
            const resBancos = await fetchAPI('/bancos');
            (resBancos.data || []).forEach(b => {
                bancos[b.id] = b.name;
            });
        } catch (e) {
            console.warn('No se pudieron cargar los bancos:', e.message);
        }

        // Cargar recargas del cliente
        const response = await fetchAPI(`/cliente/recargas`);
        const recargas = Array.isArray(response) ? response : (response.data || []);

        if (recargas.length === 0) {
            container.innerHTML = `
                <div style="text-align: center; padding: 40px 20px; color: var(--color-text-muted);">
                    <svg width="48" height="48" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" style="margin-bottom: 12px; opacity: 0.5;">
                        <path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"></path>
                        <polyline points="7 10 12 15 17 10"></polyline>
                        <line x1="12" y1="15" x2="12" y2="3"></line>
                    </svg>
                    <p style="font-weight: 600; margin-bottom: 4px;">Sin recargas aún</p>
                    <p style="font-size: 13px;">Cuando recargues saldo, tu historial aparecerá aquí.</p>
                </div>
            `;
            return;
        }

        // Renderizar cards dinámicamente
        container.innerHTML = '';
        recargas.forEach(recarga => {
            // Resolver nombre del banco
            const nombreBanco = bancos[recarga.bankId] || `Banco #${recarga.bankId || '—'}`;

            // Formatear fecha
            const fecha = new Date(recarga.dateTime);
            const fechaStr = fecha.toLocaleDateString('es-VE', {
                day: '2-digit', month: 'short', year: 'numeric'
            });

            // Formatear monto
            const montoUsd = recarga.amountUsd != null ? Number(recarga.amountUsd).toFixed(2) : '0.00';

            const cardHTML = `
                <div class="recharge-card">
                    <div class="recharge-icon">
                        <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                            <line x1="12" y1="5" x2="12" y2="19"></line>
                            <line x1="5" y1="12" x2="19" y2="12"></line>
                        </svg>
                    </div>
                    <div class="recharge-details">
                        <div class="recharge-bank">${nombreBanco}</div>
                        <div class="recharge-ref">Ref: ${recarga.reference || '—'}</div>
                    </div>
                    <div class="recharge-amount">
                        <div class="recharge-usd">+$ ${montoUsd}</div>
                        <div class="recharge-date">${fechaStr}</div>
                    </div>
                </div>
            `;
            container.innerHTML += cardHTML;
        });

    } catch (error) {
        console.error('Error cargando historial de recargas:', error);
        container.innerHTML = `
            <div class="alert-error" style="text-align: center;">
                No pudimos cargar tu historial de recargas: ${error.message}
            </div>
        `;
    }
}
