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
                    window.location.href = '/views/admin-dashboard.html';
                } else if (rol === 'chofer') {
                    window.location.href = '/views/chofer-viaje.html';
                } else {
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

    // Lógica para mostrar/ocultar contraseña
    const togglePasswordBtn = document.getElementById('toggle-password');
    const passwordInput = document.getElementById('password');
    const eyeIcon = document.getElementById('eye-icon');

    if (togglePasswordBtn && passwordInput && eyeIcon) {
        togglePasswordBtn.addEventListener('click', () => {
            const isPassword = passwordInput.type === 'password';
            passwordInput.type = isPassword ? 'text' : 'password';
            
            if (isPassword) {
                // Icono de ojo tachado (ocultar)
                eyeIcon.innerHTML = `
                    <path d="M17.94 17.94A10.07 10.07 0 0 1 12 20c-7 0-11-8-11-8a18.45 18.45 0 0 1 5.06-5.94M9.9 4.24A9.12 9.12 0 0 1 12 4c7 0 11 8 11 8a18.5 18.5 0 0 1-2.16 3.19m-6.72-1.07a3 3 0 1 1-4.24-4.24"></path>
                    <line x1="1" y1="1" x2="23" y2="23"></line>
                `;
            } else {
                // Icono de ojo normal (mostrar)
                eyeIcon.innerHTML = `
                    <path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z"></path>
                    <circle cx="12" cy="12" r="3"></circle>
                `;
            }
        });
    }
});