document.addEventListener('DOMContentLoaded', () => {
    // Prevent access if not logged in
    const user = getUsuario();
    if (!user) {
        window.location.href = '/views/login.html';
        return;
    }

    if (user.rol !== 'administrador' && user.rol !== 'personal_admin') {
        window.location.href = '/views/login.html';
        return;
    }

    cargarDatosPerfil(user);

    document.getElementById('admin-profile-form').addEventListener('submit', guardarPerfil);
});

function cargarDatosPerfil(user) {
    document.getElementById('admin-nombre').value = user.nombre || '';
    document.getElementById('admin-apellido').value = user.apellido || '';
    document.getElementById('admin-cedula').value = user.cedula || user.ci || '';
    document.getElementById('admin-telefono').value = user.telefono || '';
    document.getElementById('admin-correo').value = user.correo || '';
    
    document.getElementById('display-name').textContent = `${user.nombre} ${user.apellido}`;
    document.getElementById('display-role').textContent = user.rol;
    
    if (user.cargo) {
        const positionEl = document.getElementById('display-position');
        positionEl.textContent = user.cargo;
        positionEl.style.display = 'inline-block';
    }

    if (user.nombre && user.apellido) {
        const init1 = user.nombre.charAt(0).toUpperCase();
        const init2 = user.apellido.charAt(0).toUpperCase();
        document.getElementById('avatar-initials').textContent = init1 + init2;
    }
    
    // Add logic to get username
    document.getElementById('admin-username').value = user.username || '';
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

async function guardarPerfil(e) {
    e.preventDefault();
    const btn = document.getElementById('btn-save');
    const successAlert = document.getElementById('alert-success');
    const errorAlert = document.getElementById('alert-error');
    
    successAlert.style.display = 'none';
    errorAlert.style.display = 'none';
    
    const user = getUsuario();
    if (!user) return;

    const payload = {
        name: document.getElementById('admin-nombre').value.trim(),
        lastName: document.getElementById('admin-apellido').value.trim(),
        ci: document.getElementById('admin-cedula').value.trim(),
        phone: document.getElementById('admin-telefono').value.trim(),
        email: document.getElementById('admin-correo').value.trim(),
        username: document.getElementById('admin-username').value.trim()
    };
    
    const password = document.getElementById('admin-password').value;
    if (password) {
        payload.password = password;
    }

    const REGEX_PASSWORD = /^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[!@#$%^&*()_+\-=\[\]{};':"\\|,.<>\/?`~]).{8,}$/;
    const REGEX_USERNAME = /^[a-zA-Z0-9_]{5,}$/;

    if (!REGEX_USERNAME.test(payload.username)) {
        alert('El nombre de usuario debe tener mínimo 5 caracteres alfanuméricos.');
        return;
    }

    if (password && !REGEX_PASSWORD.test(password)) {
        alert('La nueva contraseña debe tener al menos 8 caracteres, una mayúscula, una minúscula, un número y un carácter especial.');
        return;
    }

    const originalText = btn.textContent;
    btn.disabled = true;
    btn.textContent = 'Guardando...';

    try {
        const response = await fetchAPI(`/admin/usuarios/${user.id}`, {
            method: 'PUT',
            body: JSON.stringify(payload)
        });

        if (response && response.success) {
            successAlert.textContent = 'Perfil actualizado correctamente.';
            successAlert.style.display = 'block';

            // Si se cambió la contraseña o el username, invalidar token local y redirigir
            if (password || user.username !== payload.username) {
                alert('Tus credenciales fueron actualizadas exitosamente. Deberás iniciar sesión nuevamente.');
                localStorage.removeItem('token');
                localStorage.removeItem('user');
                localStorage.removeItem('xpressUsuario');
                window.location.href = '/views/login.html';
                return;
            }

            // Actualizar datos en sesión
            const updatedUser = { ...user, nombre: payload.name, apellido: payload.lastName, cedula: payload.ci, ci: payload.ci, telefono: payload.phone, correo: payload.email, username: payload.username };
            localStorage.setItem('xpressUsuario', JSON.stringify(updatedUser));
            
            cargarDatosPerfil(updatedUser);
            
            // Si topbar está presente, intentar actualizarlo
            if (typeof populateTopbarUser === 'function') {
                populateTopbarUser();
            }
        } else {
            throw new Error(response.message || 'Error al actualizar el perfil.');
        }
    } catch (error) {
        errorAlert.textContent = error.message || 'Error en la conexión.';
        errorAlert.style.display = 'block';
    } finally {
        btn.disabled = false;
        btn.textContent = originalText;
    }
}
