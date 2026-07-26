// js/admin-personal.js — Alta y listado de personal administrativo

let todosLosAdmins = [];
let adminsFiltrados = [];
let paginaActual = 1;
const adminsPorPagina = 5; // Como solicitó el usuario, similar a clientes pero 5 por página, o 10. Pondremos 10 por consistencia, no, dijo paginación como la de clientes. Dejemos 10.

document.addEventListener('DOMContentLoaded', async () => {
    if (!requireAuth()) return;

    const usuario = getUsuario();
    const rol = (usuario.rol || usuario.role || '').toLowerCase();

    if (rol !== 'administrador' && rol !== 'admin') {
        document.getElementById('form-section').style.display = 'none';
        document.getElementById('acceso-denegado').style.display = 'block';
    }

    document.getElementById('personal-form').addEventListener('submit', async (e) => {
        e.preventDefault();
        await crearPersonalAdmin();
    });

    document.getElementById('btn-prev-page').addEventListener('click', () => cambiarPagina(-1));
    document.getElementById('btn-next-page').addEventListener('click', () => cambiarPagina(1));

    document.getElementById('buscar-admin').addEventListener('input', (e) => {
        aplicarFiltro(e.target.value);
    });

    await cargarAdmins();
});

async function cargarAdmins() {
    const tbody = document.getElementById('tbody-admins');
    try {
        const response = await fetchAPI('/admin/personal-admin');
        todosLosAdmins = response.data || [];
        document.getElementById('total-admins').textContent = todosLosAdmins.length;
        aplicarFiltro(document.getElementById('buscar-admin').value);
    } catch (error) {
        tbody.innerHTML = `<tr><td colspan="6" class="text-center" style="color: var(--color-error);">Error: ${error.message}</td></tr>`;
    }
}

function aplicarFiltro(texto) {
    const q = texto.trim().toLowerCase();
    if (!q) {
        adminsFiltrados = [...todosLosAdmins];
    } else {
        adminsFiltrados = todosLosAdmins.filter(a => {
            const nombreCompleto = `${a.nombre || ''} ${a.apellido || ''}`.toLowerCase();
            const username = (a.username || '').toLowerCase();
            return nombreCompleto.includes(q) || username.includes(q);
        });
    }
    paginaActual = 1;
    actualizarPaginacion();
}

function actualizarPaginacion() {
    const totalPaginas = Math.ceil(adminsFiltrados.length / adminsPorPagina) || 1;
    document.getElementById('page-info').textContent = `Página ${paginaActual} de ${totalPaginas}`;
    
    document.getElementById('btn-prev-page').disabled = (paginaActual === 1);
    document.getElementById('btn-next-page').disabled = (paginaActual === totalPaginas);

    renderizarPagina();
}

function cambiarPagina(delta) {
    const totalPaginas = Math.ceil(adminsFiltrados.length / adminsPorPagina) || 1;
    paginaActual += delta;
    if (paginaActual < 1) paginaActual = 1;
    if (paginaActual > totalPaginas) paginaActual = totalPaginas;
    
    actualizarPaginacion();
}

function renderizarPagina() {
    const tbody = document.getElementById('tbody-admins');
    tbody.innerHTML = '';

    if (adminsFiltrados.length === 0) {
        tbody.innerHTML = `<tr><td colspan="7" class="text-center">No se encontró personal administrativo.</td></tr>`;
        return;
    }

    const inicio = (paginaActual - 1) * adminsPorPagina;
    const fin = inicio + adminsPorPagina;
    const itemsPagina = adminsFiltrados.slice(inicio, fin);

    itemsPagina.forEach((a) => {
        const tr = document.createElement('tr');
        const nombreCol = a.nombre ? `${a.nombre} ${a.apellido || ''}` : 'Sin nombre';
        
        // Estado especial para los administradores iniciales.
        // Si no tienen "creadoPor" asumiremos que son iniciales/sistema.
        let creadoPorBadge = '';
        if (a.creadoPor) {
            creadoPorBadge = a.creadoPor;
        } else {
            creadoPorBadge = '<span class="badge-green" style="background-color: var(--color-primary); color: white;">Sistema (Inicial)</span>';
        }

        const clientData = JSON.stringify(a).replace(/"/g, '&quot;');

        let actionButtons = '';
        if (a.rol && a.rol.toLowerCase() === 'administrador') {
            actionButtons = '<span style="display:inline-block; background-color: #E2E8F0; color: #64748B; padding: 4px 8px; border-radius: 4px; font-size: 11px; font-weight: 600; text-transform: uppercase;">No disponible</span>';
        } else {
            actionButtons = `<div style="display: flex; gap: 4px; justify-content: center; flex-wrap: wrap;">
                                <button class="btn-primary btn-auto btn-sm" onclick='abrirModalEditar(${clientData})'>Editar</button>
                                <button class="btn-danger btn-auto btn-sm" onclick="abrirModalEliminar(${a.id})">Eliminar</button>
                             </div>`;
        }

        tr.innerHTML = `
            <td>${a.id}</td>
            <td>${nombreCol}</td>
            <td>${a.username}</td>
            <td style="color: var(--color-text-muted);">${a.cargo || 'No especificado'}</td>
            <td style="text-transform: capitalize;">${a.rol || 'N/A'}</td>
            <td>${creadoPorBadge}</td>
            <td style="text-align: center;">
                ${actionButtons}
            </td>
        `;
        tbody.appendChild(tr);
    });
}

async function crearPersonalAdmin() {
    const btn = document.getElementById('btn-personal-submit');
    const successAlert = document.getElementById('personal-success');
    const errorAlert = document.getElementById('personal-error');
    successAlert.style.display = 'none';
    errorAlert.style.display = 'none';

    // Obtener el usuario actual para enviarlo como creador
    const usuarioLogueado = getUsuario();

    const payload = {
        name: document.getElementById('personal-nombre').value.trim(),
        lastName: document.getElementById('personal-apellido').value.trim(),
        ci: document.getElementById('personal-cedula').value.trim(),
        phone: document.getElementById('personal-telefono').value.trim(),
        username: document.getElementById('personal-usuario').value.trim(),
        email: document.getElementById('personal-correo').value.trim(),
        password: document.getElementById('personal-password').value,
        position: document.getElementById('personal-cargo').value.trim() || null,
        createdBy: usuarioLogueado ? usuarioLogueado.username : null
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
        cargarAdmins();
    } catch (error) {
        errorAlert.textContent = error.message || 'Error al crear la cuenta.';
        errorAlert.style.display = 'block';
    } finally {
        btn.disabled = false;
        btn.textContent = originalText;
    }
}

// Modal logic
function abrirModalEditar(user) {
    document.getElementById('edit-user-id').value = user.id;
    document.getElementById('edit-nombre').value = user.nombre || '';
    document.getElementById('edit-apellido').value = user.apellido || '';
    document.getElementById('edit-cedula').value = user.ci || '';
    document.getElementById('edit-telefono').value = user.telefono || '';
    document.getElementById('edit-correo').value = user.correo || '';
    document.getElementById('modal-editar-usuario').style.display = 'flex';
}

function cerrarModalEditar() {
    document.getElementById('modal-editar-usuario').style.display = 'none';
}

document.getElementById('form-editar-usuario').addEventListener('submit', async function(e) {
    e.preventDefault();
    const id = document.getElementById('edit-user-id').value;
    const nombre = document.getElementById('edit-nombre').value.trim();
    const apellido = document.getElementById('edit-apellido').value.trim();
    const cedula = document.getElementById('edit-cedula').value.trim();
    const telefono = document.getElementById('edit-telefono').value.trim();
    const email = document.getElementById('edit-correo').value.trim();

    const REGEX_NOMBRE = /^[a-zA-ZáéíóúÁÉÍÓÚñÑ\s]+$/;
    const REGEX_CEDULA = /^[VE]-\d{7,9}$/;
    const REGEX_TELEFONO = /^04(14|24|16|26|12)-?\d{7}$/;

    if (!REGEX_NOMBRE.test(nombre)) {
        alert('El nombre solo debe contener letras y espacios.');
        return;
    }
    if (!REGEX_NOMBRE.test(apellido)) {
        alert('El apellido solo debe contener letras y espacios.');
        return;
    }
    if (!REGEX_CEDULA.test(cedula)) {
        alert('La cédula debe tener formato V-12345678 o E-12345678 (V mayúscula).');
        return;
    }
    if (!REGEX_TELEFONO.test(telefono)) {
        alert('Teléfono inválido. Usa formato 0414-1234567 o 04141234567 con prefijo válido.');
        return;
    }

    const body = {
        name: nombre,
        lastName: apellido,
        ci: cedula,
        phone: telefono,
        email: email
    };

    try {
        const res = await fetchAPI("/admin/usuarios/" + id, {
            method: 'PUT',
            body: JSON.stringify(body)
        });
        if (res && res.success) {
            cerrarModalEditar();
            cargarAdmins();
        } else {
            alert(res?.message || 'Error al actualizar usuario');
        }
    } catch (error) {
        alert('Error en la conexi�n');
    }
});

function abrirModalEliminar(id) {
    document.getElementById('delete-user-id').value = id;
    document.getElementById('modal-eliminar-usuario').style.display = 'flex';
}

function cerrarModalEliminar() {
    document.getElementById('modal-eliminar-usuario').style.display = 'none';
}

async function confirmarEliminarUsuario() {
    const id = document.getElementById('delete-user-id').value;
    try {
        const res = await fetchAPI("/admin/usuarios/" + id, {
            method: 'DELETE'
        });
        if (res && res.success) {
            cerrarModalEliminar();
            cargarAdmins();
        } else {
            alert(res?.message || 'Error al eliminar usuario');
        }
    } catch (error) {
        alert('Error en la conexi�n');
    }
}

// Lógica para mostrar/ocultar contraseña al crear personal
document.addEventListener('DOMContentLoaded', () => {
    const togglePasswordBtn = document.getElementById('toggle-personal-password');
    const passwordInput = document.getElementById('personal-password');
    const eyeIcon = document.getElementById('eye-icon-personal');

    if (togglePasswordBtn && passwordInput && eyeIcon) {
        togglePasswordBtn.addEventListener('click', () => {
            const isPassword = passwordInput.type === 'password';
            passwordInput.type = isPassword ? 'text' : 'password';
            
            if (isPassword) {
                // Icono de ojo tachado (ocultar)
                eyeIcon.innerHTML = `
                    <path d="M17.94 17.94A10.07 10.07 0 0 1 12 20c-7 0-11-8-11-8a18.45 18.45 0 0 1 5.06-5.94M9.9 4.24A9.12 9.12 0 0 1 12 4c7 0 11 8 11 8a18.5 18.5 0 0 1-2.16 3.19m-6.72-1.07a3 3 0 1 1-4.24-4.24"></path>
                    <line x1="1" y1="1" x2="23" y2="23"></line>
                `;
            } else {
                // Icono de ojo normal (mostrar)
                eyeIcon.innerHTML = `
                    <path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z"></path>
                    <circle cx="12" cy="12" r="3"></circle>
                `;
            }
        });
    }
});
