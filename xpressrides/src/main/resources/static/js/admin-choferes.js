// js/admin-choferes.js
let todosLosChoferes = [];
let choferesFiltrados = [];
let paginaActual = 1;
const choferesPorPagina = 10;

document.addEventListener('DOMContentLoaded', async () => {
    if (!requireAuth()) return;
    
    document.getElementById('btn-prev-page').addEventListener('click', () => cambiarPagina(-1));
    document.getElementById('btn-next-page').addEventListener('click', () => cambiarPagina(1));

    await cargarChoferes();
});

document.getElementById('buscar-chofer').addEventListener('input', (e) => {
    aplicarFiltro(e.target.value);
});

async function cargarChoferes() {
    const tbody = document.getElementById('tbody-choferes');

    try {
        const response = await fetchAPI('/admin/choferes');
        todosLosChoferes = response.data || [];
        
        document.getElementById('total-choferes').textContent = todosLosChoferes.length;
        aplicarFiltro(document.getElementById('buscar-chofer').value);
    } catch (error) {
        tbody.innerHTML = `<tr><td colspan="6" class="text-center" style="color: var(--color-error);">Error: ${error.message}</td></tr>`;
    }
}

function aplicarFiltro(texto) {
    const q = texto.trim().toLowerCase();
    if (!q) {
        choferesFiltrados = [...todosLosChoferes];
    } else {
        choferesFiltrados = todosLosChoferes.filter(c => {
            const nombreCompleto = `${c.nombre || ''} ${c.apellido || ''}`.toLowerCase();
            const username = (c.username || '').toLowerCase();
            return nombreCompleto.includes(q) || username.includes(q);
        });
    }
    
    paginaActual = 1;
    actualizarPaginacion();
}

function actualizarPaginacion() {
    const totalPaginas = Math.ceil(choferesFiltrados.length / choferesPorPagina) || 1;
    document.getElementById('page-info').textContent = `Página ${paginaActual} de ${totalPaginas}`;
    
    document.getElementById('btn-prev-page').disabled = (paginaActual === 1);
    document.getElementById('btn-next-page').disabled = (paginaActual === totalPaginas);

    renderizarPagina();
}

function cambiarPagina(delta) {
    const totalPaginas = Math.ceil(choferesFiltrados.length / choferesPorPagina) || 1;
    paginaActual += delta;
    if (paginaActual < 1) paginaActual = 1;
    if (paginaActual > totalPaginas) paginaActual = totalPaginas;
    
    actualizarPaginacion();
}

function renderizarPagina() {
    const tbody = document.getElementById('tbody-choferes');
    tbody.innerHTML = '';

    if (choferesFiltrados.length === 0) {
        tbody.innerHTML = `<tr><td colspan="6" class="text-center">No se encontraron conductores.</td></tr>`;
        return;
    }

    const inicio = (paginaActual - 1) * choferesPorPagina;
    const fin = inicio + choferesPorPagina;
    const itemsPagina = choferesFiltrados.slice(inicio, fin);

    itemsPagina.forEach((c) => {
        const tr = document.createElement('tr');
        const nombreCol = c.nombre ? `${c.nombre} ${c.apellido}` : 'Sin nombre';
        
        let estadoBadge = '';
        let toggleButton = '';
        if (c.habilitado) {
            estadoBadge = `<span class="badge-green">Habilitado</span>`;
            toggleButton = `<button class="btn-primary btn-auto btn-sm" style="background-color: var(--color-error);" onclick="toggleChoferEstado(${c.id}, false)">Deshabilitar</button>`;
        } else {
            estadoBadge = `<span class="badge-red">Deshabilitado</span>`;
            toggleButton = `<button class="btn-primary btn-auto btn-sm" style="background-color: var(--color-success);" onclick="toggleChoferEstado(${c.id}, true)">Habilitar</button>`;
        }

        const clientData = JSON.stringify(c).replace(/"/g, '&quot;');
        
        tr.innerHTML = `
            <td>${c.id}</td>
            <td>${nombreCol}</td>
            <td>${c.username}</td>
            <td>$${(c.saldoAcumuladoUsd || 0).toFixed(2)}</td>
            <td>${estadoBadge}</td>
            <td style="text-align: center;">
                <div style="display: flex; gap: 4px; justify-content: center; flex-wrap: wrap;">
                    ${toggleButton}
                    <button class="btn-primary btn-auto btn-sm" onclick='abrirModalEditar(${clientData})'>Editar</button>
                    <button class="btn-danger btn-auto btn-sm" onclick="abrirModalEliminar(${c.usuarioId || c.id})">Eliminar</button>
                </div>
            </td>
        `;
        tbody.appendChild(tr);
    });
}

async function toggleChoferEstado(id, habilitar) {
    try {
        const payload = { enabled: habilitar };
        const res = await fetchAPI(`/chofer/habilitar/${id}`, {
            method: 'PUT',
            body: JSON.stringify(payload)
        });
        if (res && res.message) {
            mostrarMensajeTemporal('Estado actualizado con éxito', 'success');
            cargarChoferes();
        } else {
            mostrarMensajeTemporal(res?.message || 'Error al cambiar el estado del chofer.', 'error');
        }
    } catch (err) {
        mostrarMensajeTemporal(err.message || 'Error al actualizar estado.', 'error');
    }
}

// Modal logic
function abrirModalEditar(user) {
    document.getElementById('edit-user-id').value = user.usuarioId || user.id;
    document.getElementById('edit-nombre').value = user.nombre || '';
    document.getElementById('edit-apellido').value = user.apellido || '';
    document.getElementById('edit-cedula').value = user.ci || '';
    document.getElementById('edit-telefono').value = user.telefono || '';
    document.getElementById('edit-correo').value = user.correo || '';
    document.getElementById('edit-username').value = user.username || '';
    document.getElementById('edit-password').value = ''; // Reset password field
    document.getElementById('modal-editar-usuario').style.display = 'flex';
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

function cerrarModalEditar() {
    document.getElementById('modal-editar-usuario').style.display = 'none';
}

document.getElementById('form-editar-usuario').addEventListener('submit', async function(e) {
    e.preventDefault();
    const id = document.getElementById('edit-user-id').value;
    const payload = {
        name: document.getElementById('edit-nombre').value.trim(),
        lastName: document.getElementById('edit-apellido').value.trim(),
        ci: document.getElementById('edit-cedula').value.trim(),
        phone: document.getElementById('edit-telefono').value.trim(),
        email: document.getElementById('edit-correo').value.trim(),
        username: document.getElementById('edit-username').value.trim()
    };

    const password = document.getElementById('edit-password').value;
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

    const REGEX_NOMBRE = /^[a-zA-ZáéíóúÁÉÍÓÚñÑ\s]+$/;
    const REGEX_CEDULA = /^[VE]-\d{7,9}$/;
    const REGEX_TELEFONO = /^04(14|24|16|26|12)-?\d{7}$/;

    if (!REGEX_NOMBRE.test(payload.name)) {
        alert('El nombre solo debe contener letras y espacios.');
        return;
    }
    if (!REGEX_NOMBRE.test(payload.lastName)) {
        alert('El apellido solo debe contener letras y espacios.');
        return;
    }
    if (!REGEX_CEDULA.test(payload.ci)) {
        alert('La cédula debe tener formato V-12345678 o E-12345678 (V mayúscula).');
        return;
    }
    if (!REGEX_TELEFONO.test(payload.phone)) {
        alert('Teléfono inválido. Usa formato 0414-1234567 o 04141234567 con prefijo válido.');
        return;
    }

    const btn = e.target.querySelector('button[type="submit"]');
    const originalText = btn.innerText;
    btn.innerText = 'Guardando...';
    btn.disabled = true;

    try {
        const res = await fetchAPI(`/admin/usuarios/${id}`, {
            method: 'PUT',
            body: JSON.stringify(payload)
        });
        if (res && res.success) {
            mostrarMensajeTemporal('Usuario actualizado con éxito', 'success');
            cerrarModalEditar();
            cargarChoferes();
        } else {
            mostrarMensajeTemporal(res?.message || 'Error al actualizar usuario', 'error');
        }
    } catch (err) {
        mostrarMensajeTemporal(err.message || 'Error en la conexión', 'error');
    } finally {
        btn.innerText = originalText;
        btn.disabled = false;
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
        const res = await fetchAPI(`/admin/usuarios/${id}`, {
            method: 'DELETE'
        });
        if (res && res.success) {
            mostrarMensajeTemporal('Usuario eliminado con éxito', 'success');
            cerrarModalEliminar();
            cargarChoferes();
        } else {
            mostrarMensajeTemporal(res?.message || 'Error al eliminar usuario', 'error');
        }
    } catch (error) {
        mostrarMensajeTemporal('Error en la conexión', 'error');
    }
}
