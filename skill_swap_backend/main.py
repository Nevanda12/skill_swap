from fastapi import FastAPI, HTTPException
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

    # ==========================================
    # TAMBAHKAN QUERY TABEL CHATS DI SINI kawan!
    # ==========================================
    cursor.execute("""
    CREATE TABLE IF NOT EXISTS chats (
        id INT AUTO_INCREMENT PRIMARY KEY,
        match_id INT NOT NULL,
        sender_id INT NOT NULL,
        message TEXT NOT NULL,
        timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (match_id) REFERENCES matches(id) ON DELETE CASCADE,
        FOREIGN KEY (sender_id) REFERENCES users(id) ON DELETE CASCADE
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

# =====================================================================
# CHAPTER 2: DISCOVERY ENDPOINT (Rekomendasi User Berdasarkan Skill)
# =====================================================================

@app.get("/api/discover/{user_id}")
def discover_users(user_id: int):
    connection = get_db_connection()
    if not connection:
        raise HTTPException(status_code=500, detail="Database connection failed")
    
    cursor = connection.cursor(dictionary=True)
    try:
        # 1. Ambil daftar skill yang diinginkan (WANT) oleh user ini
        query_wanted_skills = """
            SELECT skill_name FROM user_skills 
            WHERE user_id = %s AND skill_type = 'WANT'
        """
        cursor.execute(query_wanted_skills, (user_id,))
        wanted_skills_res = cursor.fetchall()
        
        if not wanted_skills_res:
            return {"status": "empty", "message": "Tentukan skill yang ingin kamu pelajari terlebih dahulu!", "data": []}
            
        wanted_skills = [row['skill_name'] for row in wanted_skills_res]

        # 2. Query Utama Rekomendasi yang lebih aman dari eror SQL
        placeholders = ','.join(['%s'] * len(wanted_skills))
        query_discover = f"""
            SELECT DISTINCT u.id, u.full_name, u.email 
            FROM users u
            JOIN user_skills us ON u.id = us.user_id
            WHERE us.skill_type = 'CAN' 
            AND us.skill_name IN ({placeholders})
            AND u.id != %s
            AND u.id NOT IN (
                SELECT COALESCE(swiped_id, 0) FROM swipes WHERE swiper_id = %s
            )
        """
        
        # Gabungkan parameter
        params = wanted_skills + [user_id, user_id]
        
        cursor.execute(query_discover, params)
        recommended_users = cursor.fetchall()

        # 3. Format hasil akhir agar sesuai dengan struktur UI Flutter kamu
        final_data = []
        for r_user in recommended_users:
            cursor.execute(
                "SELECT skill_name, skill_type FROM user_skills WHERE user_id = %s", 
                (r_user['id'],)
            )
            skills = cursor.fetchall()
            
            # Buat mapping nama field 'name' agar serasi dengan kode UI Flutter
            final_user_node = {
                "id": r_user['id'],
                "name": r_user['full_name'],
                "email": r_user['email'],
                "skills": {
                    "can": [s['skill_name'] for s in skills if s['skill_type'] == 'CAN'],
                    "want": [s['skill_name'] for s in skills if s['skill_type'] == 'WANT']
                }
            }
            final_data.append(final_user_node)

        return {
            "status": "success",
            "count": len(final_data),
            "data": final_data
        }

    except mysql.connector.Error as err:
        # Menampilkan pesan error spesifik di terminal backend untuk mempermudah debugging
        print(f"❌ SQL ERROR: {err}")
        raise HTTPException(status_code=500, detail=f"Database error: {err}")
    finally:
        cursor.close()
        connection.close()

# =====================================================================
# CHAPTER 3: CHAT SYSTEM ENDPOINTS (Manajemen Obrolan Setelah Match)
# =====================================================================
from pydantic import BaseModel

class ChatMessageInput(BaseModel):
    match_id: int
    sender_id: int
    message: str

@app.post("/api/chat/send")
def send_message(chat_input: ChatMessageInput):
    connection = get_db_connection()
    if not connection:
        raise HTTPException(status_code=500, detail="Database connection failed")
    
    cursor = connection.cursor(dictionary=True)
    try:
        cursor.execute("SELECT id FROM matches WHERE id = %s", (chat_input.match_id,))
        match_exists = cursor.fetchone()
        if not match_exists:
            raise HTTPException(status_code=404, detail="Match session not found")

        query_insert_chat = """
            INSERT INTO chats (match_id, sender_id, message)
            VALUES (%s, %s, %s)
        """
        cursor.execute(query_insert_chat, (chat_input.match_id, chat_input.sender_id, chat_input.message))
        connection.commit()
        
        return {
            "status": "success",
            "message": "Message sent successfully!",
            "chat_id": cursor.lastrowid
        }
    except mysql.connector.Error as err:
        raise HTTPException(status_code=500, detail=f"Database error: {err}")
    finally:
        cursor.close()
        connection.close()

@app.get("/api/chat/history/{match_id}")
def get_chat_history(match_id: int):
    connection = get_db_connection()
    if not connection:
        raise HTTPException(status_code=500, detail="Database connection failed")
    
    cursor = connection.cursor(dictionary=True)
    try:
        # Menggunakan full_name agar sesuai dengan skema tabel users kamu
        query_history = """
            SELECT c.id, c.sender_id, u.full_name AS sender_name, c.message, c.timestamp 
            FROM chats c
            JOIN users u ON c.sender_id = u.id
            WHERE c.match_id = %s
            ORDER BY c.timestamp ASC
        """
        cursor.execute(query_history, (match_id,))
        history = cursor.fetchall()
        
        for row in history:
            if row['timestamp']:
                row['timestamp'] = row['timestamp'].isoformat()

        return {
            "status": "success",
            "count": len(history),
            "data": history
        }
    except mysql.connector.Error as err:
        raise HTTPException(status_code=500, detail=f"Database error: {err}")
    finally:
        cursor.close()
        connection.close()

# =====================================================================
# CHAPTER 4: WORKFLOW STATE ENDPOINT (Manajemen Status Barter Skripsi)
# =====================================================================

class UpdateMatchStatusInput(BaseModel):
    match_id: int
    current_user_id: int  # Opsional: Untuk validasi apakah user ini berhak mengubah status
    new_status: str       # Harus salah satu dari: MATCHED, DISCUSSING, SWAP_ONGOING, COMPLETED

@app.put("/api/match/status")
def update_match_status(status_input: UpdateMatchStatusInput):
    # Validasi input ENUM agar sesuai dengan skema database kamu
    allowed_statuses = ['MATCHED', 'DISCUSSING', 'SWAP_ONGOING', 'COMPLETED']
    if status_input.new_status not in allowed_statuses:
        raise HTTPException(status_code=400, detail=f"Status harus salah satu dari: {allowed_statuses}")
        
    connection = get_db_connection()
    if not connection:
        raise HTTPException(status_code=500, detail="Database connection failed")
    
    cursor = connection.cursor(dictionary=True)
    try:
        # 1. Pastikan match tersebut ada dan user terlibat di dalamnya
        query_check = "SELECT id, user1_id, user2_id FROM matches WHERE id = %s"
        cursor.execute(query_check, (status_input.match_id,))
        match = cursor.fetchone()
        
        if not match:
            raise HTTPException(status_code=404, detail="Sesi match tidak ditemukan.")
            
        if status_input.current_user_id not in [match['user1_id'], match['user2_id']]:
            raise HTTPException(status_code=403, detail="Kamu tidak terdaftar dalam sesi barter ini.")

        # 2. Lakukan update status workflow
        query_update = "UPDATE matches SET status = %s WHERE id = %s"
        cursor.execute(query_update, (status_input.new_status, status_input.match_id))
        connection.commit()
        
        return {
            "status": "success",
            "message": f"Status alur barter berhasil diperbarui menjadi {status_input.new_status}!"
        }
        
    except mysql.connector.Error as err:
        raise HTTPException(status_code=500, detail=f"Database error: {err}")
    finally:
        cursor.close()
        connection.close()