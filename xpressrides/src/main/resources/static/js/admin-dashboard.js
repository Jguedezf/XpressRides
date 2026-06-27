document.addEventListener('DOMContentLoaded', async () => {
    // 1. Validar que el administrador tenga sesión iniciada (Regla de la Guía)
    if (!requireAuth()) return;

    // 2. Cargar los choferes apenas abra la pantalla
    await cargarChoferesPendientes();
});

// Función para obtener los postulantes de la BD
async function cargarChoferesPendientes() {
    const selectChofer = document.getElementById('choferPostulante');
    selectChofer.innerHTML = '<option value="" disabled selected>Cargando postulantes de la BD...</option>';

    try {
        // Consumimos el endpoint usando la herramienta del equipo
        const response = await fetchAPI('/admin/choferes');
        const choferes = response.data || [];

        if (choferes.length === 0) {
            selectChofer.innerHTML = '<option value="" disabled selected>No hay postulantes registrados aún...</option>';
            return;
        }

        // Llenamos el select con los datos reales
        selectChofer.innerHTML = '<option value="" disabled selected>Elige un chofer de la lista...</option>';
        choferes.forEach(chofer => {
            selectChofer.innerHTML += `<option value="${chofer.id}">${chofer.nombre} ${chofer.apellido} (${chofer.username})</option>`;
        });

    } catch (error) {
        console.error("Error al cargar choferes:", error);
        selectChofer.innerHTML = `<option value="" disabled selected>Error: ${error.message}</option>`;
    }
}

// Función para enviar las calificaciones al servidor
document.getElementById('evaluation-form').addEventListener('submit', async (e) => {
    e.preventDefault(); // Evitamos que recargue la página

    const btn = document.getElementById('btn-evaluar');
    const originalText = btn.innerText;

    const successAlert = document.getElementById('eval-success');
    const errorAlert = document.getElementById('eval-error');

    // Ocultamos alertas previas
    successAlert.style.display = 'none';
    errorAlert.style.display = 'none';

    // Feedback visual
    btn.innerText = 'Procesando...';
    btn.disabled = true;

    // Recolectamos los datos del formulario
    const choferId = document.getElementById('choferPostulante').value;
    const notaPsi = parseInt(document.getElementById('notaPsicologica').value);
    const notaVeh = parseInt(document.getElementById('notaVehicular').value);

    // Validamos que el administrador haya seleccionado a alguien
    if (!choferId) {
        errorAlert.innerText = 'Por favor, selecciona un postulante de la lista.';
        errorAlert.style.display = 'block';
        btn.innerText = originalText;
        btn.disabled = false;
        return;
    }

    try {
        // Armamos el "paquete" de datos a enviar
        const payload = {
            choferId: parseInt(choferId),
            notaPsicologica: notaPsi,
            notaVehicular: notaVeh
        };

        await fetchAPI(`/admin/choferes/${choferId}/evaluar`, {
            method: 'POST',
            body: JSON.stringify({ notaPsicologica: notaPsi, notaVehicular: notaVeh })
        });

        // Si llega hasta aquí, todo salió bien (fetchAPI maneja los errores automáticamente)
        successAlert.innerText = '¡Chofer evaluado exitosamente!';
        successAlert.style.display = 'block';

        // Limpiamos el formulario y recargamos la lista
        document.getElementById('evaluation-form').reset();
        await cargarChoferesPendientes();

    } catch (error) {
        // Errores amigables
        errorAlert.innerText = error.message;
        errorAlert.style.display = 'block';
    } finally {
        // Restauramos el botón siempre
        btn.disabled = false;
        btn.innerText = originalText;
    }
});