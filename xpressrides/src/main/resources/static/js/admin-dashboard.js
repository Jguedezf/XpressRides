document.addEventListener('DOMContentLoaded', async () => {
    // 1. Validar que el administrador tenga sesión iniciada (Regla de la Guía)
    if (!requireAuth()) return;

    // 2. Cargar datos
    await cargarMetricas();
    await cargarTablaConductores();
    await cargarChoferesPendientes();
});

// Función para obtener e incrementar métricas del admin
async function cargarMetricas() {
    try {
        const activeTripsRes = await fetchAPI('/admin/traslados/activos');
        const activeTripsCount = (activeTripsRes.data || []).length;
        document.getElementById('metric-active-trips').textContent = activeTripsCount;
    } catch (e) {
        console.error('Error cargando métrica de viajes activos:', e);
    }

    try {
        const driversRes = await fetchAPI('/admin/choferes');
        const driversCount = (driversRes.data || []).length;
        document.getElementById('metric-total-drivers').textContent = driversCount;
    } catch (e) {
        console.error('Error cargando métrica de conductores:', e);
    }

    try {
        const customersRes = await fetchAPI('/admin/clientes');
        const customersCount = (customersRes.data || []).length;
        document.getElementById('metric-total-customers').textContent = customersCount;
    } catch (e) {
        console.error('Error cargando métrica de clientes:', e);
    }
}

// Función para obtener y renderizar la tabla de choferes
async function cargarTablaConductores() {
    const tbody = document.getElementById('drivers-table-body');
    if (!tbody) return;

    try {
        const response = await fetchAPI('/admin/choferes');
        const choferes = response.data || [];

        if (choferes.length === 0) {
            tbody.innerHTML = `<tr><td colspan="6" style="text-align: center; padding: 12px; color: var(--color-text-muted);">No hay conductores registrados</td></tr>`;
            return;
        }

        tbody.innerHTML = '';
        choferes.forEach(chofer => {
            const tr = document.createElement('tr');
            tr.style.borderBottom = '1px solid #eee';

            const idTd = document.createElement('td');
            idTd.style.padding = '12px 8px';
            idTd.textContent = chofer.id;

            const nameTd = document.createElement('td');
            nameTd.style.padding = '12px 8px';
            nameTd.textContent = `${chofer.nombre || ''} ${chofer.apellido || ''}`;

            const usernameTd = document.createElement('td');
            usernameTd.style.padding = '12px 8px';
            usernameTd.textContent = chofer.username || 'N/A';

            const balanceTd = document.createElement('td');
            balanceTd.style.padding = '12px 8px';
            const balanceVal = chofer.saldoAcumuladoUsd != null ? Number(chofer.saldoAcumuladoUsd) : 0;
            balanceTd.textContent = `$${balanceVal.toFixed(2)}`;

            const statusTd = document.createElement('td');
            statusTd.style.padding = '12px 8px';
            const badge = document.createElement('span');
            badge.style.padding = '4px 8px';
            badge.style.borderRadius = '4px';
            badge.style.fontSize = '12px';
            badge.style.fontWeight = '600';
            if (chofer.habilitado) {
                badge.style.backgroundColor = '#d4edda';
                badge.style.color = '#155724';
                badge.textContent = 'Habilitado';
            } else {
                badge.style.backgroundColor = '#f8d7da';
                badge.style.color = '#721c24';
                badge.textContent = 'Deshabilitado';
            }
            statusTd.appendChild(badge);

            const actionTd = document.createElement('td');
            actionTd.style.padding = '12px 8px';
            actionTd.style.textAlign = 'center';
            
            const btn = document.createElement('button');
            btn.style.padding = '6px 12px';
            btn.style.fontSize = '12px';
            btn.style.cursor = 'pointer';
            btn.style.border = 'none';
            btn.style.borderRadius = '4px';
            btn.style.fontWeight = '600';
            
            if (chofer.habilitado) {
                btn.style.backgroundColor = '#dc3545';
                btn.style.color = 'white';
                btn.textContent = 'Deshabilitar';
            } else {
                btn.style.backgroundColor = '#28a745';
                btn.style.color = 'white';
                btn.textContent = 'Habilitar';
            }

            btn.addEventListener('click', () => toggleHabilitarChofer(chofer.id, chofer.habilitado));
            actionTd.appendChild(btn);

            tr.appendChild(idTd);
            tr.appendChild(nameTd);
            tr.appendChild(usernameTd);
            tr.appendChild(balanceTd);
            tr.appendChild(statusTd);
            tr.appendChild(actionTd);

            tbody.appendChild(tr);
        });

    } catch (error) {
        console.error("Error al cargar la tabla de choferes:", error);
        tbody.innerHTML = `<tr><td colspan="6" style="text-align: center; padding: 12px; color: var(--color-error);">Error al cargar los datos</td></tr>`;
    }
}

// Función para habilitar o deshabilitar un chofer
async function toggleHabilitarChofer(driverId, currentStatus) {
    try {
        const nextStatus = !currentStatus;
        await fetchAPI(`/chofer/habilitar/${driverId}`, {
            method: 'PUT',
            body: JSON.stringify({ enabled: nextStatus })
        });

        alert(`Chofer ${nextStatus ? 'habilitado' : 'deshabilitado'} correctamente.`);
        
        await cargarMetricas();
        await cargarTablaConductores();
        await cargarChoferesPendientes();
    } catch (e) {
        console.error('Error al cambiar habilitación de chofer:', e);
        alert(e.message || 'No se pudo actualizar el estado de habilitación.');
    }
}

// Función para obtener los postulantes de la BD
async function cargarChoferesPendientes() {
    const selectChofer = document.getElementById('choferPostulante');
    if (!selectChofer) return;
    
    selectChofer.innerHTML = '<option value="" disabled selected>Cargando postulantes de la BD...</option>';

    try {
        // Consumimos el endpoint usando la herramienta del equipo
        const response = await fetchAPI('/admin/choferes');
        const choferes = response.data || [];

        // Filtramos postulantes que aún no tengan evaluaciones aprobadas completas o estén deshabilitados
        // El panel de postulantes usualmente muestra a todos o podemos mostrar los que no están habilitados
        const postulantes = choferes.filter(c => !c.habilitado);

        if (postulantes.length === 0) {
            selectChofer.innerHTML = '<option value="" disabled selected>No hay postulantes registrados aún...</option>';
            return;
        }

        // Llenamos el select con los datos reales
        selectChofer.innerHTML = '<option value="" disabled selected>Elige un chofer de la lista...</option>';
        postulantes.forEach(chofer => {
            selectChofer.innerHTML += `<option value="${chofer.id}">${chofer.nombre} ${chofer.apellido} (${chofer.username})</option>`;
        });

    } catch (error) {
        console.error("Error al cargar choferes postulantes:", error);
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
        await fetchAPI(`/admin/choferes/${choferId}/evaluar`, {
            method: 'POST',
            body: JSON.stringify({ notaPsicologica: notaPsi, notaVehicular: notaVeh })
        });

        // Si llega hasta aquí, todo salió bien
        successAlert.innerText = '¡Chofer evaluado exitosamente!';
        successAlert.style.display = 'block';

        // Limpiamos el formulario y recargamos datos
        document.getElementById('evaluation-form').reset();
        await cargarMetricas();
        await cargarTablaConductores();
        await cargarChoferesPendientes();

    } catch (error) {
        errorAlert.innerText = error.message;
        errorAlert.style.display = 'block';
    } finally {
        btn.disabled = false;
        btn.innerText = originalText;
    }
});