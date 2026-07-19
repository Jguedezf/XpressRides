// js/admin-personal.js — Alta de personal administrativo, solo rol 'administrador'

document.addEventListener('DOMContentLoaded', () => {
    if (!requireAuth()) return;

    const usuario = getUsuario();
    const rol = (usuario.rol || usuario.role || '').toLowerCase();

    if (rol !== 'administrador' && rol !== 'admin') {
        document.getElementById('form-section').style.display = 'none';
        document.getElementById('acceso-denegado').style.display = 'block';
        return;
    }

    document.getElementById('personal-form').addEventListener('submit', async (e) => {
        e.preventDefault();
        await crearPersonalAdmin();
    });
});

async function crearPersonalAdmin() {
    const btn = document.getElementById('btn-personal-submit');
    const successAlert = document.getElementById('personal-success');
    const errorAlert = document.getElementById('personal-error');
    successAlert.style.display = 'none';
    errorAlert.style.display = 'none';

    const payload = {
        name: document.getElementById('personal-nombre').value.trim(),
        lastName: document.getElementById('personal-apellido').value.trim(),
        ci: document.getElementById('personal-cedula').value.trim(),
        phone: document.getElementById('personal-telefono').value.trim(),
        username: document.getElementById('personal-usuario').value.trim(),
        email: document.getElementById('personal-correo').value.trim(),
        password: document.getElementById('personal-password').value,
        position: document.getElementById('personal-cargo').value.trim() || null
    };

    const originalText = btn.textContent;
    btn.disabled = true;
    btn.textContent = 'Creando...';

    try {
        const response = await fetchAPI('/admin/personal-admin', {
            method: 'POST',
            body: JSON.stringify(payload)
        });
        successAlert.textContent = `Cuenta creada correctamente para ${response.data.nombre} ${response.data.apellido} (usuario: ${response.data.username}).`;
        successAlert.style.display = 'block';
        document.getElementById('personal-form').reset();
    } catch (error) {
        errorAlert.textContent = error.message || 'No se pudo crear la cuenta.';
        errorAlert.style.display = 'block';
    } finally {
        btn.disabled = false;
        btn.textContent = originalText;
    }
}
