// js/chofer-dashboard.js
// Carga los datos del chofer desde localStorage y maneja el panel

document.addEventListener('DOMContentLoaded', () => {
    if (!requireAuth()) return;
    cargarDatosChofer();
    configurarToggle();
    configurarBalance();
});

function requireAuth() {
    const usuario = localStorage.getItem('xpressUsuario');
    if (!usuario) {
        window.location.href = '../views/login.html';
        return false;
    }
    return true;
}

function cargarDatosChofer() {
    const usuario = JSON.parse(localStorage.getItem('xpressUsuario'));

    const driverName = document.getElementById('driver-name');
    const driverAvatar = document.getElementById('driver-avatar');
    const driverBalance = document.getElementById('driver-balance');
    const statusText = document.getElementById('status-text');
    const toggleInput = document.getElementById('availability-toggle');

    if (driverName) {
        const nombre = usuario.nombre || '';
        const apellido = usuario.apellido || '';
        driverName.innerText = `${nombre} ${apellido}`.trim() || 'Chofer';
    }

    if (driverAvatar) {
        const inicial1 = usuario.nombre ? usuario.nombre.charAt(0) : '';
        const inicial2 = usuario.apellido ? usuario.apellido.charAt(0) : '';
        driverAvatar.innerText = `${inicial1}${inicial2}`.toUpperCase() || 'CH';
    }

    if (driverBalance) {
        const saldo = usuario.saldoUsd != null ? Number(usuario.saldoUsd) : 0;
        driverBalance.innerText = `$${saldo.toFixed(2)}`;
    }

    if (toggleInput && statusText) {
        const disponible = usuario.disponible === true || usuario.disponible === 'true';
        toggleInput.checked = disponible;
        statusText.textContent = disponible ? 'En línea' : 'Inactivo';
        statusText.classList.toggle('offline', !disponible);
    }

    // Calificación (hardcoded por ahora, sin backend)
    const driverRating = document.getElementById('driver-rating');
    if (driverRating) {
        driverRating.innerText = '5.00 ★';
    }

    // Actualizar con datos reales del backend
    actualizarDatosBackendChofer(usuario, driverBalance);
}

async function actualizarDatosBackendChofer(usuario, driverBalance) {
    try {
        const response = await fetchAPI('/chofer/perfil');
        if (response) {
            // Actualizar localstorage con los nuevos datos
            const updatedUser = { ...usuario, ...response };
            // Aseguramos mantener la propiedad saldoUsd para no romper otra logica
            if (response.saldoAcumuladoUsd !== undefined) {
                updatedUser.saldoUsd = response.saldoAcumuladoUsd;
            }
            
            localStorage.setItem('xpressUsuario', JSON.stringify(updatedUser));
            
            if (driverBalance) {
                const saldo = updatedUser.saldoUsd != null ? Number(updatedUser.saldoUsd) : 0;
                driverBalance.innerText = `$${saldo.toFixed(2)}`;
            }

            // Actualizar toggle switch UI
            if (response.available !== undefined) {
                updatedUser.disponible = response.available;
                localStorage.setItem('xpressUsuario', JSON.stringify(updatedUser));

                const toggleInput = document.getElementById('availability-toggle');
                const statusText = document.getElementById('status-text');
                if (toggleInput && statusText) {
                    toggleInput.checked = response.available;
                    statusText.textContent = response.available ? 'En línea' : 'Inactivo';
                    statusText.classList.toggle('offline', !response.available);
                }
            }
        }
    } catch (e) {
        console.error("Error actualizando perfil del chofer desde backend:", e);
    }
}

function configurarToggle() {
    const toggleInput = document.getElementById('availability-toggle');
    const statusText = document.getElementById('status-text');

    if (!toggleInput || !statusText) return;

    toggleInput.addEventListener('change', function() {
        const disponible = this.checked;
        statusText.textContent = disponible ? 'En línea' : 'Inactivo';
        statusText.classList.toggle('offline', !disponible);

        // Actualizar en localStorage
        try {
            const usuario = JSON.parse(localStorage.getItem('xpressUsuario'));
            usuario.disponible = disponible;
            localStorage.setItem('xpressUsuario', JSON.stringify(usuario));
        } catch (e) {
            console.warn('Error actualizando localStorage:', e);
        }

        fetchAPI('/chofer/disponibilidad', {
            method: 'PUT',
            body: JSON.stringify({ available: disponible })
        }).catch(err => console.warn('Error actualizando disponibilidad:', err));
    });
}

function configurarBalance() {
    const btnShowBalance = document.getElementById('btn-show-balance');
    const balanceDisplay = document.getElementById('balance-display');

    if (!btnShowBalance || !balanceDisplay) return;

    btnShowBalance.addEventListener('click', function() {
        if (balanceDisplay.classList.contains('hidden')) {
            balanceDisplay.classList.remove('hidden');
            btnShowBalance.textContent = 'Ocultar Saldo';
        } else {
            balanceDisplay.classList.add('hidden');
            btnShowBalance.textContent = 'Ver Saldo Acumulado';
        }
    });
}