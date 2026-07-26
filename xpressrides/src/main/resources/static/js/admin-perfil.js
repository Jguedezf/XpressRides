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
        email: document.getElementById('admin-correo').value.trim()
    };

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

            // Actualizar datos en sesión
            const updatedUser = { ...user, nombre: payload.name, apellido: payload.lastName, cedula: payload.ci, ci: payload.ci, telefono: payload.phone, correo: payload.email };
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
