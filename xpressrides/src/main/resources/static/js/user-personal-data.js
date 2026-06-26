// user-personal-data.js — Datos personales del usuario
// Rellena el formulario desde localStorage y maneja el submit.

document.addEventListener('DOMContentLoaded', () => {
    if (!requireAuth()) return;

    const usuario = getUsuario();
    if (!usuario) return;

    poblarDatos(usuario);
    configurarFormulario();
});

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

        const nuevoCorreo = inputs[2] ? inputs[2].value : usuario.correo;
        const nuevoTelefono = inputs[3] ? inputs[3].value : usuario.telefono;

        try {
            // Enviar petición PUT al servidor
            await fetchAPI('/cliente/perfil', {
                method: 'PUT',
                body: JSON.stringify({
                    name: usuario.nombre,
                    lastName: usuario.apellido,
                    email: nuevoCorreo,
                    phone: nuevoTelefono,
                    isStudent: usuario.esEstudiante || false
                })
            });

            // Si es exitoso, actualizar localStorage
            usuario.correo = nuevoCorreo;
            usuario.telefono = nuevoTelefono;
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
