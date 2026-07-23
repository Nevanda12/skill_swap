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
        is_read BOOLEAN DEFAULT FALSE,
        timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (match_id) REFERENCES matches(id) ON DELETE CASCADE,
        FOREIGN KEY (sender_id) REFERENCES users(id) ON DELETE CASCADE
    );
    """)

    # ==========================================
    # TAMBAHKAN QUERY TABEL REVIEWS DI SINI
    # ==========================================
    cursor.execute("""
    CREATE TABLE IF NOT EXISTS reviews (
        id INT AUTO_INCREMENT PRIMARY KEY,
        match_id INT NOT NULL,
        reviewer_id INT NOT NULL,
        reviewed_user_id INT NOT NULL,
        rating INT NOT NULL CHECK (rating >= 1 AND rating <= 5),
        review_text TEXT,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (match_id) REFERENCES matches(id) ON DELETE CASCADE,
        FOREIGN KEY (reviewer_id) REFERENCES users(id) ON DELETE CASCADE,
        FOREIGN KEY (reviewed_user_id) REFERENCES users(id) ON DELETE CASCADE
    );
    """)

    # Query SQL untuk membuat tabel blocks (Fitur Blokir Pengguna)
    cursor.execute("""
    CREATE TABLE IF NOT EXISTS blocks (
        id INT AUTO_INCREMENT PRIMARY KEY,
        blocker_id INT NOT NULL,
        blocked_id INT NOT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (blocker_id) REFERENCES users(id) ON DELETE CASCADE,
        FOREIGN KEY (blocked_id) REFERENCES users(id) ON DELETE CASCADE,
        UNIQUE KEY unique_block (blocker_id, blocked_id)
    );
    """)

    # (Di dalam fungsi create_tables, sebelum db.commit())
    # Tambahkan kolom foto profil jika belum ada
    try:
        cursor.execute("ALTER TABLE users ADD COLUMN profile_photo LONGTEXT;")
    except mysql.connector.Error as err:
        # Abaikan error jika kolom sudah ada (Error 1060: Duplicate column name)
        pass

    # Tambahkan kolom latar belakang profil jika belum ada
    try:
        cursor.execute("ALTER TABLE users ADD COLUMN background_photo LONGTEXT;")
    except mysql.connector.Error as err:
        # Abaikan error jika kolom sudah ada (Error 1060: Duplicate column name)
        pass

    try:
        cursor.execute("ALTER TABLE chats ADD COLUMN is_read BOOLEAN DEFAULT FALSE;")
    except mysql.connector.Error:
        pass

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
        want_skills_count = sum(1 for item in data.skills if item.skill_type.upper() == 'WANT')
        if want_skills_count > 1:
            return {"status": "error", "message": "Kamu hanya boleh memilih 1 skill yang ingin dipelajari (WANT)!"}

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
        # A. Masukkan data swipe saat ini ke tabel `swipes` dan langsung COMMIT!
        insert_swipe_query = """
        INSERT INTO swipes (swiper_id, swiped_id, is_liked) 
        VALUES (%s, %s, %s)
        """
        cursor.execute(insert_swipe_query, (data.swiper_id, data.swiped_id, data.is_liked))
        db.commit() # Kita commit sekarang agar datanya resmi tertulis di MySQL
        
        # B. Jika swipe kanan (is_liked = True), cek apakah ada potensi MATCHED (Timbal Balik)
        if data.is_liked:
            # Cari apakah ada row di mana: 
            # swiper-nya adalah target (swiped_id) DAN yang di-swipe adalah kita (swiper_id)
            check_match_query = """
            SELECT id FROM swipes 
            WHERE swiper_id = %s AND swiped_id = %s AND is_liked = TRUE
            """
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
                    db.commit() # Commit data match baru

                    # Ambil ID match yang baru saja terbuat
                    new_match_id = cursor.lastrowid
                    
                    return {
                        "status": "match",
                        "message": "IT'S A MATCH! Algoritma Dua Arah Berhasil Mendeteksi Kecocokan.",
                        "matched_with": data.swiped_id,
                        "match_id": new_match_id
                    }
        
        return {"status": "success", "message": "Swipe berhasil dicatat."}
        
    except mysql.connector.Error as err:
        return {"status": "error", "message": f"Terjadi kesalahan database: {err}"}
        
    finally:
        cursor.close()
        db.close()

# =====================================================================
# CHAPTER 2: DISCOVERY ENDPOINT (Rekomendasi User Berdasarkan Skill)
# =====================================================================

# Ubah baris parameternya agar bisa menerima search_name dan filter_skill
@app.get("/api/discover/{user_id}")
def discover_users(user_id: int, search_name: str = None, filter_skill: str = None):
    connection = get_db_connection()
    if not connection:
        raise HTTPException(status_code=500, detail="Database connection failed")
    
    cursor = connection.cursor(dictionary=True)
    try:
        # 1. Tentukan target skill (dari dropdown filter ATAU dari profil WANT)
        target_skills = []
        if filter_skill:
            target_skills = [filter_skill] # Jika user memfilter, gunakan skill dari dropdown
        else:
            # Jika tidak ada filter, gunakan skill WANT bawaan dari profil
            cursor.execute("SELECT skill_name FROM user_skills WHERE user_id = %s AND skill_type = 'WANT'", (user_id,))
            wanted_skills_res = cursor.fetchall()
            target_skills = [row['skill_name'] for row in wanted_skills_res]

        if not target_skills:
            return {"status": "empty", "message": "Tentukan skill yang ingin kamu pelajari di Profil terlebih dahulu!", "data": []}

        # 2. Susun Query Rekomendasi
        placeholders = ','.join(['%s'] * len(target_skills))
        query_discover = f"""
            SELECT DISTINCT u.id, u.full_name, u.email, u.profile_photo 
            FROM users u
            JOIN user_skills us ON u.id = us.user_id
            WHERE us.skill_type = 'CAN' 
            AND us.skill_name IN ({placeholders})
            AND u.id != %s
            AND u.id NOT IN (SELECT COALESCE(swiped_id, 0) FROM swipes WHERE swiper_id = %s)
            AND u.id NOT IN (SELECT blocked_id FROM blocks WHERE blocker_id = %s)
            AND u.id NOT IN (SELECT blocker_id FROM blocks WHERE blocked_id = %s)
        """
        
        # Susun array parameter dasar
        params = target_skills + [user_id, user_id, user_id, user_id]

        # 3. Jika user mengetik nama di kolom pencarian, tambahkan ke SQL
        if search_name:
            query_discover += " AND u.full_name LIKE %s"
            params.append(f"{search_name}%") # Menggunakan % di akhir agar mencari abjad awalan

        cursor.execute(query_discover, params)
        recommended_users = cursor.fetchall()

        # 4. Format hasil akhir (Tetap sama seperti sebelumnya)
        final_data = []
        for r_user in recommended_users:
            cursor.execute("SELECT skill_name, skill_type FROM user_skills WHERE user_id = %s", (r_user['id'],))
            skills = cursor.fetchall()
            
            final_user_node = {
                "id": r_user['id'],
                "name": r_user['full_name'],
                "email": r_user['email'],
                "profile_photo": r_user['profile_photo'],
                "skills": {
                    "can": [s['skill_name'] for s in skills if s['skill_type'] == 'CAN'],
                    "want": [s['skill_name'] for s in skills if s['skill_type'] == 'WANT']
                }
            }
            final_data.append(final_user_node)

        return {"status": "success", "count": len(final_data), "data": final_data}

    except mysql.connector.Error as err:
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

@app.get("/api/matches/active/{user_id}")
def get_active_matches(user_id: int):
    connection = get_db_connection()
    if not connection:
        raise HTTPException(status_code=500, detail="Database connection failed")
    
    cursor = connection.cursor(dictionary=True)
    try:
        # Tambahkan filter WHERE untuk memastikan partner_id tidak ada di tabel blocks (baik memblokir atau diblokir)
        query = """
            SELECT m.id AS match_id, m.status,
                   u.id AS partner_id, u.full_name AS partner_name,
                   u.profile_photo AS partner_photo,
                   (SELECT COUNT(id) FROM chats WHERE match_id = m.id AND sender_id != %s AND is_read = FALSE) AS unread_count,
                   (SELECT COUNT(id) FROM chats WHERE match_id = m.id) AS message_count,
                   (SELECT message FROM chats WHERE match_id = m.id ORDER BY timestamp DESC LIMIT 1) AS last_message,
                   (SELECT timestamp FROM chats WHERE match_id = m.id ORDER BY timestamp DESC LIMIT 1) AS last_message_time
            FROM matches m
            JOIN users u ON (m.user1_id = u.id OR m.user2_id = u.id)
            WHERE (m.user1_id = %s OR m.user2_id = %s) AND u.id != %s
            AND u.id NOT IN (SELECT blocked_id FROM blocks WHERE blocker_id = %s)
            AND u.id NOT IN (SELECT blocker_id FROM blocks WHERE blocked_id = %s)
            ORDER BY (last_message_time IS NULL) ASC, last_message_time DESC
        """
        cursor.execute(query, (user_id, user_id, user_id, user_id, user_id, user_id))
        active_matches = cursor.fetchall()

        # Ubah timestamp jadi string ISO agar bisa di-decode dengan aman di Flutter
        for row in active_matches:
            if row.get('last_message_time'):
                row['last_message_time'] = row['last_message_time'].isoformat()

        return {"status": "success", "data": active_matches}
    except mysql.connector.Error as err:
        raise HTTPException(status_code=500, detail=f"Database error: {err}")
    finally:
        cursor.close()
        connection.close()

# =====================================================================
# CHAPTER 5: REVIEW SYSTEM ENDPOINT (Penilaian Partner Barter)
# =====================================================================

class ReviewInput(BaseModel):
    match_id: int
    reviewer_id: int
    reviewed_user_id: int
    rating: int
    review_text: str

@app.post("/api/review/submit")
def submit_review(data: ReviewInput):
    # Validasi rating
    if data.rating < 1 or data.rating > 5:
        raise HTTPException(status_code=400, detail="Rating harus antara 1 dan 5.")

    connection = get_db_connection()
    if not connection:
        raise HTTPException(status_code=500, detail="Database connection failed")
    
    cursor = connection.cursor(dictionary=True)
    try:
        # Cek apakah user sudah pernah memberi ulasan untuk match ini (mencegah spam/duplikat)
        cursor.execute("""
            SELECT id FROM reviews 
            WHERE match_id = %s AND reviewer_id = %s
        """, (data.match_id, data.reviewer_id))
        existing_review = cursor.fetchone()
        
        if existing_review:
            return {"status": "error", "message": "Kamu sudah memberikan ulasan untuk sesi ini."}

        # Simpan ulasan baru
        query_insert = """
            INSERT INTO reviews (match_id, reviewer_id, reviewed_user_id, rating, review_text)
            VALUES (%s, %s, %s, %s, %s)
        """
        cursor.execute(query_insert, (data.match_id, data.reviewer_id, data.reviewed_user_id, data.rating, data.review_text))
        connection.commit()
        
        return {"status": "success", "message": "Terima kasih atas ulasanmu!"}
        
    except mysql.connector.Error as err:
        raise HTTPException(status_code=500, detail=f"Database error: {err}")
    finally:
        cursor.close()
        connection.close()


@app.get("/api/review/check/{match_id}/{reviewer_id}")
def check_review_status(match_id: int, reviewer_id: int):
    connection = get_db_connection()
    if not connection:
        raise HTTPException(status_code=500, detail="Database connection failed")
    
    cursor = connection.cursor(dictionary=True)
    try:
        cursor.execute("""
            SELECT id FROM reviews 
            WHERE match_id = %s AND reviewer_id = %s
        """, (match_id, reviewer_id))
        existing_review = cursor.fetchone()
        
        return {
            "status": "success",
            "has_reviewed": bool(existing_review) # Mengembalikan True jika ulasan sudah ada
        }
    except mysql.connector.Error as err:
        raise HTTPException(status_code=500, detail=f"Database error: {err}")
    finally:
        cursor.close()
        connection.close()

# =====================================================================
# CHAPTER 6: PROFILE & REVIEWS MANAGEMENT
# =====================================================================

@app.get("/api/profile/{user_id}")
def get_user_profile(user_id: int):
    connection = get_db_connection()
    if not connection:
        raise HTTPException(status_code=500, detail="Database connection failed")
    
    cursor = connection.cursor(dictionary=True)
    try:
        # 1. Ambil data dasar user beserta rata-rata rating
        query_user = """
            SELECT u.id, u.full_name, u.email, u.profile_photo, u.background_photo,
                   COALESCE(AVG(r.rating), 0) as average_rating,
                   COUNT(r.id) as total_reviews,
                   (SELECT COUNT(*) FROM matches WHERE user1_id = u.id OR user2_id = u.id) as total_matches
            FROM users u
            LEFT JOIN reviews r ON u.id = r.reviewed_user_id
            WHERE u.id = %s
            GROUP BY u.id
        """
        cursor.execute(query_user, (user_id,))
        user_data = cursor.fetchone()
        
        if not user_data:
            raise HTTPException(status_code=404, detail="User tidak ditemukan")

        # 2. Ambil daftar keahlian
        cursor.execute("SELECT skill_type, skill_name FROM user_skills WHERE user_id = %s", (user_id,))
        skills = cursor.fetchall()
        
        user_data['skills'] = {
            "can": [s['skill_name'] for s in skills if s['skill_type'] == 'CAN'],
            "want": [s['skill_name'] for s in skills if s['skill_type'] == 'WANT']
        }
        
        # Konversi float desimal rating agar rapi (misal: 4.5)
        user_data['average_rating'] = round(float(user_data['average_rating']), 1)

        return {"status": "success", "data": user_data}
        
    except mysql.connector.Error as err:
        raise HTTPException(status_code=500, detail=f"Database error: {err}")
    finally:
        cursor.close()
        connection.close()
        
@app.get("/api/profile/reviews/{user_id}")
def get_user_reviews_list(user_id: int):
    connection = get_db_connection()
    if not connection:
        raise HTTPException(status_code=500, detail="Database connection failed")
    
    cursor = connection.cursor(dictionary=True)
    try:
        # Ambil semua ulasan untuk user ini beserta nama pengulasnya
        query = """
            SELECT r.rating, r.review_text, r.created_at, u.full_name as reviewer_name 
            FROM reviews r
            JOIN users u ON r.reviewer_id = u.id
            WHERE r.reviewed_user_id = %s
            ORDER BY r.created_at DESC
        """
        cursor.execute(query, (user_id,))
        reviews = cursor.fetchall()
        
        return {"status": "success", "data": reviews}
    except mysql.connector.Error as err:
        raise HTTPException(status_code=500, detail=f"Database error: {err}")
    finally:
        cursor.close()
        connection.close()

class ProfilePhotoInput(BaseModel):
    user_id: int
    photo_base64: str

@app.put("/api/profile/photo")
def update_profile_photo(data: ProfilePhotoInput):
    connection = get_db_connection()
    if not connection:
        raise HTTPException(status_code=500, detail="Database connection failed")
    
    cursor = connection.cursor()
    try:
        cursor.execute("UPDATE users SET profile_photo = %s WHERE id = %s", (data.photo_base64, data.user_id))
        connection.commit()
        return {"status": "success", "message": "Foto profil berhasil diperbarui!"}
    except mysql.connector.Error as err:
        raise HTTPException(status_code=500, detail=f"Database error: {err}")
    finally:
        cursor.close()
        connection.close()

class BackgroundPhotoInput(BaseModel):
    user_id: int
    photo_base64: str

@app.put("/api/profile/background")
def update_background_photo(data: BackgroundPhotoInput):
    connection = get_db_connection()
    if not connection:
        raise HTTPException(status_code=500, detail="Database connection failed")

    cursor = connection.cursor()
    try:
        cursor.execute("UPDATE users SET background_photo = %s WHERE id = %s", (data.photo_base64, data.user_id))
        connection.commit()
        return {"status": "success", "message": "Latar belakang profil berhasil diperbarui!"}
    except mysql.connector.Error as err:
        raise HTTPException(status_code=500, detail=f"Database error: {err}")
    finally:
        cursor.close()
        connection.close()

# =====================================================================
# CHAPTER 7: NOTIFICATION & UNREAD MESSAGES
# =====================================================================

@app.get("/api/chat/unread/{user_id}")
def check_unread_messages(user_id: int):
    connection = get_db_connection()
    if not connection:
        raise HTTPException(status_code=500, detail="Database connection failed")
    
    cursor = connection.cursor(dictionary=True)
    try:
        # Hitung jumlah pesan yang is_read = FALSE dan BUKAN dikirim oleh user yang sedang login
        query = """
            SELECT COUNT(c.id) AS unread_count
            FROM chats c
            JOIN matches m ON c.match_id = m.id
            WHERE (m.user1_id = %s OR m.user2_id = %s) 
            AND c.sender_id != %s 
            AND c.is_read = FALSE
        """
        cursor.execute(query, (user_id, user_id, user_id))
        result = cursor.fetchone()
        
        return {"status": "success", "unread_count": result['unread_count']}
    except mysql.connector.Error as err:
        raise HTTPException(status_code=500, detail=f"Database error: {err}")
    finally:
        cursor.close()
        connection.close()


@app.put("/api/chat/read/{match_id}/{user_id}")
def mark_messages_as_read(match_id: int, user_id: int):
    connection = get_db_connection()
    if not connection:
        raise HTTPException(status_code=500, detail="Database connection failed")
    
    cursor = connection.cursor()
    try:
        # Ubah status is_read menjadi TRUE saat user membuka ruang obrolan
        query = "UPDATE chats SET is_read = TRUE WHERE match_id = %s AND sender_id != %s"
        cursor.execute(query, (match_id, user_id))
        connection.commit()
        
        return {"status": "success", "message": "Pesan telah dibaca."}
    except mysql.connector.Error as err:
        raise HTTPException(status_code=500, detail=f"Database error: {err}")
    finally:
        cursor.close()
        connection.close()

# =====================================================================
# CHAPTER 8: HAPUS CHAT & BLOKIR ACTION
# =====================================================================

@app.delete("/api/match/delete/{match_id}")
def delete_match_session(match_id: int):
    connection = get_db_connection()
    if not connection:
        raise HTTPException(status_code=500, detail="Database connection failed")
    cursor = connection.cursor()
    try:
        # Menghapus data dari tabel matches otomatis menghapus chats karena ON DELETE CASCADE
        query = "DELETE FROM matches WHERE id = %s"
        cursor.execute(query, (match_id,))
        connection.commit()
        return {"status": "success", "message": "Obrolan berhasil dihapus permanent."}
    except mysql.connector.Error as err:
        raise HTTPException(status_code=500, detail=f"Database error: {err}")
    finally:
        cursor.close()
        connection.close()

class BlockInput(BaseModel):
    blocker_id: int
    blocked_id: int

@app.post("/api/user/block")
def block_user(data: BlockInput):
    connection = get_db_connection()
    if not connection:
        raise HTTPException(status_code=500, detail="Database connection failed")
    cursor = connection.cursor()
    try:
        # 1. Catat ke tabel blocks
        query_block = "INSERT IGNORE INTO blocks (blocker_id, blocked_id) VALUES (%s, %s)"
        cursor.execute(query_block, (data.blocker_id, data.blocked_id))
        
        # 2. Putus juga hubungan match mereka agar otomatis hilang dari chat list
        query_delete_match = """
            DELETE FROM matches 
            WHERE (user1_id = %s AND user2_id = %s) OR (user2_id = %s AND user1_id = %s)
        """
        cursor.execute(query_delete_match, (data.blocker_id, data.blocked_id, data.blocker_id, data.blocked_id))
        
        connection.commit()
        return {"status": "success", "message": "Pengguna berhasil diblokir."}
    except mysql.connector.Error as err:
        raise HTTPException(status_code=500, detail=f"Database error: {err}")
    finally:
        cursor.close()
        connection.close()

# =====================================================================
# CHAPTER 9: SUMMARY EXPLORE SKILLS
# =====================================================================

@app.get("/api/skills/summary")
def get_skills_summary():
    connection = get_db_connection()
    if not connection:
        raise HTTPException(status_code=500, detail="Database connection failed")
    
    cursor = connection.cursor(dictionary=True)
    try:
        # Hitung jumlah user unik (CAN) per kategori skill
        query = """
            SELECT skill_name, COUNT(DISTINCT user_id) as total_users 
            FROM user_skills 
            WHERE skill_type = 'CAN' 
            GROUP BY skill_name
            ORDER BY total_users DESC
        """
        cursor.execute(query)
        skills_data = cursor.fetchall()
        return {"status": "success", "data": skills_data}
    except mysql.connector.Error as err:
        raise HTTPException(status_code=500, detail=f"Database error: {err}")
    finally:
        cursor.close()
        connection.close()