// js/registro.js
document.addEventListener('DOMContentLoaded', async () => {
    // 1. Cargar bancos desde la BD de Johanna (CatalogController)
    await cargarBancos();

    // 2. Manejar alternancia de formulario
    const radiosRol = document.querySelectorAll('input[name="rol"]');
    radiosRol.forEach(radio => {
        radio.addEventListener('change', window.toggleForm);
    });

    // 3. Manejar el evento de registro
    const registerForm = document.getElementById('register-form');
    if(registerForm) {
        registerForm.addEventListener('submit', async (e) => {
            e.preventDefault();

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