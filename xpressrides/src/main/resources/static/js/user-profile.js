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

    // 5. Mostrar saldo directamente desde el objeto del usuario en LocalStorage
    //    No hacemos llamada al backend; usamos el dato guardado en la sesión.
    const walletAmount = document.getElementById('wallet-amount');
    if (walletAmount) {
        const saldo = usuario.saldoUsd != null ? Number(usuario.saldoUsd) : 0;
        walletAmount.innerText = `$${saldo.toFixed(2)}`;
    }
}