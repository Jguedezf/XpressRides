// js/admin-cupones.js — CRUD de cupones + asignación a cliente, panel administrativo

let todosLosCupones = [];
let todosLosClientesCache = null;

document.addEventListener('DOMContentLoaded', async () => {
    if (!requireAuth()) return;
    await cargarCupones();
});

document.getElementById('cupon-form').addEventListener('submit', async (e) => {
    e.preventDefault();
    await guardarCupon();
});

document.getElementById('btn-cupon-cancelar').addEventListener('click', () => {
    resetFormulario();
});

async function cargarCupones() {
    const tbody = document.getElementById('tbody-cupones');

    try {
        const response = await fetchAPI('/cupones');
        todosLosCupones = response.data || [];

        document.getElementById('total-cupones').textContent = todosLosCupones.length;
        renderCupones();

    } catch (error) {
        tbody.innerHTML = `<tr><td colspan="6" class="text-center" style="color: var(--color-error);">Error: ${error.message}</td></tr>`;
    }
}

function renderCupones() {
    const tbody = document.getElementById('tbody-cupones');

    if (todosLosCupones.length === 0) {
        tbody.innerHTML = '<tr><td colspan="6" class="text-center">No hay cupones registrados.</td></tr>';
        return;
    }

    tbody.innerHTML = '';
    todosLosCupones.forEach(c => {
        const tr = document.createElement('tr');
        tr.innerHTML = `
            <td>${c.code}</td>
            <td style="text-transform:capitalize;">${c.type}</td>
            <td>$ ${Number(c.discountUsd).toFixed(2)}</td>
            <td>${c.maxDistanceKm != null ? c.maxDistanceKm + ' km' : 'Sin límite'}</td>
            <td><span class="badge ${c.active ? 'badge-si' : 'badge-no'}">${c.active ? 'Activo' : 'Inactivo'}</span></td>
            <td></td>
        `;
        const accionesTd = tr.querySelector('td:last-child');

        const btnEditar = document.createElement('button');
        btnEditar.className = 'btn-mini';
        btnEditar.style.cssText = 'background:#1F4E79;color:white;';
        btnEditar.textContent = 'Editar';
        btnEditar.addEventListener('click', () => cargarParaEdicion(c));
        accionesTd.appendChild(btnEditar);

        if (c.active) {
            const btnAsignar = document.createElement('button');
            btnAsignar.className = 'btn-mini';
            btnAsignar.style.cssText = 'background:#2E7D32;color:white;';
            btnAsignar.textContent = 'Asignar';
            btnAsignar.addEventListener('click', () => asignarCupon(c));
            accionesTd.appendChild(btnAsignar);

            const btnDesactivar = document.createElement('button');
            btnDesactivar.className = 'btn-mini';
            btnDesactivar.style.cssText = 'background:#dc3545;color:white;';
            btnDesactivar.textContent = 'Desactivar';
            btnDesactivar.addEventListener('click', () => desactivarCupon(c.id));
            accionesTd.appendChild(btnDesactivar);
        }

        tbody.appendChild(tr);
    });
}

function cargarParaEdicion(cupon) {
    document.getElementById('form-title').textContent = `Editar Cupón — ${cupon.code}`;
    document.getElementById('cupon-id').value = cupon.id;
    document.getElementById('cupon-codigo').value = cupon.code;
    document.getElementById('cupon-tipo').value = cupon.type;
    document.getElementById('cupon-descuento').value = cupon.discountUsd;
    document.getElementById('cupon-distancia').value = cupon.maxDistanceKm != null ? cupon.maxDistanceKm : '';
    document.getElementById('btn-cupon-submit').textContent = 'Guardar Cambios';
    document.getElementById('btn-cupon-cancelar').style.display = 'inline-block';
    window.scrollTo({ top: 0, behavior: 'smooth' });
}

function resetFormulario() {
    document.getElementById('form-title').textContent = 'Nuevo Cupón';
    document.getElementById('cupon-form').reset();
    document.getElementById('cupon-id').value = '';
    document.getElementById('btn-cupon-submit').textContent = 'Guardar Cupón';
    document.getElementById('btn-cupon-cancelar').style.display = 'none';
}

async function guardarCupon() {
    const btn = document.getElementById('btn-cupon-submit');
    const successAlert = document.getElementById('cupon-success');
    const errorAlert = document.getElementById('cupon-error');
    successAlert.style.display = 'none';
    errorAlert.style.display = 'none';

    const id = document.getElementById('cupon-id').value;
    const distanciaVal = document.getElementById('cupon-distancia').value;
    
    const discountUsd = parseFloat(document.getElementById('cupon-descuento').value);
    if (isNaN(discountUsd)) {
        errorAlert.textContent = 'El descuento debe ser un número válido.';
        errorAlert.style.display = 'block';
        return;
    }
    
    let maxDistanceKm = null;
    if (distanciaVal) {
        maxDistanceKm = parseInt(distanciaVal, 10);
        if (isNaN(maxDistanceKm)) {
            errorAlert.textContent = 'La distancia máxima debe ser un número válido.';
            errorAlert.style.display = 'block';
            return;
        }
    }

    const payload = {
        code: document.getElementById('cupon-codigo').value.trim(),
        type: document.getElementById('cupon-tipo').value,
        discountUsd: discountUsd,
        maxDistanceKm: maxDistanceKm
    };

    const originalText = btn.textContent;
    btn.disabled = true;
    btn.textContent = 'Guardando...';

    try {
        if (id) {
            await fetchAPI(`/cupones/${id}`, { method: 'PUT', body: JSON.stringify(payload) });
            successAlert.textContent = 'Cupón actualizado correctamente.';
        } else {
            await fetchAPI('/cupones', { method: 'POST', body: JSON.stringify(payload) });
            successAlert.textContent = 'Cupón creado correctamente.';
        }
        successAlert.style.display = 'block';
        resetFormulario();
        await cargarCupones();
    } catch (error) {
        errorAlert.textContent = error.message || 'No se pudo guardar el cupón.';
        errorAlert.style.display = 'block';
    } finally {
        btn.disabled = false;
        btn.textContent = originalText;
    }
}

async function desactivarCupon(id) {
    mostrarModalConfirm(
        '⚠️',
        '¿Desactivar este cupón?',
        'Ya no podrá asignarse a nuevos clientes. Los cupones ya asignados seguirán vigentes.',
        'Desactivar',
        'modal-btn-danger',
        async () => {
            try {
                await fetchAPI(`/cupones/${id}/desactivar`, { method: 'PATCH' });
                cerrarModal();
                await cargarCupones();
            } catch (error) {
                mostrarModalResultado('❌', 'Error al desactivar', error.message || 'No se pudo desactivar el cupón.');
            }
        }
    );
}

async function asignarCupon(cupon) {
    const overlay = document.getElementById('modal-cupones-overlay');
    const content = document.getElementById('modal-cupones-content');

    content.innerHTML = `
        <div class="modal-icon">🎫</div>
        <h3 class="modal-title">Asignar Cupón</h3>
        <p class="modal-subtitle">Cupón <strong>${cupon.code}</strong> — $${Number(cupon.discountUsd).toFixed(2)} de descuento</p>
        <label style="display:block; font-weight:500; font-size:13px; color:var(--color-text-main); margin-bottom:6px;">
            Usuario (username) del cliente
        </label>
        <input type="text" id="modal-username-input" class="modal-input" placeholder="Ej. juanperez" autocomplete="off">
        <div id="modal-asignar-error" style="display:none; margin-top:10px; padding:8px 12px; background:#FEF2F2; border:1px solid #FECACA; border-radius:6px; font-size:13px; color:#991B1B;"></div>
        <div class="modal-actions">
            <button class="modal-btn-cancel" id="modal-btn-cancelar">Cancelar</button>
            <button class="modal-btn-success" id="modal-btn-asignar">Asignar Cupón</button>
        </div>
    `;

    overlay.classList.add('show');

    // Auto-focus en el input
    setTimeout(() => document.getElementById('modal-username-input').focus(), 100);

    document.getElementById('modal-btn-cancelar').addEventListener('click', cerrarModal);

    // Cerrar con Escape
    const escHandler = (e) => { if (e.key === 'Escape') { cerrarModal(); document.removeEventListener('keydown', escHandler); } };
    document.addEventListener('keydown', escHandler);

    // Enter para confirmar
    document.getElementById('modal-username-input').addEventListener('keydown', (e) => {
        if (e.key === 'Enter') document.getElementById('modal-btn-asignar').click();
    });

    document.getElementById('modal-btn-asignar').addEventListener('click', async () => {
        const username = document.getElementById('modal-username-input').value.trim();
        const errorDiv = document.getElementById('modal-asignar-error');

        if (!username) {
            errorDiv.textContent = 'Debes ingresar un nombre de usuario.';
            errorDiv.style.display = 'block';
            document.getElementById('modal-username-input').focus();
            return;
        }

        const btnAsignar = document.getElementById('modal-btn-asignar');
        btnAsignar.disabled = true;
        btnAsignar.textContent = 'Asignando...';
        errorDiv.style.display = 'none';

        try {
            if (!todosLosClientesCache) {
                const response = await fetchAPI('/admin/clientes');
                todosLosClientesCache = response.data || [];
            }

            const cliente = todosLosClientesCache.find(c => (c.username || '').toLowerCase() === username.toLowerCase());
            if (!cliente) {
                errorDiv.textContent = `No se encontró ningún cliente con el usuario '${username}'.`;
                errorDiv.style.display = 'block';
                btnAsignar.disabled = false;
                btnAsignar.textContent = 'Asignar Cupón';
                document.getElementById('modal-username-input').focus();
                return;
            }

            await fetchAPI(`/cupones/${cupon.id}/asignar/${cliente.id}`, { method: 'POST' });
            mostrarModalResultado('✅', 'Cupón asignado', `El cupón <strong>${cupon.code}</strong> fue asignado correctamente a <strong>${cliente.nombre} ${cliente.apellido}</strong> (${username}).`);
        } catch (error) {
            errorDiv.textContent = error.message || 'No se pudo asignar el cupón.';
            errorDiv.style.display = 'block';
            btnAsignar.disabled = false;
            btnAsignar.textContent = 'Asignar Cupón';
        }
    });
}

// — Funciones auxiliares del modal —

function mostrarModalConfirm(icono, titulo, mensaje, textoBtn, clasBtn, onConfirm) {
    const overlay = document.getElementById('modal-cupones-overlay');
    const content = document.getElementById('modal-cupones-content');

    content.innerHTML = `
        <div class="modal-icon">${icono}</div>
        <h3 class="modal-title">${titulo}</h3>
        <p class="modal-subtitle">${mensaje}</p>
        <div class="modal-actions">
            <button class="modal-btn-cancel" id="modal-btn-cancelar">Cancelar</button>
            <button class="${clasBtn}" id="modal-btn-confirmar">${textoBtn}</button>
        </div>
    `;

    overlay.classList.add('show');

    document.getElementById('modal-btn-cancelar').addEventListener('click', cerrarModal);
    document.getElementById('modal-btn-confirmar').addEventListener('click', onConfirm);

    const escHandler = (e) => { if (e.key === 'Escape') { cerrarModal(); document.removeEventListener('keydown', escHandler); } };
    document.addEventListener('keydown', escHandler);
}

function mostrarModalResultado(icono, titulo, mensajeHTML) {
    const overlay = document.getElementById('modal-cupones-overlay');
    const content = document.getElementById('modal-cupones-content');

    content.innerHTML = `
        <div style="text-align:center;">
            <div class="modal-icon">${icono}</div>
            <h3 class="modal-title" style="text-align:center;">${titulo}</h3>
            <p class="modal-result-msg">${mensajeHTML}</p>
            <div class="modal-actions" style="justify-content:center; margin-top:22px;">
                <button class="modal-btn-primary" id="modal-btn-aceptar" style="max-width:160px;">Aceptar</button>
            </div>
        </div>
    `;

    overlay.classList.add('show');
    document.getElementById('modal-btn-aceptar').addEventListener('click', cerrarModal);

    const escHandler = (e) => { if (e.key === 'Escape') { cerrarModal(); document.removeEventListener('keydown', escHandler); } };
    document.addEventListener('keydown', escHandler);
}

function cerrarModal() {
    const overlay = document.getElementById('modal-cupones-overlay');
    overlay.classList.remove('show');
}
