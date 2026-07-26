// user-personal-data.js — Datos personales del usuario
// Rellena el formulario desde localStorage y maneja el submit.

document.addEventListener('DOMContentLoaded', () => {
    if (!requireAuth()) return;

    const usuario = getUsuario();
    if (!usuario) return;

    ajustarNavegacionPorRol(usuario);
    poblarDatos(usuario);
    configurarFormulario();
});

function ajustarNavegacionPorRol(usuario) {
    if (usuario.rol !== 'chofer') return;

    const bottomLinks = document.querySelectorAll('.bottom-nav a');
    if (bottomLinks.length >= 3) {
        bottomLinks[0].href = '../views/chofer-viaje.html';
        const span0 = bottomLinks[0].querySelector('span');
        if (span0) span0.textContent = 'Inicio';

        bottomLinks[1].href = '../views/chofer-travel-history.html';
        const span1 = bottomLinks[1].querySelector('span');
        if (span1) span1.textContent = 'Viajes';

        bottomLinks[2].href = '../views/chofer-dashboard.html';
        const span2 = bottomLinks[2].querySelector('span');
        if (span2) span2.textContent = 'Panel';
    }

    const backBtn = document.querySelector('main div[onclick*="user-profile"]');
    if (backBtn) {
        backBtn.setAttribute('onclick', "window.location.href='chofer-dashboard.html'");
    }

    // Ajustar colores para el chofer
    const avatar = document.querySelector('.avatar-large');
    if (avatar) avatar.style.backgroundColor = 'var(--color-secondary)';
    
    const textCambiar = document.querySelector('.avatar-edit-container span.text-small');
    if (textCambiar) textCambiar.style.color = 'var(--color-secondary)';
    
    const btnUpdate = document.getElementById('btn-update');
    if (btnUpdate) btnUpdate.style.backgroundColor = 'var(--color-secondary)';
    
    cargarDatosAdicionalesChofer();
}

async function cargarDatosAdicionalesChofer() {
    try {
        const result = await fetchAPI('/chofer/perfil');
        if (result && result.data && result.data.evaluacionPsicologica) {
            const evalData = result.data.evaluacionPsicologica;
            const container = document.getElementById('eval-psico-container');
            const calif = document.getElementById('eval-calif');
            const fecha = document.getElementById('eval-fecha');
            const obs = document.getElementById('eval-obs');
            
            if (container && calif && fecha && obs) {
                calif.value = evalData.calificacion ? `${evalData.calificacion} / 100` : 'Sin calificación';
                fecha.value = evalData.fecha ? new Date(evalData.fecha).toLocaleDateString() : 'N/A';
                obs.value = evalData.observacion || 'Sin observaciones adicionales.';
                container.style.display = 'block';
            }
        }
    } catch (e) {
        console.warn('No se pudieron cargar los datos adicionales del chofer:', e);
    }
    
    // Cargar también los contactos de emergencia
    cargarContactosEmergencia();
}

async function cargarContactosEmergencia() {
    const container = document.getElementById('contactos-emergencia-container');
    const lista = document.getElementById('lista-emergencias');
    if (!container || !lista) return;

    try {
        const contactos = await fetchAPI('/emergencias'); // El token identificará al chofer
        container.style.display = 'block';

        if (!contactos || contactos.length === 0) {
            lista.innerHTML = '<p class="text-small" style="color:var(--color-text-muted);">No tienes contactos de emergencia registrados.</p>';
            return;
        }

        let html = '';
        contactos.forEach(c => {
            html += `
            <div class="mb-sm" style="background: white; padding: 16px; border-radius: 12px; border: 1px solid #e0e0e0; display: flex; align-items: center; justify-content: space-between; box-shadow: 0 2px 4px rgba(0,0,0,0.02); transition: transform 0.2s; cursor: default;">
                <div style="flex-grow: 1; min-width: 0;">
                    <div class="d-flex align-center gap-sm mb-xs" style="flex-wrap: wrap;">
                        <strong style="color:var(--color-secondary); font-size:15px; white-space: nowrap; overflow: hidden; text-overflow: ellipsis;">${c.name}</strong>
                        <span class="badge-primary" style="font-size:10px; padding: 2px 6px; white-space: nowrap;">${c.relationship}</span>
                    </div>
                    <div style="color:var(--color-text-muted); font-size:14px; font-weight: 500; letter-spacing: 0.5px;">
                        <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" style="vertical-align: text-bottom; margin-right: 4px; opacity: 0.7;"><path d="M22 16.92v3a2 2 0 0 1-2.18 2 19.79 19.79 0 0 1-8.63-3.07 19.5 19.5 0 0 1-6-6 19.79 19.79 0 0 1-3.07-8.67A2 2 0 0 1 4.11 2h3a2 2 0 0 1 2 1.72 12.84 12.84 0 0 0 .7 2.81 2 2 0 0 1-.45 2.11L8.09 9.91a16 16 0 0 0 6 6l1.27-1.27a2 2 0 0 1 2.11-.45 12.84 12.84 0 0 0 2.81.7A2 2 0 0 1 22 16.92z"></path></svg>
                        ${c.phone}
                    </div>
                </div>
                <button style="background: var(--color-bg-main); border: 1px solid #eee; border-radius: 8px; padding: 10px; cursor: pointer; color: var(--color-primary); flex-shrink: 0; display: flex; align-items: center; justify-content: center; transition: all 0.2s;" onclick="editarContactoEmergencia(${c.id}, '${c.name}', '${c.phone}', '${c.relationship}')" onmouseover="this.style.background='#f0f0f0'" onmouseout="this.style.background='var(--color-bg-main)'" title="Editar">
                    <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                        <path d="M12 20h9"></path>
                        <path d="M16.5 3.5a2.121 2.121 0 0 1 3 3L7 19l-4 1 1-4L16.5 3.5z"></path>
                    </svg>
                </button>
            </div>`;
        });
        
        lista.innerHTML = html;

    } catch (e) {
        console.error('Error al cargar contactos de emergencia:', e);
        lista.innerHTML = '<p class="text-small" style="color:var(--color-error);">No se pudieron cargar los contactos.</p>';
    }
}

function editarContactoEmergencia(id, nombreActual, telefonoActual, parentescoActual) {
    document.getElementById('edit-emergencia-id').value = id;
    document.getElementById('edit-emergencia-nombre').value = nombreActual;
    document.getElementById('edit-emergencia-telefono').value = telefonoActual;
    document.getElementById('edit-emergencia-parentesco').value = parentescoActual;
    document.getElementById('modal-editar-emergencia').style.display = 'flex';
}

function cerrarModalEmergencia() {
    document.getElementById('modal-editar-emergencia').style.display = 'none';
}

/**
 * Rellena el avatar y los campos del formulario con datos del usuario.
 * Los inputs de nombre y cédula son readonly; correo y teléfono editables.
 */
function poblarDatos(usuario) {
    // Avatar con iniciales
    const avatar = document.querySelector('.avatar-large');
    if (avatar) {
        const ini1 = usuario.nombre ? usuario.nombre.charAt(0) : '';
        const ini2 = usuario.apellido ? usuario.apellido.charAt(0) : '';
        avatar.textContent = `${ini1}${ini2}`.toUpperCase() || '??';
    }

    // Los inputs no tienen IDs, así que los seleccionamos por orden dentro del form
    const form = document.getElementById('form-datos');
    if (!form) return;

    const inputs = form.querySelectorAll('.input-field');
    // Orden: [0] nombre completo, [1] cédula, [2] correo, [3] teléfono

    if (inputs[0]) {
        const nombreCompleto = `${usuario.nombre || ''} ${usuario.apellido || ''}`.trim();
        inputs[0].value = nombreCompleto || 'Sin nombre';
    }

    if (inputs[1]) {
        inputs[1].value = usuario.cedula || 'Sin cédula';
    }

    if (inputs[2]) {
        inputs[2].value = usuario.correo || usuario.email || '';
    }

    if (inputs[3]) {
        inputs[3].value = usuario.telefono || '';
    }
}

function configurarFormulario() {
    const form = document.getElementById('form-datos');
    if (!form) return;

    form.addEventListener('submit', async (e) => {
        e.preventDefault();

        const btn = document.getElementById('btn-update');
        btn.innerText = 'Guardando...';
        btn.disabled = true;

        // Leer valores editables del formulario
        const inputs = form.querySelectorAll('.input-field');
        const usuario = getUsuario() || {};

        const nuevoCorreo = inputs[2] ? inputs[2].value : (usuario.correo || usuario.email);
        const nuevoTelefono = inputs[3] ? inputs[3].value : (usuario.telefono || usuario.phone);

        try {
            const rol = (usuario.rol || '').toLowerCase();
            let endpoint = '/cliente/perfil';
            let bodyPayload;

            if (rol === 'chofer') {
                const idToUpdate = usuario.usuarioId || usuario.id;
                endpoint = `/users/${idToUpdate}`;
                bodyPayload = {
                    name: usuario.nombre || usuario.name,
                    lastName: usuario.apellido || usuario.lastName,
                    email: nuevoCorreo,
                    phone: nuevoTelefono,
                    ci: usuario.cedula || usuario.ci || (inputs[1] ? inputs[1].value : '')
                };
            } else {
                bodyPayload = {
                    name: usuario.nombre,
                    lastName: usuario.apellido,
                    email: nuevoCorreo,
                    phone: nuevoTelefono,
                    isStudent: usuario.esEstudiante || false
                };
            }

            // Enviar petición PUT al servidor
            await fetchAPI(endpoint, {
                method: 'PUT',
                body: JSON.stringify(bodyPayload)
            });

            // Si es exitoso, actualizar localStorage
            usuario.correo = nuevoCorreo;
            usuario.email = nuevoCorreo;
            usuario.telefono = nuevoTelefono;
            usuario.phone = nuevoTelefono;
            localStorage.setItem('xpressUsuario', JSON.stringify(usuario));

            // Feedback visual de éxito
            btn.innerText = '¡Datos Actualizados!';
            btn.style.backgroundColor = 'var(--color-success)';

        } catch (error) {
            console.error('Error actualizando perfil:', error);
            // Feedback visual de error
            btn.innerText = 'Error al guardar';
            btn.style.backgroundColor = 'var(--color-error)';
            alert(error.message || 'No se pudieron actualizar los datos.');
        } finally {
            setTimeout(() => {
                btn.innerText = 'Actualizar Datos';
                btn.disabled = false;
                btn.style.backgroundColor = 'var(--color-primary)';
            }, 2000);
        }
    });

    const formEmergencia = document.getElementById('form-editar-emergencia');
    if (formEmergencia) {
        formEmergencia.addEventListener('submit', async (e) => {
            e.preventDefault();
            const id = document.getElementById('edit-emergencia-id').value;
            const nuevoNombre = document.getElementById('edit-emergencia-nombre').value.trim();
            const nuevoTelefono = document.getElementById('edit-emergencia-telefono').value.trim();
            const nuevoParentesco = document.getElementById('edit-emergencia-parentesco').value.trim();
            
            const REGEX_NOMBRE = /^[a-zA-ZáéíóúÁÉÍÓÚñÑ\s]+$/;
            const REGEX_TELEFONO = /^04(14|24|16|26|12)-?\d{7}$/;
            
            if (!REGEX_NOMBRE.test(nuevoNombre)) {
                alert('El nombre solo debe contener letras y espacios.');
                return;
            }
            if (!REGEX_TELEFONO.test(nuevoTelefono)) {
                alert('Teléfono inválido. Usa formato 0414-1234567 o 04141234567 con prefijo válido.');
                return;
            }
            if (!REGEX_NOMBRE.test(nuevoParentesco)) {
                alert('El parentesco solo debe contener letras y espacios.');
                return;
            }
            
            try {
                const usuario = getUsuario();
                await fetchAPI('/emergencias/' + id, {
                    method: 'PUT',
                    body: JSON.stringify({
                        driverId: usuario.id,
                        name: nuevoNombre,
                        phone: nuevoTelefono,
                        relationship: nuevoParentesco
                    })
                });
                alert('Contacto actualizado con éxito.');
                cerrarModalEmergencia();
                cargarContactosEmergencia(); // Recargar la lista
            } catch (err) {
                console.error('Error actualizando contacto:', err);
                alert('No se pudo actualizar el contacto de emergencia.');
            }
        });
    }
}
