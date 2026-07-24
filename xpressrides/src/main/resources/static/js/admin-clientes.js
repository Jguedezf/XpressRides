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
        tbody.innerHTML = '<tr><td colspan="6" class="text-center">No hay clientes que coincidan con la búsqueda.</td></tr>';
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
        return `
            <tr>
                <td>${startIndex + index + 1}</td>
                <td>${nombreStr}</td>
                <td>${userStr}</td>
                <td>$ ${saldo}</td>
                <td>${c.esEstudiante ? 'Sí' : 'No'}</td>
                <td>${c.primerViajeUsado ? 'Sí' : 'No'}</td>
            </tr>
        `;
    }).join("");
}
