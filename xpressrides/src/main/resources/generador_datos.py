import os
import random
from datetime import datetime, timedelta

# =========================================================================
# CONFIGURATION
# =========================================================================
NUM_CLIENTS = 60
NUM_DRIVERS = 25
NUM_TRIPS = 300

OUTPUT_FILE = "02_datos_prueba.sql"
HASH_PASSWORD = "$2a$10$SeAgMoDqTfHmtpDSpSmkteZTMNqT/LSyOOc7tzVkr1Mhhqge3aq5i" # for "password"

# =========================================================================
# DATA SOURCE
# =========================================================================
NAMES = ["Carlos", "Laura", "Pedro", "Ana", "Luis", "Maria", "Jose", "Elena", "Miguel", "Carmen", "Jesus", "Isabel", "Antonio", "Rosa", "David", "Diana", "Juan", "Sofia", "Diego", "Lucia", "Andres", "Camila", "Javier", "Valentina", "Gabriel", "Valeria", "Alejandro", "Daniela", "Fernando", "Mariana", "Ricardo", "Victoria", "Jorge", "Paola", "Eduardo", "Andrea", "Victor", "Natalia", "Hector", "Gabriela", "Oscar", "Alejandra", "Rafael", "Adriana", "Roberto", "Monica", "Emilio", "Patricia"]
LAST_NAMES = ["Rodriguez", "Perez", "Gonzalez", "Gomez", "Fernandez", "Lopez", "Martinez", "Sanchez", "Diaz", "Torres", "Ramirez", "Ruiz", "Flores", "Benitez", "Acosta", "Mendoza", "Medina", "Castillo", "Rojas", "Cruz", "Morales", "Ortiz", "Gutierrez", "Chavez", "Ramos", "Herrera", "Vargas", "Castro", "Mendez", "Guzman", "Muñoz", "Rios", "Delgado", "Navarro", "Salazar", "Reyes", "Aguilar", "Suarez", "Cabrera", "Molina", "Campos", "Vega", "Fuentes", "Carrillo", "Pinto", "Soto", "Cortez", "Navarrete"]

CAR_BRANDS = ["Toyota", "Chevrolet", "Ford", "Hyundai", "Honda", "Nissan", "Kia", "Mazda"]
CAR_MODELS = {
    "Toyota": ["Corolla", "Yaris", "Camry", "Hilux"],
    "Chevrolet": ["Aveo", "Cruze", "Optra", "Spark"],
    "Ford": ["Fiesta", "Focus", "Explorer", "Escape"],
    "Hyundai": ["Elantra", "Tucson", "Accent", "Sonata"],
    "Honda": ["Civic", "Accord", "CR-V", "Fit"],
    "Nissan": ["Sentra", "Versa", "Altima", "Kicks"],
    "Kia": ["Rio", "Forte", "Sportage", "Cerato"],
    "Mazda": ["Mazda3", "Mazda6", "CX-5"]
}
COLORS = ["Blanco", "Negro", "Plata", "Gris", "Azul", "Rojo"]

ADMINS = [
    ('V-31783162', 'Ángel', 'Martínez', 'angelm'),
    ('V-32015232', 'Freddy', 'Salazar', 'freddys'),
    ('V-32417248', 'Eliuber', 'González', 'eliuberg'),
    ('V-31757491', 'Manuel', 'Jaimes', 'manuelj'),
    ('V-14089807', 'Johanna', 'Guédez', 'johannag')
]

# =========================================================================
# GENERATORS
# =========================================================================

def get_random_date(start_days_ago=90):
    start = datetime.now() - timedelta(days=start_days_ago)
    random_days = random.randint(0, start_days_ago - 1)
    random_hours = random.randint(0, 23)
    random_minutes = random.randint(0, 59)
    random_seconds = random.randint(0, 59)
    return start + timedelta(days=random_days, hours=random_hours, minutes=random_minutes, seconds=random_seconds)

def generate_cedula():
    return f"V-{random.randint(10000000, 35000000)}"

def generate_phone():
    prefix = random.choice(["0414", "0424", "0412", "0416", "0426"])
    number = random.randint(1000000, 9999999)
    return f"{prefix}-{number}"

def generate_plate():
    letters = "".join(random.choices("ABCDEFGHIJKLMNOPQRSTUVWXYZ", k=3))
    nums = "".join(random.choices("0123456789", k=3))
    return f"{letters}{nums}"

# =========================================================================
# SCRIPT BUILDER
# =========================================================================

def build_sql():
    sql = []
    
    # Read Bloque 0
    bloque0_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "bloque0.sql")
    if os.path.exists(bloque0_path):
        with open(bloque0_path, "r", encoding="utf-8-sig", errors="replace") as f:
            sql.append(f.read())
    else:
        sql.append("-- ================================================================")
        sql.append("-- DATOS DE PRUEBA GENERADOS AUTOMATICAMENTE")
        sql.append("-- ================================================================")
        sql.append("USE decarrerita;\n")
        sql.append("SET SQL_SAFE_UPDATES = 0;\n")

    # Bloque 0 is not fully needed if we already consolidated migrations.
    # We will just TRUNCATE all transactional tables to have a clean slate.
    sql.append("-- ================================================================")
    sql.append("-- LIMPIEZA TOTAL")
    sql.append("-- ================================================================")
    sql.append("SET FOREIGN_KEY_CHECKS = 0;")
    tables = [
        "notificacion", "factura", "pago_chofer", "recarga_saldo", 
        "contacto_emergencia", "evaluacion_psicologica", "revision_vehiculo",
        "vehiculo", "incidente", "traslado", "cupon_cliente", "cupon", 
        "token_revocado", "cliente", "chofer", "personal_admin", "usuario"
    ]
    for table in tables:
        sql.append(f"TRUNCATE TABLE {table};")
    sql.append("SET FOREIGN_KEY_CHECKS = 1;\n")

    # Generate Users
    users_insert = []
    
    # 1. ADMINS (IDs 1 to 5)
    for adm in ADMINS:
        users_insert.append(f"('{adm[0]}', '{adm[1]}', '{adm[2]}', '{adm[3]}', '{HASH_PASSWORD}', '{adm[3]}@admin.com', '{generate_phone()}', 'personal_admin')")

    # 2. CLIENTS (IDs 6 to 5+NUM_CLIENTS)
    clients_data = []
    for i in range(NUM_CLIENTS):
        name = random.choice(NAMES)
        lastname = random.choice(LAST_NAMES)
        username = f"{name.lower()[0]}{lastname.lower()}{i}"
        cedula = generate_cedula()
        email = f"{username}@test.ve"
        users_insert.append(f"('{cedula}', '{name}', '{lastname}', '{username}', '{HASH_PASSWORD}', '{email}', '{generate_phone()}', 'cliente')")
        saldo = round(random.uniform(5.0, 100.0), 2)
        clients_data.append(saldo)

    # 3. DRIVERS (IDs 5+NUM_CLIENTS+1 to end)
    drivers_data = []
    for i in range(NUM_DRIVERS):
        name = random.choice(NAMES)
        lastname = random.choice(LAST_NAMES)
        username = f"{name.lower()[0]}{lastname.lower()}ch{i}"
        cedula = generate_cedula()
        email = f"{username}@test.ve"
        users_insert.append(f"('{cedula}', '{name}', '{lastname}', '{username}', '{HASH_PASSWORD}', '{email}', '{generate_phone()}', 'chofer')")
        drivers_data.append(username)

    sql.append("INSERT INTO usuario (cedula, nombre, apellido, username, password_hash, email, telefono, rol) VALUES")
    sql.append(",\n".join(users_insert) + ";\n")

    # Insert Personal Admin records
    sql.append("INSERT INTO personal_admin (id_usuario, super_admin, nivel_acceso) VALUES")
    admin_inserts = []
    for i in range(1, 6):
        admin_inserts.append(f"({i}, 1, 'TOTAL')")
    sql.append(",\n".join(admin_inserts) + ";\n")

    # Insert Clients
    sql.append("INSERT INTO cliente (id_usuario, saldo_usd, verificado) VALUES")
    client_inserts = []
    for i, saldo in enumerate(clients_data):
        client_inserts.append(f"({i + 6}, {saldo}, 1)")
    sql.append(",\n".join(client_inserts) + ";\n")

    # Insert Drivers
    sql.append("INSERT INTO chofer (id_usuario, id_banco, id_zona_actual, numero_cuenta, saldo_acumulado_usd, habilitado, disponible) VALUES")
    driver_inserts = []
    for i in range(NUM_DRIVERS):
        driver_idx = i + 6 + NUM_CLIENTS
        banco = random.randint(1, 5) # Assuming banks 1 to 5 exist
        zona = random.randint(1, 6) # Assuming zones 1 to 6 exist
        cuenta = f"0134000000{random.randint(1000000000, 9999999999)}"
        saldo_acum = round(random.uniform(10.0, 150.0), 2)
        driver_inserts.append(f"({driver_idx}, {banco}, {zona}, '{cuenta}', {saldo_acum}, 1, 1)")
    sql.append(",\n".join(driver_inserts) + ";\n")

    # Driver related data (Evaluations, Vehicles, Reviews)
    eval_inserts = []
    vehic_inserts = []
    rev_inserts = []
    emerg_inserts = []

    for i in range(NUM_DRIVERS):
        chofer_id = i + 1
        
        # Evaluations
        date_eval = get_random_date(180).strftime("%Y-%m-%d %H:%M:%S")
        eval_inserts.append(f"({chofer_id}, 'Test MMPI', '{date_eval}', 'aprobado', 'Sin observaciones', {random.randint(1,5)})")
        
        # Vehicles
        brand = random.choice(CAR_BRANDS)
        model = random.choice(CAR_MODELS[brand])
        plate = generate_plate()
        year = random.randint(2008, 2024)
        color = random.choice(COLORS)
        vehic_inserts.append(f"({chofer_id}, '{plate}', '{brand}', '{model}', {year}, '{color}', 4, 1)")
        
        # Revisions
        date_rev = get_random_date(180).strftime("%Y-%m-%d")
        rev_inserts.append(f"({i+1}, '{date_rev}', 'aprobado', 'Buenas condiciones', {random.randint(1,5)})")
        
        # Emergency Contacts
        emerg_inserts.append(f"({chofer_id}, 'Maria {LAST_NAMES[i]}', 'Madre', '{generate_phone()}')")
        emerg_inserts.append(f"({chofer_id}, 'Jose {LAST_NAMES[i]}', 'Padre', '{generate_phone()}')")

    sql.append("INSERT INTO evaluacion_psicologica (id_chofer, tipo_test, fecha_evaluacion, estado, observaciones, evaluador_id) VALUES")
    sql.append(",\n".join(eval_inserts) + ";\n")

    sql.append("INSERT INTO vehiculo (id_chofer, placa, marca, modelo, anio, color, capacidad_pasajeros, activo) VALUES")
    sql.append(",\n".join(vehic_inserts) + ";\n")

    sql.append("INSERT INTO revision_vehiculo (id_vehiculo, fecha_revision, estado, observaciones, revisor_id) VALUES")
    sql.append(",\n".join(rev_inserts) + ";\n")
    
    sql.append("INSERT INTO contacto_emergencia (id_chofer, nombre, parentesco, telefono) VALUES")
    sql.append(",\n".join(emerg_inserts) + ";\n")

    # 4. TRIPS (Traslados)
    trip_inserts = []
    estados = ['completado', 'completado', 'completado', 'completado', 'cancelado', 'en_progreso']
    
    for i in range(NUM_TRIPS):
        id_cliente = random.randint(1, NUM_CLIENTS)
        id_chofer = random.randint(1, NUM_DRIVERS)
        
        estado = random.choice(estados)
        if estado == 'cancelado':
            id_chofer = 'NULL' if random.random() > 0.5 else id_chofer
        
        tarifa = round(random.uniform(2.5, 15.0), 2)
        costo_cliente = tarifa
        monto_chofer = round(tarifa * 0.75, 2)
        
        date_sol = get_random_date(60)
        date_ini = date_sol + timedelta(minutes=random.randint(5, 15))
        date_fin = date_ini + timedelta(minutes=random.randint(10, 45))
        
        ds_str = date_sol.strftime("%Y-%m-%d %H:%M:%S")
        di_str = f"'{date_ini.strftime('%Y-%m-%d %H:%M:%S')}'" if estado == 'completado' else 'NULL'
        df_str = f"'{date_fin.strftime('%Y-%m-%d %H:%M:%S')}'" if estado == 'completado' else 'NULL'
        
        calif = random.randint(3, 5) if estado == 'completado' else 'NULL'
        
        # Dummy coordinates
        lat_o = round(random.uniform(8.2, 8.4), 6)
        lng_o = round(random.uniform(-62.7, -62.5), 6)
        lat_d = round(random.uniform(8.2, 8.4), 6)
        lng_d = round(random.uniform(-62.7, -62.5), 6)

        trip_inserts.append(f"({id_cliente}, {id_chofer}, NULL, NULL, 'Direccion Origen {i}', {lat_o}, {lng_o}, 'Direccion Destino {i}', {lat_d}, {lng_d}, '{estado}', 1, '{ds_str}', {di_str}, {df_str}, {tarifa}, {costo_cliente}, {monto_chofer}, {calif}, NULL)")

    sql.append("INSERT INTO traslado (id_cliente, id_chofer, id_zona_origen, id_zona_destino, origen_direccion, origen_lat, origen_lng, destino_direccion, destino_lat, destino_lng, estado, nro_pasajeros, fecha_solicitud, fecha_inicio, fecha_fin, tarifa_base_usd, costo_cliente_usd, monto_chofer_usd, calificacion_al_chofer, calificacion_al_cliente) VALUES")
    sql.append(",\n".join(trip_inserts) + ";\n")

    return "\n".join(sql)

if __name__ == "__main__":
    script_dir = os.path.dirname(os.path.abspath(__file__))
    output_path = os.path.join(script_dir, OUTPUT_FILE)
    
    with open(output_path, "w", encoding="utf-8") as f:
        f.write(build_sql())
    
    print(f"Generated {NUM_CLIENTS} clients, {NUM_DRIVERS} drivers, and {NUM_TRIPS} trips.")
    print(f"File saved to {output_path}")

