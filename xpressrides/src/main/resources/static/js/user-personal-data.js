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

    const desktopLinks = document.querySelectorAll('.desktop-nav a');
    if (desktopLinks.length >= 3) {
        desktopLinks[0].href = '../views/chofer-viaje.html';
        desktopLinks[1].href = '../views/chofer-travel-history.html';
        desktopLinks[1].textContent = 'Mis Viajes';
        desktopLinks[2].href = '../views/chofer-dashboard.html';
        desktopLinks[2].textContent = 'Mi perfil';
    }

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
                endpoint = `/users/${usuario.id}`;
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
}
