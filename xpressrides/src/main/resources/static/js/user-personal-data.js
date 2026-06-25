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

/**
 * Maneja el submit del formulario.
 * Como no existe endpoint PUT para actualizar datos,
 * guardamos en localStorage y mostramos feedback visual.
 */
function configurarFormulario() {
    const form = document.getElementById('form-datos');
    if (!form) return;

    form.addEventListener('submit', (e) => {
        e.preventDefault();

        const btn = document.getElementById('btn-update');
        btn.innerText = 'Guardando...';
        btn.disabled = true;

        // Leer valores editables del formulario
        const inputs = form.querySelectorAll('.input-field');
        const usuario = getUsuario() || {};

        if (inputs[2]) usuario.correo = inputs[2].value;
        if (inputs[3]) usuario.telefono = inputs[3].value;

        // Actualizar localStorage
        localStorage.setItem('xpressUsuario', JSON.stringify(usuario));

        // Feedback visual
        setTimeout(() => {
            btn.innerText = '¡Datos Actualizados!';
            btn.style.backgroundColor = 'var(--color-success)';

            setTimeout(() => {
                btn.innerText = 'Actualizar Datos';
                btn.disabled = false;
                btn.style.backgroundColor = 'var(--color-primary)';
            }, 2000);
        }, 600);
    });
}
