// js/admin-clientes.js
// Pantalla de consulta/búsqueda de clientes — NO es un CRUD, es solo listado + filtro.
// Aspecto agregado por el equipo, no exigido por el enunciado (ver informe, ítem a).

let todosLosClientes = [];
let clientesFiltrados = [];
let paginaActual = 1;
const clientesPorPagina = 10;

document.addEventListener('DOMContentLoaded', async () => {
    if (!requireAuth()) return;
    
    document.getElementById('btn-prev-page').addEventListener('click', () => cambiarPagina(-1));
    document.getElementById('btn-next-page').addEventListener('click', () => cambiarPagina(1));

    await cargarClientes();
});

document.getElementById('buscar-cliente').addEventListener('input', (e) => {
    aplicarFiltro(e.target.value);
});

async function cargarClientes() {
    const tbody = document.getElementById('tbody-clientes');

    try {
        const response = await fetchAPI('/admin/clientes');
        todosLosClientes = response.data || [];
        
        document.getElementById('total-clientes').textContent = todosLosClientes.length;
        aplicarFiltro(document.getElementById('buscar-cliente').value);
    } catch (error) {
        tbody.innerHTML = `<tr><td colspan="6" class="text-center" style="color: var(--color-error);">Error: ${error.message}</td></tr>`;
    }
}

function aplicarFiltro(texto) {
    const q = texto.trim().toLowerCase();
    if (!q) {
        clientesFiltrados = [...todosLosClientes];
    } else {
        clientesFiltrados = todosLosClientes.filter(c => {
            const nombreCompleto = `${c.nombre || ''} ${c.apellido || ''}`.toLowerCase();
            const username = (c.username || '').toLowerCase();
            return nombreCompleto.includes(q) || username.includes(q);
        });
    }
    
    paginaActual = 1;
    actualizarPaginacion();
}

function cambiarPagina(delta) {
    const totalPaginas = Math.ceil(clientesFiltrados.length / clientesPorPagina) || 1;
    paginaActual += delta;
    if (paginaActual < 1) paginaActual = 1;
    if (paginaActual > totalPaginas) paginaActual = totalPaginas;
    
    actualizarPaginacion();
}

function actualizarPaginacion() {
    const totalPaginas = Math.ceil(clientesFiltrados.length / clientesPorPagina) || 1;
    
    document.getElementById('page-info').textContent = `Página ${paginaActual} de ${totalPaginas}`;
    document.getElementById('btn-prev-page').disabled = paginaActual <= 1;
    document.getElementById('btn-next-page').disabled = paginaActual >= totalPaginas;

    const inicio = (paginaActual - 1) * clientesPorPagina;
    const fin = inicio + clientesPorPagina;
    const paginaClientes = clientesFiltrados.slice(inicio, fin);
    
    // We pass the start index to maintain correct numbering across pages
    renderClientes(paginaClientes, inicio);
}

function renderClientes(clientes, startIndex = 0) {
    const tbody = document.getElementById('tbody-clientes');

    if (clientes.length === 0) {
        tbody.innerHTML = '<tr><td colspan="7" class="text-center">No hay clientes que coincidan con la búsqueda.</td></tr>';
        return;
    }

    const escapeHTML = str => String(str).replace(/[&<>'"]/g, 
        tag => ({
            '&': '&amp;',
            '<': '&lt;',
            '>': '&gt;',
            "'": '&#39;',
            '"': '&quot;'
        }[tag] || tag)
    );

    tbody.innerHTML = clientes.map((c, index) => {
        const saldo = c.saldoUsd != null ? Number(c.saldoUsd).toFixed(2) : '0.00';
        const nombreStr = escapeHTML(`${c.nombre || ''} ${c.apellido || ''}`);
        const userStr = escapeHTML(c.username || '');
        const clientData = JSON.stringify(c).replace(/"/g, '&quot;');
        
        return `
            <tr>
                <td>${startIndex + index + 1}</td>
                <td>${nombreStr}</td>
                <td>${userStr}</td>
                <td>$ ${saldo}</td>
                <td>${c.esEstudiante ? 'Sí' : 'No'}</td>
                <td>${c.primerViajeUsado ? 'Sí' : 'No'}</td>
                <td style="text-align: center;">
                    <div style="display: flex; gap: 4px; justify-content: center; flex-wrap: wrap;">
                        <button class="btn-primary btn-auto btn-sm" onclick='abrirModalEditar(${clientData})'>Editar</button>
                        <button class="btn-danger btn-auto btn-sm" onclick="abrirModalEliminar(${c.usuarioId || c.id})">Eliminar</button>
                    </div>
                </td>
            </tr>
        `;
    }).join("");
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
            cargarClientes();
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
            cargarClientes();
        } else {
            mostrarMensajeTemporal(res?.message || 'Error al eliminar usuario', 'error');
        }
    } catch (error) {
        mostrarMensajeTemporal('Error en la conexión', 'error');
    }
}
