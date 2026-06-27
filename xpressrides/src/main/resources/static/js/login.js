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

                const response = await fetchAPI('/auth/iniciar-sesion', {
                    method: 'POST',
                    body: JSON.stringify({ username: correo, password })
                });

                // Guardamos la sesión (response ya tiene data)
                const userData = response.data;
                localStorage.setItem('xpressUsuario', JSON.stringify(userData));

                // Redirección basada en el rol del usuario
                const rol = (userData.rol || userData.role || '').toLowerCase();
                if (rol === 'admin' || rol === 'administrador' || rol === 'personal_admin') {
                    window.location.href = '../views/admin-dashboard.html';
                } else if (rol === 'chofer') {
                    window.location.href = '../views/chofer-dashboard.html';
                } else {
                    window.location.href = '../views/cliente-dashboard.html';
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