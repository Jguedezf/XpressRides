// user-support.js — Lógica de la página de Ayuda y Soporte
// Verifica autenticación y configura el accordion FAQ.

document.addEventListener('DOMContentLoaded', () => {
    if (!requireAuth()) return;

    configurarFAQ();
});

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
