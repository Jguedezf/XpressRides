// js/chofer-vehicle.js
// Carga la información del vehículo y su revisión para el chofer

document.addEventListener('DOMContentLoaded', async () => {
    if (!requireAuth()) return;
    await cargarDatosVehiculo();
});

async function cargarDatosVehiculo() {
    try {
        const result = await fetchAPI('/chofer/perfil');
        if (!result || !result.data) return;

        const data = result.data;
        
        // Cargar Vehículo
        if (data.vehiculo) {
            const veh = data.vehiculo;
            document.getElementById('vehicle-title').textContent = `${veh.marca} ${veh.modelo} (${veh.anioFabricacion})`;
            
            document.getElementById('veh-placa').value = veh.placa || 'N/A';
            document.getElementById('veh-marca').value = veh.marca || 'N/A';
            document.getElementById('veh-modelo').value = veh.modelo || 'N/A';
            document.getElementById('veh-anio').value = veh.anioFabricacion || 'N/A';
            document.getElementById('veh-color').value = veh.color || 'N/A';
        } else {
            document.getElementById('vehicle-title').textContent = 'Sin Vehículo Registrado';
        }

        // Cargar Revisión
        if (data.revisionVehiculo) {
            const rev = data.revisionVehiculo;
            document.getElementById('rev-calif').value = rev.calificacion ? `${rev.calificacion} / 100` : 'Sin calificación';
            document.getElementById('rev-fecha').value = rev.fecha ? new Date(rev.fecha).toLocaleDateString() : 'N/A';
            document.getElementById('rev-obs').value = rev.observacion || 'Sin observaciones adicionales.';
        } else {
            document.getElementById('revision-info').style.display = 'none';
        }

    } catch (e) {
        console.warn('No se pudieron cargar los datos del vehículo:', e);
        document.getElementById('vehicle-title').textContent = 'Error al cargar';
    }
}
