// js/registro.js
document.addEventListener('DOMContentLoaded', async () => {
    // 1. Cargar bancos desde la BD de Johanna (CatalogController)
    await cargarBancos();

    // 2. Manejar alternancia de formulario
    const radiosRol = document.querySelectorAll('input[name="rol"]');
    radiosRol.forEach(radio => {
        radio.addEventListener('change', window.toggleForm);
    });

    // 3. Validación en tiempo real de la contraseña
    const passwordInput = document.getElementById('password');
    if (passwordInput) {
        passwordInput.addEventListener('input', () => {
            const val = passwordInput.value;
            setRule('rule-length',  val.length >= 8);
            setRule('rule-upper',   /[A-Z]/.test(val));
            setRule('rule-lower',   /[a-z]/.test(val));
            setRule('rule-number',  /\d/.test(val));
            setRule('rule-special', /[!@#$%^&*()_+\-=\[\]{};':"\\|,.<>\/?`~]/.test(val));
        });
    }

    // 4. Manejar el evento de registro
    const registerForm = document.getElementById('register-form');
    if(registerForm) {
        registerForm.addEventListener('submit', async (e) => {
            e.preventDefault();

            // --- Validación JS antes de enviar ---
            const errores = validarFormulario();
            if (errores.length > 0) {
                alert('Corrige los siguientes errores:\n\n• ' + errores.join('\n• '));
                return;
            }

            const btnSubmit = document.getElementById('btn-submit');
            const alertSuccess = document.getElementById('register-success');

            // Determinar si es cliente o chofer
            const isChofer = document.querySelector('input[name="rol"][value="chofer"]').checked;

            // Recopilar datos comunes
            const datosBase = {
                nombre: document.getElementById('nombre').value,
                apellido: document.getElementById('apellido').value,
                cedula: document.getElementById('cedula').value,
                telefono: document.getElementById('telefono').value,
                password: document.getElementById('password').value
            };

            try {
                btnSubmit.disabled = true;
                btnSubmit.innerText = 'Creando cuenta...';

                let endpoint = '';
                let payload = {};

                if (isChofer) {
                    // Datos específicos del chofer
                    endpoint = '/auth/registro';
                    payload = {
                        name: document.getElementById('nombre').value,
                        lastName: document.getElementById('apellido').value,
                        ci: document.getElementById('cedula').value,
                        phone: document.getElementById('telefono').value,
                        password: document.getElementById('password').value,
                        username: document.getElementById('cedula').value,
                        email: document.getElementById('cedula').value + '@xpressrides.local',
                        role: 'chofer',
                        bankId: parseInt(document.getElementById('banco').value),
                        accountNumber: document.getElementById('cuenta').value
                    };
                } else {
                    // Datos específicos del cliente
                    endpoint = '/auth/registro';
                    payload = {
                        name: document.getElementById('nombre').value,
                        lastName: document.getElementById('apellido').value,
                        ci: document.getElementById('cedula').value,
                        phone: document.getElementById('telefono').value,
                        password: document.getElementById('password').value,
                        username: document.getElementById('cedula').value,
                        email: document.getElementById('cedula').value + '@xpressrides.local',
                        role: 'cliente',
                        isStudent: document.getElementById('es_estudiante').checked
                    };
                }

                // Llamada a la API
                const response = await fetchAPI(endpoint, {
                    method: 'POST',
                    body: JSON.stringify(payload)
                });

                // El chofer debe quedar con exactamente 2 contactos de emergencia
                // registrados (regla de negocio validada también en la BD).
                if (isChofer) {
                    try {
                        await registrarContactosEmergencia(response.data);
                    } catch (contactError) {
                        console.error('Error registrando contactos de emergencia:', contactError);
                        alert('Tu cuenta fue creada, pero no se pudieron guardar los contactos de '
                            + 'emergencia: ' + contactError.message
                            + '. Contacta al administrador para completarlos antes de poder recibir viajes.');
                    }
                }

                // Mostrar éxito y ocultar formulario
                registerForm.style.display = 'none';
                alertSuccess.style.display = 'block';

                // Redirigir al login tras 2 segundos
                setTimeout(() => {
                    window.location.href = '../views/login.html';
                }, 2000);

            } catch (error) {
                console.error("Error en registro:", error);
                alert("Ocurrió un error al registrar: " + error.message);
                btnSubmit.disabled = false;
                btnSubmit.innerText = 'Registrarme';
            }
        });
    }
});

// Envía los 2 contactos de emergencia obligatorios del chofer recién registrado.
// fetchAPI toma el JWT desde localStorage('xpressUsuario'); como el chofer aún
// no inició sesión formalmente (no pasó por login.html), lo fijamos aquí solo
// para estas 2 llamadas y lo removemos después.
async function registrarContactosEmergencia(usuarioRegistrado) {
    localStorage.setItem('xpressUsuario', JSON.stringify(usuarioRegistrado));
    try {
        const contactos = [
            {
                driverId: usuarioRegistrado.driverId,
                name: document.getElementById('emergencia1_nombre').value,
                phone: document.getElementById('emergencia1_tel').value,
                relationship: document.getElementById('emergencia1_parentesco').value
            },
            {
                driverId: usuarioRegistrado.driverId,
                name: document.getElementById('emergencia2_nombre').value,
                phone: document.getElementById('emergencia2_tel').value,
                relationship: document.getElementById('emergencia2_parentesco').value
            }
        ];

        for (const contacto of contactos) {
            await fetchAPI('/emergencias', {
                method: 'POST',
                body: JSON.stringify(contacto)
            });
        }
    } finally {
        localStorage.removeItem('xpressUsuario');
    }
}

async function cargarBancos() {
    try {
        const response = await fetchAPI('/bancos');
        const bancos = response.data;
        const selectBanco = document.getElementById('banco');

        selectBanco.innerHTML = '<option value="">Seleccione un banco...</option>';
        bancos.forEach(banco => {
            selectBanco.add(new Option(banco.name || banco.nombre, banco.id));
        });
    } catch (error) {
        console.error("No se pudieron cargar los bancos:", error);
    }
}

// Función global para alternar entre formulario de cliente y chofer
window.toggleForm = function() {
    const isChofer = document.querySelector('input[name="rol"][value="chofer"]').checked;
    
    document.getElementById('campos-cliente').style.display = isChofer ? 'none' : 'block';
    document.getElementById('campos-chofer').style.display = isChofer ? 'block' : 'none';
    
    document.getElementById('lbl-cliente').classList.toggle('active', !isChofer);
    document.getElementById('lbl-chofer').classList.toggle('active', isChofer);
};

// ========================================================================
// VALIDACIONES
// ========================================================================
const REGEX_NOMBRE   = /^[a-zA-ZáéíóúÁÉÍÓÚñÑüÜ\s]+$/;
const REGEX_CEDULA   = /^[VE]-\d{7,9}$/;
const REGEX_TELEFONO = /^(0414|0424|0416|0426|0412)-?\d{7}$/;
const REGEX_PASSWORD = /^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[!@#$%^&*()_+\-=\[\]{};':"\\|,.<>\/?`~]).{8,}$/;
const REGEX_CUENTA   = /^\d{20}$/;

function validarFormulario() {
    const errores = [];
    const isChofer = document.querySelector('input[name="rol"][value="chofer"]').checked;

    const nombre   = document.getElementById('nombre').value.trim();
    const apellido = document.getElementById('apellido').value.trim();
    const cedula   = document.getElementById('cedula').value.trim();
    const telefono = document.getElementById('telefono').value.trim();
    const password = document.getElementById('password').value;

    // Nombre
    if (!nombre) errores.push('El nombre es obligatorio.');
    else if (!REGEX_NOMBRE.test(nombre)) errores.push('El nombre solo debe contener letras y espacios.');

    // Apellido
    if (!apellido) errores.push('El apellido es obligatorio.');
    else if (!REGEX_NOMBRE.test(apellido)) errores.push('El apellido solo debe contener letras y espacios.');

    // Cédula
    if (!cedula) errores.push('La cédula es obligatoria.');
    else if (!REGEX_CEDULA.test(cedula)) errores.push('La cédula debe tener formato V-12345678 o E-12345678 (V mayúscula).');

    // Teléfono
    if (!telefono) errores.push('El teléfono es obligatorio.');
    else if (!REGEX_TELEFONO.test(telefono)) errores.push('Teléfono inválido. Usa formato 0414-1234567 o 04141234567 con prefijo válido.');

    // Contraseña
    if (!password) errores.push('La contraseña es obligatoria.');
    else if (password.length < 8) errores.push('La contraseña debe tener al menos 8 caracteres.');
    else if (!/[A-Z]/.test(password)) errores.push('La contraseña debe contener al menos una letra mayúscula.');
    else if (!/[a-z]/.test(password)) errores.push('La contraseña debe contener al menos una letra minúscula.');
    else if (!/\d/.test(password)) errores.push('La contraseña debe contener al menos un número.');
    else if (!/[!@#$%^&*()_+\-=\[\]{};':"\\|,.<>\/?`~]/.test(password)) errores.push('La contraseña debe contener al menos un carácter especial (ej: @, !, #, $).');

    // Campos de chofer
    if (isChofer) {
        const banco  = document.getElementById('banco').value;
        const cuenta = document.getElementById('cuenta').value.trim();

        if (!banco) errores.push('Debes seleccionar un banco.');
        if (!cuenta) errores.push('El número de cuenta es obligatorio.');
        else if (!REGEX_CUENTA.test(cuenta)) errores.push('El número de cuenta debe ser exactamente 20 dígitos numéricos.');

        // Contactos de emergencia
        const e1n = document.getElementById('emergencia1_nombre').value.trim();
        const e1t = document.getElementById('emergencia1_tel').value.trim();
        const e1p = document.getElementById('emergencia1_parentesco').value.trim();
        const e2n = document.getElementById('emergencia2_nombre').value.trim();
        const e2t = document.getElementById('emergencia2_tel').value.trim();
        const e2p = document.getElementById('emergencia2_parentesco').value.trim();

        if (!e1n || !REGEX_NOMBRE.test(e1n)) errores.push('Nombre del contacto 1: solo letras y espacios.');
        if (!e1t || !REGEX_TELEFONO.test(e1t)) errores.push('Teléfono del contacto 1: formato inválido.');
        if (!e1p || !REGEX_NOMBRE.test(e1p)) errores.push('Parentesco del contacto 1: solo letras y espacios.');

        if (!e2n || !REGEX_NOMBRE.test(e2n)) errores.push('Nombre del contacto 2: solo letras y espacios.');
        if (!e2t || !REGEX_TELEFONO.test(e2t)) errores.push('Teléfono del contacto 2: formato inválido.');
        if (!e2p || !REGEX_NOMBRE.test(e2p)) errores.push('Parentesco del contacto 2: solo letras y espacios.');
    }

    return errores;
}

function setRule(id, ok) {
    const el = document.getElementById(id);
    if (!el) return;
    el.classList.toggle('pass', ok);
    el.classList.toggle('fail', !ok);
}