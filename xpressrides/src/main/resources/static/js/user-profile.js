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
            // Actualizar localstorage con los nuevos datos
            const updatedUser = { ...usuario, ...response };
            // El backend devuelve saldoUsd para cliente, o saldoAcumuladoUsd para chofer.
            // Aseguramos que se guarde en saldoUsd para mantener compatibilidad
            if (response.saldoAcumuladoUsd !== undefined) {
                updatedUser.saldoUsd = response.saldoAcumuladoUsd;
            } else if (response.balance !== undefined) {
                updatedUser.saldoUsd = response.balance;
            } else if (response.saldoUsd !== undefined) {
                updatedUser.saldoUsd = response.saldoUsd;
            }
            
            localStorage.setItem('xpressUsuario', JSON.stringify(updatedUser));
            
            // Actualizar UI
            if (walletAmount) {
                const saldo = updatedUser.saldoUsd != null ? Number(updatedUser.saldoUsd) : 0;
                walletAmount.innerText = `$${saldo.toFixed(2)}`;
            }
        }
    } catch (e) {
        console.error("Error actualizando perfil desde el backend:", e);
    }
}