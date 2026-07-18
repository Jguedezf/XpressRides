// js/chofer-vehicle.js
// Carga los vehículos del chofer (puede tener varios) y su revisión, y maneja
// el registro de vehículos nuevos y el cambio de cuál está en uso.

let currentDriverId = null;

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

        const vehiculos = data.vehiculos || [];
        renderizarVehiculos(vehiculos);

        const formTitle = document.getElementById('form-title');
        formTitle.textContent = vehiculos.length === 0 ? 'Registrar Vehículo' : 'Registrar otro vehículo';

        if (vehiculos.length === 0) {
            document.getElementById('vehicle-title').textContent = 'Sin Vehículo Registrado';
        } else if (vehiculos.length === 1) {
            const v = vehiculos[0];
            document.getElementById('vehicle-title').textContent = `${v.marca} ${v.modelo} (${v.anioFabricacion})`;
        } else {
            document.getElementById('vehicle-title').textContent = `${vehiculos.length} vehículos registrados`;
        }

    } catch (e) {
        console.warn('No se pudieron cargar los datos del vehículo:', e);
        document.getElementById('vehicle-title').textContent = 'Error al cargar';
    }
}

function renderizarVehiculos(vehiculos) {
    const container = document.getElementById('vehiculos-container');
    const template = document.getElementById('vehiculo-card-template');
    container.innerHTML = '';

    vehiculos.forEach((v) => {
        const fragment = template.content.cloneNode(true);
        const card = fragment.querySelector('.vehiculo-card');
        card.id = `vehiculo-card-${v.id}`;

        card.querySelector('.veh-placa').value = v.placa || 'N/A';
        card.querySelector('.veh-marca').value = v.marca || 'N/A';
        card.querySelector('.veh-modelo').value = v.modelo || 'N/A';
        card.querySelector('.veh-anio').value = v.anioFabricacion || 'N/A';
        card.querySelector('.veh-color').value = v.color || 'N/A';

        const badge = card.querySelector('.veh-badge-en-uso');
        badge.style.display = v.enUso ? 'inline-block' : 'none';

        const revBlock = card.querySelector('.veh-revision-block');
        if (v.ultimaRevision) {
            revBlock.style.display = 'block';
            const rev = v.ultimaRevision;
            card.querySelector('.veh-rev-calif').value = rev.calificacion != null ? `${rev.calificacion} / 100` : 'Sin calificación';
            card.querySelector('.veh-rev-fecha').value = rev.fecha ? new Date(rev.fecha).toLocaleDateString() : 'N/A';
            card.querySelector('.veh-rev-obs').value = rev.observacion || 'Sin observaciones adicionales.';
        } else {
            revBlock.style.display = 'none';
        }

        const btnUsar = card.querySelector('.btn-usar-vehiculo');
        if (v.enUso) {
            btnUsar.style.display = 'none';
        } else {
            btnUsar.addEventListener('click', () => activarVehiculo(v.id, btnUsar));
        }

        container.appendChild(fragment);
    });
}

async function activarVehiculo(vehicleId, btnUsar) {
    const originalText = btnUsar.textContent;
    btnUsar.disabled = true;
    btnUsar.textContent = 'Activando...';

    try {
        await fetchAPI(`/vehiculo/${vehicleId}/activar`, { method: 'PUT' });
        await cargarDatosVehiculo();
    } catch (error) {
        console.error('Error al activar el vehículo:', error);
        alert(error.message || 'No se pudo activar este vehículo.');
        btnUsar.disabled = false;
        btnUsar.textContent = originalText;
    }
}

function configurarFormularioVehiculo() {
    const form = document.getElementById('vehiculo-form');
    if (!form) return;

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
            form.reset();
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
