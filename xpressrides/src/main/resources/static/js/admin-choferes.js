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
                    <button class="btn-danger btn-auto btn-sm" onclick="abrirModalEliminar(${c.id})">Eliminar</button>
                </div>
            </td>
        `;
        tbody.appendChild(tr);
    });
}

async function toggleChoferEstado(id, habilitar) {
    alert('Esta funcionalidad debe conectarse con el endpoint correspondiente para ' + (habilitar ? 'habilitar' : 'deshabilitar'));
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
    const body = {
        name: document.getElementById('edit-nombre').value,
        lastName: document.getElementById('edit-apellido').value,
        ci: document.getElementById('edit-cedula').value,
        phone: document.getElementById('edit-telefono').value,
        email: document.getElementById('edit-correo').value
    };

    try {
        const res = await fetchAPI(`/admin/usuarios/${id}`, {
            method: 'PUT',
            body: JSON.stringify(body)
        });
        if (res && res.success) {
            cerrarModalEditar();
            obtenerChoferes();
        } else {
            alert(res?.message || 'Error al actualizar usuario');
        }
    } catch (error) {
        alert('Error en la conexión');
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
            cerrarModalEliminar();
            obtenerChoferes();
        } else {
            alert(res?.message || 'Error al eliminar usuario');
        }
    } catch (error) {
        alert('Error en la conexión');
    }
}
