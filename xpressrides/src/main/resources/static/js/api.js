// api.js — Módulo central de comunicación con el backend
// Todas las peticiones al servidor pasan por fetchAPI()

const API_BASE_URL = '/api';

/**
 * Obtiene el usuario autenticado desde localStorage.
 * Retorna null si no existe o si el JSON es inválido.
 */
function getUsuario() {
    try {
        const raw = localStorage.getItem('xpressUsuario');
        if (!raw) return null;
        return JSON.parse(raw);
    } catch (e) {
        // Si el JSON está corrupto, limpiamos y retornamos null
        console.warn('Error parseando xpressUsuario:', e);
        localStorage.removeItem('xpressUsuario');
        return null;
    }
}

/**
 * Realiza peticiones al backend con manejo centralizado de errores.
 * - Antepone API_BASE_URL al endpoint
 * - Fusiona headers correctamente (los del caller NO sobreescriben Content-Type)
 * - Incluye token JWT si el usuario está autenticado
 * - Parsea la respuesta JSON y lanza Error si !result.success
 *
 * @param {string} endpoint - Ruta SIN el prefijo '/api' (ej: '/zonas')
 * @param {object} options  - Opciones adicionales de fetch (method, body, headers, etc.)
 * @returns {Promise<object>} El objeto de respuesta { success, data, message }
 */
async function fetchAPI(endpoint, options = {}) {
    try {
        // Cabeceras por defecto
        const defaultHeaders = {
            'Content-Type': 'application/json'
        };

        // Si hay un usuario con token, agregamos la cabecera de autorización
        const usuario = getUsuario();
        if (usuario && usuario.token) {
            defaultHeaders['Authorization'] = `Bearer ${usuario.token}`;
        }

        // Fusión correcta: las cabeceras del caller se agregan pero NO sobreescriben las por defecto
        const mergedHeaders = {
            ...defaultHeaders,
            ...(options.headers || {})
        };

        // Construimos las opciones finales de fetch
        const fetchOptions = {
            ...options,
            headers: mergedHeaders
        };

        const response = await fetch(`${API_BASE_URL}${endpoint}`, fetchOptions);

        // Si el HTTP status indica error, extraemos el mensaje del body
        if (!response.ok) {
            let errorMsg = `Error HTTP ${response.status}`;
            try {
                const errorBody = await response.json();
                errorMsg = errorBody.message || errorMsg;
            } catch (e) { /* body no era JSON */ }
            throw new Error(errorMsg);
        }

        // Si es 204 No Content, retornamos null
        if (response.status === 204) return null;

        const result = await response.json();

        // Si la respuesta tiene `success` explícito en false, es un error lógico
        if (result.hasOwnProperty('success') && !result.success) {
            throw new Error(result.message || 'Ocurrió un error en la operación.');
        }

        return result;
    } catch (error) {
        console.error('Error en fetchAPI:', error);
        throw error;
    }
}

/**
 * Verifica que el usuario esté autenticado.
 * Si no lo está, redirige al login y retorna false.
 * Usar al inicio de cada página protegida.
 *
 * @returns {boolean} true si hay sesión activa, false si redirigió al login
 */
function requireAuth() {
    const usuario = getUsuario();
    if (!usuario) {
        window.location.href = '../views/login.html';
        return false;
    }
    return true;
}