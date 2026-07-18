// js/admin-clientes.js
// Pantalla de consulta/búsqueda de clientes — NO es un CRUD, es solo listado + filtro.
// Aspecto agregado por el equipo, no exigido por el enunciado (ver informe, ítem a).

let todosLosClientes = [];

document.addEventListener('DOMContentLoaded', async () => {
    if (!requireAuth()) return;
    await cargarClientes();
});

document.getElementById('buscar-cliente').addEventListener('input', (e) => {
    renderClientes(filtrarClientes(e.target.value));
});

async function cargarClientes() {
    const tbody = document.getElementById('tbody-clientes');

    try {
        const response = await fetchAPI('/admin/clientes');
        todosLosClientes = response.data || [];

        document.getElementById('total-clientes').textContent = todosLosClientes.length;
        renderClientes(todosLosClientes);

    } catch (error) {
        tbody.innerHTML = `<tr><td colspan="6" class="text-center" style="color: var(--color-error);">Error: ${error.message}</td></tr>`;
    }
}

function filtrarClientes(texto) {
    const q = texto.trim().toLowerCase();
    if (!q) return todosLosClientes;

    return todosLosClientes.filter(c => {
        const nombreCompleto = `${c.nombre || ''} ${c.apellido || ''}`.toLowerCase();
        const username = (c.username || '').toLowerCase();
        return nombreCompleto.includes(q) || username.includes(q);
    });
}

function renderClientes(clientes) {
    const tbody = document.getElementById('tbody-clientes');

    if (clientes.length === 0) {
        tbody.innerHTML = '<tr><td colspan="6" class="text-center">No hay clientes que coincidan con la búsqueda.</td></tr>';
        return;
    }

    tbody.innerHTML = '';
    clientes.forEach(c => {
        const saldo = c.saldoUsd != null ? Number(c.saldoUsd).toFixed(2) : '0.00';
        tbody.innerHTML += `
            <tr>
                <td>#${c.id}</td>
                <td>${c.nombre || ''} ${c.apellido || ''}</td>
                <td>${c.username || ''}</td>
                <td>$ ${saldo}</td>
                <td>${c.esEstudiante ? 'Sí' : 'No'}</td>
                <td>${c.primerViajeUsado ? 'Sí' : 'No'}</td>
            </tr>
        `;
    });
}
