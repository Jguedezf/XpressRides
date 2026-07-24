// js/user-profile.js
// Carga el perfil del usuario (nombre, avatar, badge de estudiante y saldo)

document.addEventListener('DOMContentLoaded', () => {
    cargarPerfil();
});

function cargarPerfil() {
    // 1. Obtener datos de la sesión desde LocalStorage
    const usuarioString = localStorage.getItem('xpressUsuario');
    if (!usuarioString) {
        window.location.href = '../views/login.html';
        return;
    }

    const usuario = JSON.parse(usuarioString);

    // 2. Pintar nombre completo
    const profileName = document.getElementById('profile-name');
    if (profileName) {
        const nombre = usuario.nombre || '';
        const apellido = usuario.apellido || '';
        profileName.innerText = `${nombre} ${apellido}`.trim() || 'Usuario';
    }

    // Renderizar Navegación Dinámica ahora se maneja globalmente en topbar.js
    
    // Ajustar barra de navegación inferior
    const bottomNav = document.querySelector('.bottom-nav');
    if (bottomNav) {
        if (usuario.rol && usuario.rol.toLowerCase() === 'chofer') {
            bottomNav.innerHTML = `
                <a href="../views/chofer-dashboard.html" class="bottom-nav-item">
                    <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M3 9l9-7 9 7v11a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z"></path><polyline points="9 22 9 12 15 12 15 22"></polyline></svg>
                    <span class="mt-xs">Inicio</span>
                </a>
                <a href="../views/user-profile.html" class="bottom-nav-item active">
                    <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2"></path><circle cx="12" cy="7" r="4"></circle></svg>
                    <span class="mt-xs">Perfil</span>
                </a>
            `;
        }
    }

    // 3. Crear avatar con iniciales (Ej: Freddy Salazar → FS)
    const profileAvatar = document.getElementById('profile-avatar');
    if (profileAvatar) {
        const inicial1 = usuario.nombre ? usuario.nombre.charAt(0) : '';
        const inicial2 = usuario.apellido ? usuario.apellido.charAt(0) : '';
        profileAvatar.innerText = `${inicial1}${inicial2}`.toUpperCase() || '??';
    }

    // 4. Mostrar badge si es estudiante UNEG
    const profileBadge = document.getElementById('profile-badge');
    if (profileBadge) {
        if (usuario.esEstudiante) {
            profileBadge.innerText = 'Estudiante UNEG';
            profileBadge.style.display = 'inline-block';
        } else {
            profileBadge.style.display = 'none';
        }
    }

    // 5. Mostrar saldo directamente desde el objeto del usuario en LocalStorage (Fallback rápido)
    const walletAmount = document.getElementById('wallet-amount');
    if (walletAmount) {
        const saldo = usuario.saldoUsd != null ? Number(usuario.saldoUsd) : 0;
        walletAmount.innerText = `$${saldo.toFixed(2)}`;
    }

    // 6. Actualizar con datos reales del backend
    actualizarDatosBackend(usuario, walletAmount);
}

async function actualizarDatosBackend(usuario, walletAmount) {
    try {
        const endpoint = usuario.rol.toLowerCase() === 'chofer' ? '/chofer/perfil' : '/cliente/perfil';
        const response = await fetchAPI(endpoint);
        
        if (response) {
            // El backend del chofer devuelve {success: true, data: {...}}, mientras que el cliente devuelve el objeto directo
            const profileData = response.data ? response.data : response;

            // Actualizar localstorage con los nuevos datos
            const updatedUser = { ...usuario, ...profileData };
            // El backend devuelve saldoUsd para cliente, o saldoAcumuladoUsd para chofer.
            // Aseguramos que se guarde en saldoUsd para mantener compatibilidad
            if (profileData.saldoAcumuladoUsd !== undefined) {
                updatedUser.saldoUsd = profileData.saldoAcumuladoUsd;
            } else if (profileData.balance !== undefined) {
                updatedUser.saldoUsd = profileData.balance;
            } else if (profileData.saldoUsd !== undefined) {
                updatedUser.saldoUsd = profileData.saldoUsd;
            }
            
            localStorage.setItem('xpressUsuario', JSON.stringify(updatedUser));

            // Actualizar UI
            if (walletAmount) {
                const saldo = updatedUser.saldoUsd != null ? Number(updatedUser.saldoUsd) : 0;
                walletAmount.innerText = `$${saldo.toFixed(2)}`;
            }

            // Sección de Referidos: solo aplica para clientes (el chofer no tiene
            // estos campos en su respuesta de perfil, renderizarReferidos no falla
            // si vienen undefined, simplemente los deja en sus valores por defecto)
            renderizarReferidos(profileData);
        }
    } catch (e) {
        console.error("Error actualizando perfil desde el backend:", e);
    }
}

// ─────────────────────────────────────────────────────────
// Programa de Referidos
// ─────────────────────────────────────────────────────────

function renderizarReferidos(profileData) {
    const codigoEl = document.getElementById('referido-codigo');
    if (codigoEl) codigoEl.textContent = profileData.codigoReferido || '------';

    // El botón arranca disabled en el HTML (ver user-profile.html) para que un clic antes
    // de que este fetch resuelva no quede en silencio (compartirCodigoReferido ya se
    // protegía contra el placeholder "------", pero al usuario no le llegaba ninguna señal).
    const btnCompartir = document.getElementById('btn-compartir-referido');
    if (btnCompartir) btnCompartir.disabled = !profileData.codigoReferido;

    const disponiblesEl = document.getElementById('referido-cupones-disponibles');
    if (disponiblesEl) disponiblesEl.textContent = profileData.cuponesDisponibles != null ? profileData.cuponesDisponibles : 0;

    const historialContainer = document.getElementById('referido-historial-container');
    const historialLista = document.getElementById('referido-historial-lista');
    const historial = profileData.historialCuponesUsados || [];
    if (historialContainer && historialLista) {
        if (historial.length > 0) {
            historialContainer.style.display = 'block';
            historialLista.innerHTML = historial.map((h) => `
                <div class="d-flex justify-between text-small" style="padding: 6px 0; border-bottom: 1px solid #f0f0f0;">
                    <span>${h.codigo} — $${Number(h.montoUsd || 0).toFixed(2)}</span>
                    <span style="color: var(--color-text-muted);">${h.fechaUso ? new Date(h.fechaUso).toLocaleDateString() : ''}</span>
                </div>
            `).join('');
        } else {
            historialContainer.style.display = 'none';
        }
    }

    // El backend ya decidió si corresponde mostrar el campo (puedeAgregarReferido);
    // el frontend no recalcula fechas ni ventanas de tiempo, solo obedece el flag.
    const agregarContainer = document.getElementById('agregar-referido-container');
    if (agregarContainer) {
        if (profileData.puedeAgregarReferido) {
            agregarContainer.style.display = 'block';
            const horasEl = document.getElementById('referido-horas-restantes');
            if (horasEl) {
                const horas = profileData.horasRestantesReferido;
                horasEl.textContent = horas != null ? `${horas}h` : '';
            }
        } else {
            agregarContainer.style.display = 'none';
        }
    }
}

window.compartirCodigoReferido = async function () {
    const codigoEl = document.getElementById('referido-codigo');
    const codigo = codigoEl ? codigoEl.textContent.trim() : '';
    if (!codigo || codigo === '------') return;

    const texto = `Únete a XpressRides con mi código de referido ${codigo} y ambos ganamos beneficios.`;

    if (navigator.share) {
        try {
            await navigator.share({ title: 'XpressRides', text: texto });
        } catch (err) {
            // El usuario cerró el panel nativo de compartir sin elegir nada — no es un error real
        }
        return;
    }

    if (navigator.clipboard) {
        try {
            await navigator.clipboard.writeText(codigo);
            alert('Código copiado al portapapeles: ' + codigo);
            return;
        } catch (err) {
            // sigue al fallback de abajo
        }
    }

    alert('Tu código de referido es: ' + codigo);
};

window.agregarCodigoReferido = async function () {
    const input = document.getElementById('input-codigo-referido');
    if (!input || !input.value.trim()) return;

    try {
        await fetchAPI('/cliente/perfil/referido', {
            method: 'PUT',
            body: JSON.stringify({ codigoReferido: input.value.trim() })
        });
        alert('Código de referido agregado correctamente.');
        input.value = '';
        cargarPerfil();
    } catch (err) {
        alert('Error: ' + err.message);
    }
};