import bcrypt

hash_val = b'$2a$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcfl7p92ldGxad68LJZdL17lHuu'
print("password: ", bcrypt.checkpw(b'password', hash_val))
print("contrasena: ", bcrypt.checkpw(b'contrase\xc3\xb1a', hash_val))
