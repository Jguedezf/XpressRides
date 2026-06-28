// js/chofer-vehicle.js
// Carga la información del vehículo y su revisión para el chofer, y maneja el registro/actualización.

let currentDriverId = null;
let currentVehicle = null;

document.addEventListener('DOMContentLoaded', async () => {
    if (!requireAuth()) return;
    await cargarDatosVehiculo();
    configurarFormularioVehiculo();
});

async function cargarDatosVehiculo() {
    try {
        const result = await fetchAPI('/chofer/perfil');
        if (!result || !result.data) return;

        const data = result.data;
        currentDriverId = data.id;
        
        const infoCard = document.getElementById('vehiculo-info');
        const formCard = document.getElementById('vehiculo-form-container');
        const btnEdit = document.getElementById('btn-edit-vehicle');

        // Cargar Vehículo
        if (data.vehiculo) {
            currentVehicle = data.vehiculo;
            document.getElementById('vehicle-title').textContent = `${currentVehicle.marca} ${currentVehicle.modelo} (${currentVehicle.anioFabricacion})`;
            
            document.getElementById('veh-placa').value = currentVehicle.placa || 'N/A';
            document.getElementById('veh-marca').value = currentVehicle.marca || 'N/A';
            document.getElementById('veh-modelo').value = currentVehicle.modelo || 'N/A';
            document.getElementById('veh-anio').value = currentVehicle.anioFabricacion || 'N/A';
            document.getElementById('veh-color').value = currentVehicle.color || 'N/A';

            infoCard.style.display = 'block';
            formCard.style.display = 'none';
            btnEdit.style.display = 'block';
        } else {
            currentVehicle = null;
            document.getElementById('vehicle-title').textContent = 'Sin Vehículo Registrado';
            infoCard.style.display = 'none';
            formCard.style.display = 'block';
            btnEdit.style.display = 'none';
            
            document.getElementById('form-title').textContent = 'Registrar Vehículo';
            document.getElementById('btn-cancel-edit').style.display = 'none';
        }

        // Cargar Revisión
        if (data.revisionVehiculo) {
            const rev = data.revisionVehiculo;
            document.getElementById('revision-info').style.display = 'block';
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

function configurarFormularioVehiculo() {
    const btnEdit = document.getElementById('btn-edit-vehicle');
    const btnCancel = document.getElementById('btn-cancel-edit');
    const infoCard = document.getElementById('vehiculo-info');
    const formCard = document.getElementById('vehiculo-form-container');
    const form = document.getElementById('vehiculo-form');

    if (btnEdit) {
        btnEdit.addEventListener('click', () => {
            if (!currentVehicle) return;
            // Pre-rellenar formulario
            document.getElementById('reg-placa').value = currentVehicle.placa || '';
            document.getElementById('reg-marca').value = currentVehicle.marca || '';
            document.getElementById('reg-modelo').value = currentVehicle.modelo || '';
            document.getElementById('reg-anio').value = currentVehicle.anioFabricacion || '';
            document.getElementById('reg-color').value = currentVehicle.color || '';

            document.getElementById('form-title').textContent = 'Editar Vehículo';
            btnCancel.style.display = 'inline-block';
            
            infoCard.style.display = 'none';
            formCard.style.display = 'block';
        });
    }

    if (btnCancel) {
        btnCancel.addEventListener('click', () => {
            infoCard.style.display = 'block';
            formCard.style.display = 'none';
        });
    }

    if (form) {
        form.addEventListener('submit', async (e) => {
            e.preventDefault();

            if (!currentDriverId) {
                alert('No se pudo determinar el ID del chofer. Intente recargar la página.');
                return;
            }

            const btnSubmit = document.getElementById('btn-submit-vehiculo');
            const originalText = btnSubmit.textContent;
            btnSubmit.disabled = true;
            btnSubmit.textContent = 'Guardando...';

            const payload = {
                plate: document.getElementById('reg-placa').value.trim(),
                brand: document.getElementById('reg-marca').value.trim(),
                model: document.getElementById('reg-modelo').value.trim(),
                year: parseInt(document.getElementById('reg-anio').value, 10),
                color: document.getElementById('reg-color').value.trim(),
                driverId: currentDriverId
            };

            try {
                await fetchAPI('/vehiculo/registrar', {
                    method: 'POST',
                    body: JSON.stringify(payload)
                });

                alert('Vehículo guardado correctamente.');
                await cargarDatosVehiculo();
            } catch (error) {
                console.error('Error al guardar el vehículo:', error);
                alert(error.message || 'Error al guardar el vehículo.');
            } finally {
                btnSubmit.disabled = false;
                btnSubmit.textContent = originalText;
            }
        });
    }
}
