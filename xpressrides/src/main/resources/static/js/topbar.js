// js/topbar.js — Lógica para la barra superior (Tasa BCV y Perfil de Usuario)
// Este script asume que api.js ya ha sido cargado.

document.addEventListener('DOMContentLoaded', () => {
    populateTopbarUser();
    loadTopbarBcvRate();
});

/**
 * Obtiene el usuario de localStorage (vía api.js) y puebla el dropdown del topbar.
 */
function populateTopbarUser() {
    const user = getUsuario();
    if (!user) return;
    
    const initial = document.getElementById('topbar-user-initial');
    const name = document.getElementById('topbar-user-name');
    const role = document.getElementById('topbar-user-role');
    const userRole = (user.rol || user.role || '').toLowerCase();

    if (initial && user.nombre) {
        initial.textContent = user.nombre.charAt(0).toUpperCase();
        if (userRole === 'chofer') {
            initial.style.backgroundColor = 'var(--color-secondary)';
        } else if (userRole === 'personal_admin' || userRole === 'admin' || userRole === 'administrador') {
            initial.style.backgroundColor = '#6A0DAD'; // Púrpura para administradores
        } else {
            initial.style.backgroundColor = 'var(--color-primary)';
        }
    }
    if (name) {
        name.textContent = user.nombre || 'Usuario';
    }
    if (role) {
        let roleStr = user.rol || 'Rol';
        // Limpiar el rol para mostrarlo más amigable y configurar el enlace del perfil
        const profileLink = document.querySelector('#topbar-profile-dropdown a');
        if (userRole === 'personal_admin' || userRole === 'admin' || userRole === 'administrador') {
            roleStr = 'Administrador';
            if (profileLink) profileLink.style.display = 'none';
        } else {
            if (userRole === 'chofer') {
                if (profileLink) profileLink.href = '../views/chofer-dashboard.html';
            }
            // Add logout link if it doesn't exist
            const dropdown = document.getElementById('topbar-profile-dropdown');
            if (dropdown && !document.getElementById('topbar-logout-link')) {
                const logoutLink = document.createElement('a');
                logoutLink.id = 'topbar-logout-link';
                logoutLink.href = '../views/user-logout.html';
                logoutLink.style.cssText = 'font-size:13px; color:var(--color-error); text-decoration:none; display:block; padding:4px 0; margin-top:4px;';
                logoutLink.textContent = 'Cerrar sesión';
                dropdown.appendChild(logoutLink);
            }
        }
        role.textContent = roleStr;
    }

    // Renderizar Navegación Dinámica Global si existe el contenedor
    const dynamicNav = document.getElementById('dynamic-desktop-nav');
    if (dynamicNav) {
        if (userRole === 'chofer') {
            dynamicNav.innerHTML = `
                <a href="../views/chofer-viaje.html">Inicio</a>
                <a href="../views/chofer-travel-history.html">Mis Viajes</a>
                <a href="../views/chofer-resenas.html">Mis Reseñas</a>
            `;
        } else if (userRole === 'cliente') {
            dynamicNav.innerHTML = `
                <a href="../views/cliente-dashboard.html">Inicio</a>
                <a href="../views/cliente-record.html">Historial de Viajes</a>
                <a href="../views/cliente-resenas.html">Mis Reseñas</a>
            `;
        }
    }
}

/**
 * Carga la tasa BCV vigente desde el backend y la muestra en el topbar.
 */
async function loadTopbarBcvRate() {
    const span = document.getElementById('topbar-bcv-rate');
    if (!span) return;

    // Ocultar la tasa BCV si es administrador
    const user = typeof getUsuario === 'function' ? getUsuario() : null;
    if (user) {
        const userRole = (user.rol || user.role || '').toLowerCase();
        if (userRole === 'personal_admin' || userRole === 'admin' || userRole === 'administrador') {
            span.style.display = 'none';
            return;
        }
    }
    
    try {
        const response = await fetchAPI('/tasa-bcv/vigente');
        if (response && response.success && response.data) {
            span.textContent = `Tasa BCV: ${response.data.rateVes} VES`;
            span.style.display = 'inline-block';
        }
    } catch(e) {
        console.error('Error al cargar la tasa BCV para el topbar', e);
        // Ocultar si hay error o no hay tasa
        span.style.display = 'none';
    }
}

/**
 * Alterna la visibilidad del menú desplegable del perfil.
 */
window.toggleProfileDropdown = function() {
    const dropdown = document.getElementById('topbar-profile-dropdown');
    if (dropdown) {
        dropdown.style.display = dropdown.style.display === 'none' ? 'block' : 'none';
    }
};

/**
 * Cierra el menú desplegable si se hace click en otro lugar de la pantalla.
 */
document.addEventListener('click', (e) => {
    const widget = document.querySelector('.user-profile-widget');
    const dropdown = document.getElementById('topbar-profile-dropdown');
    if (widget && dropdown && !widget.contains(e.target)) {
        dropdown.style.display = 'none';
    }
});
