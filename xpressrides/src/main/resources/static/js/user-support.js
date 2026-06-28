// user-support.js — Lógica de la página de Ayuda y Soporte
// Verifica autenticación y configura el accordion FAQ.

document.addEventListener('DOMContentLoaded', () => {
    if (!requireAuth()) return;

    const usuario = getUsuario();
    if (!usuario) return;

    ajustarNavegacionPorRol(usuario);
    configurarFAQ();
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
}

/**
 * Configura el comportamiento accordion de las preguntas frecuentes.
 * Al hacer clic en una pregunta, se expande/colapsa la respuesta.
 * Solo una pregunta puede estar abierta a la vez.
 */
function configurarFAQ() {
    document.querySelectorAll('.faq-question').forEach(question => {
        question.addEventListener('click', () => {
            const item = question.parentElement;
            const icon = question.querySelector('.faq-toggle');

            // Cerrar todas las demás preguntas
            document.querySelectorAll('.faq-item').forEach(faq => {
                if (faq !== item) {
                    faq.classList.remove('active');
                    const otherIcon = faq.querySelector('.faq-toggle');
                    if (otherIcon) otherIcon.textContent = '+';
                }
            });

            // Toggle de la pregunta actual
            item.classList.toggle('active');
            if (icon) {
                icon.textContent = item.classList.contains('active') ? '−' : '+';
            }
        });
    });
}
