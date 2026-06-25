// js/registro.js
document.addEventListener('DOMContentLoaded', async () => {
    // 1. Cargar bancos desde la BD de Johanna (CatalogController)
    await cargarBancos();

    // 2. Manejar el evento de registro
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
                    endpoint = '/driver/register'; // Ruta provisional para chofer
                    payload = {
                        ...datosBase,
                        bancoId: document.getElementById('banco').value,
                        numeroCuenta: document.getElementById('cuenta').value,
                        emergencia1Nombre: document.getElementById('emergencia1_nombre').value,
                        emergencia1Tel: document.getElementById('emergencia1_tel').value,
                        emergencia2Nombre: document.getElementById('emergencia2_nombre').value,
                        emergencia2Tel: document.getElementById('emergencia2_tel').value
                    };
                } else {
                    // Datos específicos del cliente
                    endpoint = '/auth/register-cliente'; // Asumimos esta ruta de Eliuber
                    payload = {
                        ...datosBase,
                        esEstudiante: document.getElementById('es_estudiante').checked
                    };
                }

                // Llamada a la API
                await fetchAPI(endpoint, {
                    method: 'POST',
                    body: JSON.stringify(payload)
                });

                // Mostrar éxito y ocultar formulario
                registerForm.style.display = 'none';
                alertSuccess.style.display = 'block';

                // Redirigir al login tras 2 segundos
                setTimeout(() => {
                    window.location.href = '/views/login.html';
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