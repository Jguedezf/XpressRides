// js/login.js
document.addEventListener('DOMContentLoaded', () => {
    const loginForm = document.getElementById('login-form');
    const errorDiv = document.getElementById('login-error');

    if(loginForm) {
        loginForm.addEventListener('submit', async (e) => {
            e.preventDefault();

            // Ocultamos el error si estaba visible por un intento anterior
            errorDiv.style.display = 'none';

            const correo = document.getElementById('username').value;
            const password = document.getElementById('password').value;

            try {
                // Deshabilitamos el botón para evitar doble clic
                const btnSubmit = document.getElementById('btn-submit');
                btnSubmit.disabled = true;
                btnSubmit.innerText = 'Cargando...';

                const response = await fetchAPI('/auth/login', {
                    method: 'POST',
                    body: JSON.stringify({ correo, password })
                });

                // Guardamos la sesión
                localStorage.setItem('xpressUsuario', JSON.stringify(response.data));

                // Redirección basada en el rol del usuario
                const rol = (response.data.rol || '').toLowerCase();
                if (rol === 'admin') {
                    // TODO: crear admin-dashboard.html — por ahora usa el de cliente
                    window.location.href = '/views/cliente-dashboard.html';
                } else if (rol === 'chofer') {
                    // TODO: crear chofer-dashboard.html — por ahora usa el de cliente
                    window.location.href = '/views/cliente-dashboard.html';
                } else {
                    // Cliente u otro rol por defecto
                    window.location.href = '/views/cliente-dashboard.html';
                }

            } catch (error) {
                // Usamos tu div personalizado de error
                errorDiv.innerText = error.message || 'Credenciales incorrectas. Intenta de nuevo.';
                errorDiv.style.display = 'block';

                // Restauramos el botón
                const btnSubmit = document.getElementById('btn-submit');
                btnSubmit.disabled = false;
                btnSubmit.innerText = 'Iniciar sesión';
            }
        });
    }
});