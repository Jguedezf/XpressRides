// js/cliente-cupones.js
// Lógica para la vista de Mis Cupones del cliente

document.addEventListener('DOMContentLoaded', () => {
    verificarSesion();
    inicializarTabs();
    cargarCupones();
});

function verificarSesion() {
    const usuario = localStorage.getItem('xpressUsuario');
    if (!usuario) {
        window.location.href = '../views/login.html';
        return;
    }
    const parsed = JSON.parse(usuario);
    if ((parsed.rol || '').toLowerCase() !== 'cliente') {
        window.location.href = '../views/login.html';
    }
}

function inicializarTabs() {
    const tabBtns = document.querySelectorAll('.tab-btn');
    tabBtns.forEach(btn => {
        btn.addEventListener('click', () => {
            tabBtns.forEach(b => b.classList.remove('active'));
            btn.classList.add('active');

            document.querySelectorAll('.tab-content').forEach(tc => tc.classList.remove('active'));
            const targetTab = document.getElementById('tab-' + btn.dataset.tab);
            if (targetTab) targetTab.classList.add('active');
        });
    });
}

async function cargarCupones() {
    try {
        const response = await fetchAPI('/cliente/cupones');

        // El endpoint puede devolver directamente el Map o envuelto en {success, data}
        const data = response.data ? response.data : response;
        const disponibles = data.disponibles || [];
        const usados = data.usados || [];

        // Actualizar contador
        const countEl = document.getElementById('coupons-count');
        if (countEl) countEl.textContent = disponibles.length;

        renderizarDisponibles(disponibles);
        renderizarUsados(usados);
    } catch (error) {
        console.error('Error cargando cupones:', error);
        document.getElementById('lista-cupones-disponibles').innerHTML = `
            <div class="empty-state">
                <div class="empty-state-icon">⚠️</div>
                <div class="empty-state-title">Error al cargar cupones</div>
                <div class="empty-state-desc">${error.message || 'Intenta recargar la página.'}</div>
            </div>
        `;
    }
}

function renderizarDisponibles(cupones) {
    const container = document.getElementById('lista-cupones-disponibles');
    if (!container) return;

    if (cupones.length === 0) {
        container.innerHTML = `
            <div class="empty-state">
                <div class="empty-state-icon">🎫</div>
                <div class="empty-state-title">No tienes cupones disponibles</div>
                <div class="empty-state-desc">Los cupones aparecerán aquí cuando recibas uno por referidos, promociones o bienvenida.</div>
            </div>
        `;
        return;
    }

    container.innerHTML = cupones.map(cc => {
        const cupon = cc.coupon || {};
        const tipo = cupon.type || 'promocional';
        const codigo = cupon.code || '---';
        const descuento = cupon.discountUsd != null ? Number(cupon.discountUsd) : 0;
        const distanciaMax = cupon.maxDistanceKm;
        const fechaCreacion = cc.createdAt ? new Date(cc.createdAt).toLocaleDateString('es-VE') : '';

        const tipoIcono = getTipoIcono(tipo);
        const tipoLabel = getTipoLabel(tipo);

        return `
            <div class="coupon-card">
                <div class="coupon-card-top">
                    <span class="coupon-type-badge ${tipo}">${tipoIcono} ${tipoLabel}</span>
                    <div class="coupon-code-container">
                        <span class="coupon-code">${codigo}</span>
                        <button class="copy-btn" onclick="copiarCodigo('${codigo}')" title="Copiar código">
                            <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                                <rect x="9" y="9" width="13" height="13" rx="2" ry="2"></rect>
                                <path d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1"></path>
                            </svg>
                        </button>
                    </div>
                </div>
                <div class="coupon-card-body">
                    <div class="coupon-discount">-$${descuento.toFixed(2)}</div>
                    <div class="coupon-detail">Descuento en tu próximo viaje</div>
                    ${fechaCreacion ? `<div class="coupon-detail">Recibido el ${fechaCreacion}</div>` : ''}
                </div>
                <div class="coupon-card-footer">
                    <div class="coupon-condition">
                        <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="10"></circle><line x1="12" y1="16" x2="12" y2="12"></line><line x1="12" y1="8" x2="12.01" y2="8"></line></svg>
                        ${distanciaMax ? `Hasta ${distanciaMax} km` : 'Sin límite de distancia'}
                    </div>
                    <button class="btn-usar-cupon" onclick="window.location.href='../views/cliente-dashboard.html'">
                        🚀 Usar en viaje
                    </button>
                </div>
            </div>
        `;
    }).join('');
}

function renderizarUsados(cupones) {
    const container = document.getElementById('lista-cupones-usados');
    if (!container) return;

    if (cupones.length === 0) {
        container.innerHTML = `
            <div class="empty-state">
                <div class="empty-state-icon">📜</div>
                <div class="empty-state-title">Sin historial de cupones</div>
                <div class="empty-state-desc">Los cupones que utilices aparecerán aquí.</div>
            </div>
        `;
        return;
    }

    container.innerHTML = cupones.map(cc => {
        const cupon = cc.coupon || {};
        const tipo = cupon.type || 'promocional';
        const codigo = cupon.code || '---';
        const descuento = cupon.discountUsd != null ? Number(cupon.discountUsd) : 0;
        const fechaUso = cc.usedDate ? new Date(cc.usedDate).toLocaleDateString('es-VE', {
            year: 'numeric', month: 'short', day: 'numeric'
        }) : 'Fecha desconocida';

        const tipoIcono = getTipoIcono(tipo);
        const tipoLabel = getTipoLabel(tipo);

        return `
            <div class="coupon-card used">
                <div class="coupon-card-top">
                    <span class="coupon-type-badge usado">✓ Usado</span>
                    <span class="coupon-type-badge ${tipo}" style="font-size:10px;">${tipoIcono} ${tipoLabel}</span>
                    <div class="coupon-code-container">
                        <span class="coupon-code" style="opacity:0.6;">${codigo}</span>
                    </div>
                </div>
                <div class="coupon-card-body">
                    <div class="coupon-discount">-$${descuento.toFixed(2)}</div>
                    <div class="coupon-used-date">Utilizado el ${fechaUso}</div>
                </div>
            </div>
        `;
    }).join('');
}

function getTipoIcono(tipo) {
    switch (tipo) {
        case 'referido': return '🤝';
        case 'bienvenida': return '👋';
        case 'promocional': return '🎉';
        case 'estudiante': return '🎓';
        default: return '🎫';
    }
}

function getTipoLabel(tipo) {
    switch (tipo) {
        case 'referido': return 'Referido';
        case 'bienvenida': return 'Bienvenida';
        case 'promocional': return 'Promoción';
        case 'estudiante': return 'Estudiante';
        default: return tipo;
    }
}

window.copiarCodigo = async function(codigo) {
    try {
        if (navigator.clipboard && navigator.clipboard.writeText) {
            await navigator.clipboard.writeText(codigo);
        } else {
            const textarea = document.createElement('textarea');
            textarea.value = codigo;
            textarea.style.position = 'fixed';
            textarea.style.opacity = '0';
            document.body.appendChild(textarea);
            textarea.focus();
            textarea.select();
            document.execCommand('copy');
            document.body.removeChild(textarea);
        }

        const toast = document.getElementById('toast-copy');
        if (toast) {
            toast.classList.add('show');
            setTimeout(() => toast.classList.remove('show'), 2000);
        }
    } catch (err) {
        console.error('Error copiando código:', err);
    }
};
