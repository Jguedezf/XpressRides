// js/admin-bancos.js — CRUD de bancos para el panel administrativo

let todosLosBancos = [];

document.addEventListener('DOMContentLoaded', async () => {
    if (!requireAuth()) return;
    
    document.getElementById('banco-nombre').addEventListener('change', (e) => {
        const select = e.target;
        const code = select.options[select.selectedIndex].getAttribute('data-code');
        document.getElementById('banco-codigo').value = code || '';
    });

    await cargarCatalogoBancos();
    await cargarBancos();
});

async function cargarCatalogoBancos() {
    const select = document.getElementById('banco-nombre');
    try {
        const response = await fetchAPI('/bancos/catalogo');
        const catalogo = response.data || [];
        
        catalogo.forEach(banco => {
            const option = document.createElement('option');
            option.value = banco.name;
            option.setAttribute('data-code', banco.bcvCode);
            option.textContent = banco.name;
            select.appendChild(option);
        });
    } catch (error) {
        console.error("Error al cargar catálogo de bancos:", error);
    }
}

document.getElementById('banco-form').addEventListener('submit', async (e) => {
    e.preventDefault();
    await guardarBanco();
});

document.getElementById('btn-banco-cancelar').addEventListener('click', () => {
    resetFormulario();
});

async function cargarBancos() {
    const tbody = document.getElementById('tbody-bancos');

    try {
        const response = await fetchAPI('/bancos/todos');
        todosLosBancos = response.data || [];

        document.getElementById('total-bancos').textContent = todosLosBancos.length;
        renderBancos();

    } catch (error) {
        tbody.innerHTML = `<tr><td colspan="6" class="text-center" style="color: var(--color-error);">Error: ${error.message}</td></tr>`;
    }
}

function renderBancos() {
    const tbody = document.getElementById('tbody-bancos');

    if (todosLosBancos.length === 0) {
        tbody.innerHTML = '<tr><td colspan="6" class="text-center">No hay bancos registrados.</td></tr>';
        return;
    }

    tbody.innerHTML = '';
    todosLosBancos.forEach(b => {
        const tr = document.createElement('tr');
        tr.innerHTML = `
            <td>${b.name}</td>
            <td>${b.bcvCode}</td>
            <td><span class="badge ${b.acceptsUsd ? 'badge-si' : 'badge-no'}">${b.acceptsUsd ? 'Sí' : 'No'}</span></td>
            <td><span class="badge ${b.acceptsVes ? 'badge-si' : 'badge-no'}">${b.acceptsVes ? 'Sí' : 'No'}</span></td>
            <td><span class="badge ${b.active ? 'badge-si' : 'badge-no'}">${b.active ? 'Activo' : 'Inactivo'}</span></td>
            <td></td>
        `;
        const accionesTd = tr.querySelector('td:last-child');

        const btnEditar = document.createElement('button');
        btnEditar.className = 'btn-mini';
        btnEditar.style.cssText = 'background:#1F4E79;color:white;';
        btnEditar.textContent = 'Editar';
        btnEditar.addEventListener('click', () => cargarParaEdicion(b));
        accionesTd.appendChild(btnEditar);

        if (b.active) {
            const btnDesactivar = document.createElement('button');
            btnDesactivar.className = 'btn-mini';
            btnDesactivar.style.cssText = 'background:#dc3545;color:white;';
            btnDesactivar.textContent = 'Desactivar';
            btnDesactivar.addEventListener('click', () => desactivarBanco(b.id));
            accionesTd.appendChild(btnDesactivar);
        }

        tbody.appendChild(tr);
    });

    actualizarOpcionesBancos();
}

function actualizarOpcionesBancos() {
    const select = document.getElementById('banco-nombre');
    const currentEditId = document.getElementById('banco-id').value;

    Array.from(select.options).forEach(opt => opt.disabled = false);

    todosLosBancos.forEach(b => {
        if (currentEditId === String(b.id)) return; // No deshabilitar el banco que se está editando

        const optionByCodeAttr = select.querySelector(`option[data-code="${b.bcvCode}"]`);
        if (optionByCodeAttr) optionByCodeAttr.disabled = true;

        const optionByValueOrName = Array.from(select.options).find(opt => 
            opt.value === b.name || 
            opt.value === b.bcvCode || 
            opt.textContent === b.name
        );
        if (optionByValueOrName) optionByValueOrName.disabled = true;
    });
}

function cargarParaEdicion(banco) {
    document.getElementById('form-title').textContent = `Editar Banco — ${banco.name}`;
    document.getElementById('banco-id').value = banco.id;
    
    // Si el nombre antiguo no está en el select, lo agregamos temporalmente para que se vea
    const select = document.getElementById('banco-nombre');
    const optionExists = Array.from(select.options).some(opt => opt.value === banco.name || opt.getAttribute('data-code') === banco.bcvCode);
    
    if (!optionExists) {
        const newOpt = document.createElement('option');
        newOpt.value = banco.name;
        newOpt.setAttribute('data-code', banco.bcvCode);
        newOpt.textContent = banco.name;
        select.appendChild(newOpt);
    }

    // Seleccionamos por código preferiblemente
    const optionToSelect = select.querySelector(`option[data-code="${banco.bcvCode}"]`) || Array.from(select.options).find(opt => opt.value === banco.name);
    if (optionToSelect) {
        select.value = optionToSelect.value;
    }

    document.getElementById('banco-codigo').value = banco.bcvCode;
    document.getElementById('banco-usd').checked = !!banco.acceptsUsd;
    document.getElementById('banco-ves').checked = !!banco.acceptsVes;
    document.getElementById('btn-banco-submit').textContent = 'Guardar Cambios';
    document.getElementById('btn-banco-cancelar').style.display = 'inline-block';
    
    actualizarOpcionesBancos();
    window.scrollTo({ top: 0, behavior: 'smooth' });
}

function resetFormulario() {
    document.getElementById('form-title').textContent = 'Nuevo Banco';
    document.getElementById('banco-form').reset();
    document.getElementById('banco-id').value = '';
    document.getElementById('banco-ves').checked = true;
    document.getElementById('btn-banco-submit').textContent = 'Guardar Banco';
    document.getElementById('btn-banco-cancelar').style.display = 'none';
    
    actualizarOpcionesBancos();
}

async function guardarBanco() {
    const btn = document.getElementById('btn-banco-submit');
    const successAlert = document.getElementById('banco-success');
    const errorAlert = document.getElementById('banco-error');
    successAlert.style.display = 'none';
    errorAlert.style.display = 'none';

    const id = document.getElementById('banco-id').value;
    const payload = {
        name: document.getElementById('banco-nombre').value.trim(),
        bcvCode: document.getElementById('banco-codigo').value.trim(),
        acceptsUsd: document.getElementById('banco-usd').checked,
        acceptsVes: document.getElementById('banco-ves').checked
    };

    const originalText = btn.textContent;
    btn.disabled = true;
    btn.textContent = 'Guardando...';

    try {
        if (id) {
            await fetchAPI(`/bancos/${id}`, { method: 'PUT', body: JSON.stringify(payload) });
            successAlert.textContent = 'Banco actualizado correctamente.';
        } else {
            await fetchAPI('/bancos', { method: 'POST', body: JSON.stringify(payload) });
            successAlert.textContent = 'Banco creado correctamente.';
        }
        successAlert.style.display = 'block';
        resetFormulario();
        await cargarBancos();
    } catch (error) {
        errorAlert.textContent = error.message || 'No se pudo guardar el banco.';
        errorAlert.style.display = 'block';
    } finally {
        btn.disabled = false;
        btn.textContent = originalText;
    }
}

async function desactivarBanco(id) {
    if (!confirm('¿Desactivar este banco? Dejará de estar disponible para nuevos registros de choferes.')) return;

    try {
        await fetchAPI(`/bancos/${id}/desactivar`, { method: 'PATCH' });
        await cargarBancos();
    } catch (error) {
        alert('Error: ' + (error.message || 'No se pudo desactivar el banco.'));
    }
}
