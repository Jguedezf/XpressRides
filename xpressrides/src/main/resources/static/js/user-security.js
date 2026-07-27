document.addEventListener('DOMContentLoaded', () => {
    // Check authentication
    if (!requireAuth()) return;

    const usuario = getUsuario();
    if (!usuario) return;

    const formPassword = document.getElementById('form-cambiar-password');
    if (formPassword) {
        formPassword.addEventListener('submit', cambiarPassword);
    }
});

function volverAlPerfil() {
    const user = getUsuario();
    if (user && user.rol === 'chofer') {
        window.location.href = '/views/chofer-dashboard.html';
    } else {
        window.location.href = '/views/user-profile.html';
    }
}

function togglePasswordVisibility(inputId, iconId) {
    const input = document.getElementById(inputId);
    const icon = document.getElementById(iconId);
    if (input.type === 'password') {
        input.type = 'text';
        icon.classList.remove('fa-eye');
        icon.classList.add('fa-eye-slash');
    } else {
        input.type = 'password';
        icon.classList.remove('fa-eye-slash');
        icon.classList.add('fa-eye');
    }
}

async function cambiarPassword(e) {
    e.preventDefault();
    const currentPassword = document.getElementById('current-password').value;
    const newPassword = document.getElementById('new-password').value;

    const REGEX_PASSWORD = /^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[!@#$%^&*()_+\-=\[\]{};':"\\|,.<>\/?`~]).{8,}$/;

    if (!REGEX_PASSWORD.test(newPassword)) {
        alert('La nueva contraseña debe tener al menos 8 caracteres, una mayúscula, una minúscula, un número y un carácter especial.');
        return;
    }

    try {
        const response = await fetchAPI('/auth/cambiar-contrasena', {
            method: 'POST',
            body: JSON.stringify({ currentPassword, newPassword })
        });
        
        if (response && response.success) {
            alert('Contraseña actualizada correctamente. Deberás iniciar sesión nuevamente.');
            localStorage.removeItem('token');
            localStorage.removeItem('user');
            localStorage.removeItem('xpressUsuario');
            window.location.href = '/views/login.html';
        } else {
            alert(response?.message || 'Error al actualizar contraseña.');
        }
    } catch (error) {
        alert(error.message || 'Error de conexión.');
    }
}
