from fastapi import FastAPI
import mysql.connector

app = FastAPI()

# 1. Konfigurasi Koneksi ke Database
def get_db_connection():
    try:
        connection = mysql.connector.connect(
            host="localhost",
            user="root",
            password="",
            database="skill_swap"
        )
        return connection
    except mysql.connector.Error as err:
        print(f"Database Error: {err}")
        return None

# 2. Fungsi untuk Membuat Tabel Otomatis saat Server Menyala
def create_tables():
    db = get_db_connection()
    if not db:
        return
    
    cursor = db.cursor()
    
    # Query SQL untuk membuat tabel users
    cursor.execute("""
    CREATE TABLE IF NOT EXISTS users (
        id INT AUTO_INCREMENT PRIMARY KEY,
        full_name VARCHAR(100) NOT NULL,
        email VARCHAR(100) UNIQUE NOT NULL,
        password_hash VARCHAR(255) NOT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    );
    """)

    # Query SQL untuk membuat tabel user_skills (Barter Can & Want)
    cursor.execute("""
    CREATE TABLE IF NOT EXISTS user_skills (
        id INT AUTO_INCREMENT PRIMARY KEY,
        user_id INT,
        skill_type ENUM('CAN', 'WANT') NOT NULL,
        skill_name VARCHAR(100) NOT NULL,
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
    );
    """)

    # Query SQL untuk membuat tabel swipes (Histori Geser Kanan/Kiri)
    cursor.execute("""
    CREATE TABLE IF NOT EXISTS swipes (
        id INT AUTO_INCREMENT PRIMARY KEY,
        swiper_id INT,
        swiped_id INT,
        is_liked BOOLEAN NOT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (swiper_id) REFERENCES users(id) ON DELETE CASCADE,
        FOREIGN KEY (swiped_id) REFERENCES users(id) ON DELETE CASCADE
    );
    """)

    # Query SQL untuk membuat tabel matches (Hasil Dua Arah + Workflow State)
    cursor.execute("""
    CREATE TABLE IF NOT EXISTS matches (
        id INT AUTO_INCREMENT PRIMARY KEY,
        user1_id INT,
        user2_id INT,
        status ENUM('MATCHED', 'DISCUSSING', 'SWAP_ONGOING', 'COMPLETED') DEFAULT 'MATCHED',
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (user1_id) REFERENCES users(id) ON DELETE CASCADE,
        FOREIGN KEY (user2_id) REFERENCES users(id) ON DELETE CASCADE
    );
    """)

    db.commit()
    cursor.close()
    db.close()
    print("Semua tabel database berhasil diperiksa/dibuat!")

# Jalankan fungsi pembuatan tabel saat script pertama kali dieksekusi
create_tables()


@app.get("/")
def read_root():
    db = get_db_connection()
    if db and db.is_connected():
        db.close()
        db_status = "Connected successfully to MySQL and Tables are Ready!"
    else:
        db_status = "Failed to connect to MySQL."

    return {
        "status": "success",
        "message": "Welcome to Skill Swap Backend API!",
        "database_status": db_status
    }

from pydantic import BaseModel, EmailStr
from passlib.context import CryptContext

# Inisialisasi pengaman password
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

# 3. Model Data Validasi untuk Menerima Input dari Frontend (Flutter)
class RegisterInput(BaseModel):
    full_name: str
    email: EmailStr  # Memastikan format email valid
    password: str

# 4. API Endpoint untuk Registrasi Akun Baru
@app.post("/api/register")
def register_user(data: RegisterInput):
    db = get_db_connection()
    if not db:
        return {"status": "error", "message": "Database connection failed"}
    
    cursor = db.cursor()
    
    try:
        # A. Cek apakah email sudah terdaftar di database
        cursor.execute("SELECT id FROM users WHERE email = %s", (data.email,))
        existing_user = cursor.fetchone()
        
        if existing_user:
            return {"status": "error", "message": "Email sudah digunakan!"}
        
        # B. Enkripsi password asli menjadi kode acak (Hashing)
        hashed_password = pwd_context.hash(data.password)
        
        # C. Masukkan data ke dalam tabel users
        query = "INSERT INTO users (full_name, email, password_hash) VALUES (%s, %s, %s)"
        cursor.execute(query, (data.full_name, data.email, hashed_password))
        db.commit() # Simpan permanen ke MySQL
        
        return {"status": "success", "message": "Akun berhasil didaftarkan!"}
        
    except mysql.connector.Error as err:
        return {"status": "error", "message": f"Terjadi kesalahan: {err}"}
        
    finally:
        cursor.close()
        db.close()

# 5. Model Data Validasi untuk Menerima Input Login dari Frontend
class LoginInput(BaseModel):
    email: EmailStr
    password: str

# 6. API Endpoint untuk Login Pengguna
@app.post("/api/login")
def login_user(data: LoginInput):
    db = get_db_connection()
    if not db:
        return {"status": "error", "message": "Database connection failed"}
    
    cursor = db.cursor(dictionary=True) # Menggunakan dictionary=True agar hasil query berupa Key-Value
    
    try:
        # A. Cari pengguna berdasarkan email
        query = "SELECT id, full_name, password_hash FROM users WHERE email = %s"
        cursor.execute(query, (data.email,))
        user = cursor.fetchone()
        
        # B. Jika email tidak ditemukan
        if not user:
            return {"status": "error", "message": "Email atau password salah!"}
        
        # C. Verifikasi apakah password yang diketik cocok dengan yang di-hash
        is_password_correct = pwd_context.verify(data.password, user['password_hash'])
        
        if not is_password_correct:
            return {"status": "error", "message": "Email atau password salah!"}
        
        # D. Jika sukses, kembalikan data user (bisa dipakai Flutter untuk sesi login)
        return {
            "status": "success",
            "message": f"Selamat datang kembali, {user['full_name']}!",
            "user": {
                "id": user['id'],
                "full_name": user['full_name'],
                "email": data.email
            }
        }
        
    except mysql.connector.Error as err:
        return {"status": "error", "message": f"Terjadi kesalahan: {err}"}
        
    finally:
        cursor.close()
        db.close()

# 7. Model Data Validasi untuk Input Keahlian Tunggal
class SkillItem(BaseModel):
    skill_type: str  # Harus diisi 'CAN' atau 'WANT'
    skill_name: str  # Contoh: 'Flutter', 'UI/UX', dll.

# Model Data Validasi untuk Menerima List Keahlian dari Pengguna
class UserSkillsInput(BaseModel):
    user_id: int
    skills: list[SkillItem]

# 8. API Endpoint untuk Menyimpan/Mengupdate Keahlian Pengguna
@app.post("/api/user-skills")
def save_user_skills(data: UserSkillsInput):
    db = get_db_connection()
    if not db:
        return {"status": "error", "message": "Database connection failed"}
    
    cursor = db.cursor()
    
    try:
        # A. Hapus dulu keahlian lama milik user tersebut agar tidak duplikat saat di-update
        delete_query = "DELETE FROM user_skills WHERE user_id = %s"
        cursor.execute(delete_query, (data.user_id,))
        
        # B. Masukkan daftar keahlian baru satu per satu
        insert_query = """
        INSERT INTO user_skills (user_id, skill_type, skill_name) 
        VALUES (%s, %s, %s)
        """
        
        for item in data.skills:
            # Validasi isi skill_type secara manual demi keamanan database
            if item.skill_type.upper() not in ['CAN', 'WANT']:
                return {"status": "error", "message": "skill_type harus berisi 'CAN' atau 'WANT'!"}
            
            cursor.execute(insert_query, (data.user_id, item.skill_type.upper(), item.skill_name))
        
        db.commit() # Simpan permanen ke MySQL
        return {"status": "success", "message": "Daftar keahlian berhasil diperbarui!"}
        
    except mysql.connector.Error as err:
        return {"status": "error", "message": f"Terjadi kesalahan: {err}"}
        
    finally:
        cursor.close()
        db.close()

# 9. Model Data Validasi untuk Menerima Input Swipe
class SwipeInput(BaseModel):
    swiper_id: int  # Pengguna yang sedang nge-swipe
    swiped_id: int  # Pengguna yang kartunya muncul
    is_liked: bool  # True = Kanan (Suka), False = Kiri (Lewati)

# 10. API Endpoint untuk Menangani Logika Two-Way Matching
@app.post("/api/swipe")
def process_swipe(data: SwipeInput):
    db = get_db_connection()
    if not db:
        return {"status": "error", "message": "Database connection failed"}
    
    cursor = db.cursor(dictionary=True)
    
    try:
        # A. Masukkan data swipe saat ini ke tabel `swipes`
        insert_swipe_query = """
        INSERT INTO swipes (swiper_id, swiped_id, is_liked) 
        VALUES (%s, %s, %s)
        """
        cursor.execute(insert_swipe_query, (data.swiper_id, data.swiped_id, data.is_liked))
        
        # B. Jika swipe kanan (is_liked = True), cek apakah ada potensi MATCHED (Timbal Balik)
        if data.is_liked:
            check_match_query = """
            SELECT id FROM swipes 
            WHERE swiper_id = %s AND swiped_id = %s AND is_liked = TRUE
            """
            # Memeriksa apakah swiped_id (orang di kartu) pernah menyukai swiper_id (kamu)
            cursor.execute(check_match_query, (data.swiped_id, data.swiper_id))
            reverse_swipe = cursor.fetchone()
            
            # Jika ditemukan swipe balik dari target
            if reverse_swipe:
                # Cek dulu apakah data match ini sudah pernah terdaftar agar tidak duplikat
                check_duplicate_match = """
                SELECT id FROM matches 
                WHERE (user1_id = %s AND user2_id = %s) OR (user1_id = %s AND user2_id = %s)
                """
                cursor.execute(check_duplicate_match, (data.swiper_id, data.swiped_id, data.swiped_id, data.swiper_id))
                existing_match = cursor.fetchone()
                
                if not existing_match:
                    # Masukkan data kecocokan ke tabel `matches` dengan status 'MATCHED'
                    insert_match_query = """
                    INSERT INTO matches (user1_id, user2_id, status) 
                    VALUES (%s, %s, 'MATCHED')
                    """
                    cursor.execute(insert_match_query, (data.swiper_id, data.swiped_id))
                    db.commit()
                    
                    return {
                        "status": "match",
                        "message": "IT'S A MATCH! Algoritma Dua Arah Berhasil Mendeteksi Kecocokan.",
                        "matched_with": data.swiped_id
                    }
        
        db.commit()
        return {"status": "success", "message": "Swipe berhasil dicatat."}
        
    except mysql.connector.Error as err:
        return {"status": "error", "message": f"Terjadi kesalahan database: {err}"}
        
    finally:
        cursor.close()
        db.close()