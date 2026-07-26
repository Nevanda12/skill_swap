from fastapi import FastAPI, HTTPException
import mysql.connector
import random
import string
import os
from dotenv import load_dotenv
import smtplib
from email.mime.text import MIMEText
from datetime import datetime, timedelta
from google.oauth2 import id_token as google_id_token
from google.auth.transport import requests as google_requests

# Membaca isi file .env dan menjadikannya environment variable
# HARUS dipanggil SEBELUM os.environ.get() di bawah
load_dotenv()

app = FastAPI()

# =====================================================================
# KONFIGURASI EMAIL (untuk kirim OTP) & GOOGLE LOGIN
# Ambil dari Environment Variable, JANGAN taruh password langsung di kode!
# Cara set env variable ada di penjelasan chat.
# =====================================================================
SMTP_EMAIL = os.environ.get("SMTP_EMAIL")          # contoh: skillswapapp@gmail.com
SMTP_APP_PASSWORD = os.environ.get("SMTP_APP_PASSWORD")  # App Password 16 digit dari Google
GOOGLE_CLIENT_ID = os.environ.get("GOOGLE_CLIENT_ID")    # Client ID dari Google Cloud Console

OTP_EXPIRE_MINUTES = 10


def generate_otp_code() -> str:
    """Membuat 6 digit kode OTP acak, contoh: '482913'"""
    return "".join(random.choices(string.digits, k=6))


def send_otp_email(to_email: str, full_name: str, otp_code: str):
    """Mengirim kode OTP ke email asli pengguna lewat Gmail SMTP."""
    if not SMTP_EMAIL or not SMTP_APP_PASSWORD:
        # Kalau env variable belum di-set, OTP tidak terkirim tapi server tidak crash.
        print(f"[WARNING] SMTP belum dikonfigurasi. OTP untuk {to_email} adalah: {otp_code}")
        return

    subject = "Kode Verifikasi Skill Swap Kamu"
    body = f"""Halo {full_name},

Kode OTP kamu adalah: {otp_code}

Kode ini berlaku selama {OTP_EXPIRE_MINUTES} menit. Jangan berikan kode ini ke siapa pun.

Salam,
Tim Skill Swap
"""
    message = MIMEText(body)
    message["Subject"] = subject
    message["From"] = SMTP_EMAIL
    message["To"] = to_email

    try:
        with smtplib.SMTP_SSL("smtp.gmail.com", 465) as server:
            server.login(SMTP_EMAIL, SMTP_APP_PASSWORD)
            server.sendmail(SMTP_EMAIL, to_email, message.as_string())
    except Exception as e:
        print(f"[ERROR] Gagal mengirim email OTP ke {to_email}: {e}")

# 1. Konfigurasi Koneksi ke Database
def get_db_connection():
    try:
        connection = mysql.connector.connect(
            host=os.environ.get("DB_HOST", "localhost"),
            user=os.environ.get("DB_USER", "root"),
            password=os.environ.get("DB_PASSWORD", ""),
            database=os.environ.get("DB_NAME", "skill_swap"),
            port=int(os.environ.get("DB_PORT", "3306")),
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
        is_verified BOOLEAN DEFAULT FALSE,
        otp_code VARCHAR(10),
        otp_expires_at DATETIME,
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

    # Query SQL untuk membuat tabel follows (Fitur Follow/Followers)
    cursor.execute("""
    CREATE TABLE IF NOT EXISTS follows (
        id INT AUTO_INCREMENT PRIMARY KEY,
        follower_id INT NOT NULL,
        following_id INT NOT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (follower_id) REFERENCES users(id) ON DELETE CASCADE,
        FOREIGN KEY (following_id) REFERENCES users(id) ON DELETE CASCADE,
        UNIQUE KEY unique_follow (follower_id, following_id)
    );
    """)

    # Query SQL untuk membuat tabel profile_gallery (Foto Sertifikat/Profesional di Profil)
    cursor.execute("""
    CREATE TABLE IF NOT EXISTS profile_gallery (
        id INT AUTO_INCREMENT PRIMARY KEY,
        user_id INT NOT NULL,
        photo_base64 LONGTEXT NOT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
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

    # ==========================================
    # KOLOM BARU UNTUK OTP EMAIL + GOOGLE LOGIN
    # ==========================================
    try:
        cursor.execute("ALTER TABLE users ADD COLUMN is_verified BOOLEAN DEFAULT FALSE;")
    except mysql.connector.Error:
        pass

    try:
        cursor.execute("ALTER TABLE users ADD COLUMN otp_code VARCHAR(6) NULL;")
    except mysql.connector.Error:
        pass

    try:
        cursor.execute("ALTER TABLE users ADD COLUMN otp_expires_at DATETIME NULL;")
    except mysql.connector.Error:
        pass

    try:
        cursor.execute("ALTER TABLE users ADD COLUMN google_id VARCHAR(255) NULL;")
    except mysql.connector.Error:
        pass

    # Password harus boleh kosong untuk akun yang daftar lewat Google
    try:
        cursor.execute("ALTER TABLE users MODIFY password_hash VARCHAR(255) NULL;")
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

        # C. Buat kode OTP dan waktu kadaluarsanya
        otp_code = generate_otp_code()
        otp_expires_at = datetime.now() + timedelta(minutes=OTP_EXPIRE_MINUTES)

        # D. Masukkan data ke dalam tabel users (is_verified masih FALSE)
        query = """
            INSERT INTO users (full_name, email, password_hash, is_verified, otp_code, otp_expires_at) 
            VALUES (%s, %s, %s, FALSE, %s, %s)
        """
        cursor.execute(query, (data.full_name, data.email, hashed_password, otp_code, otp_expires_at))
        db.commit() # Simpan permanen ke MySQL

        # E. Kirim email berisi kode OTP
        send_otp_email(data.email, data.full_name, otp_code)

        return {
            "status": "success",
            "message": "Akun berhasil didaftarkan! Silakan cek email untuk kode OTP.",
            "email": data.email
        }
        
    except mysql.connector.Error as err:
        return {"status": "error", "message": f"Terjadi kesalahan: {err}"}
        
    finally:
        cursor.close()
        db.close()

# 4b. Model & Endpoint untuk Verifikasi Kode OTP
class VerifyOtpInput(BaseModel):
    email: EmailStr
    otp_code: str

@app.post("/api/verify-otp")
def verify_otp(data: VerifyOtpInput):
    db = get_db_connection()
    if not db:
        return {"status": "error", "message": "Database connection failed"}

    cursor = db.cursor(dictionary=True)
    try:
        cursor.execute(
            "SELECT id, full_name, otp_code, otp_expires_at, is_verified FROM users WHERE email = %s",
            (data.email,)
        )
        user = cursor.fetchone()

        if not user:
            return {"status": "error", "message": "Akun tidak ditemukan."}

        if user["is_verified"]:
            return {"status": "error", "message": "Akun sudah terverifikasi sebelumnya."}

        if not user["otp_code"] or user["otp_code"] != data.otp_code:
            return {"status": "error", "message": "Kode OTP salah!"}

        if user["otp_expires_at"] and datetime.now() > user["otp_expires_at"]:
            return {"status": "error", "message": "Kode OTP sudah kadaluarsa, silakan kirim ulang."}

        # OTP cocok -> aktifkan akun & hapus kode OTP
        cursor.execute(
            "UPDATE users SET is_verified = TRUE, otp_code = NULL, otp_expires_at = NULL WHERE id = %s",
            (user["id"],)
        )
        db.commit()

        return {
            "status": "success",
            "message": "Verifikasi berhasil! Akun kamu sudah aktif.",
            "user": {"id": user["id"], "full_name": user["full_name"], "email": data.email}
        }
    except mysql.connector.Error as err:
        return {"status": "error", "message": f"Terjadi kesalahan: {err}"}
    finally:
        cursor.close()
        db.close()


# 4c. Model & Endpoint untuk Kirim Ulang OTP
class ResendOtpInput(BaseModel):
    email: EmailStr

@app.post("/api/resend-otp")
def resend_otp(data: ResendOtpInput):
    db = get_db_connection()
    if not db:
        return {"status": "error", "message": "Database connection failed"}

    cursor = db.cursor(dictionary=True)
    try:
        cursor.execute("SELECT id, full_name, is_verified FROM users WHERE email = %s", (data.email,))
        user = cursor.fetchone()

        if not user:
            return {"status": "error", "message": "Akun tidak ditemukan."}

        if user["is_verified"]:
            return {"status": "error", "message": "Akun sudah terverifikasi."}

        otp_code = generate_otp_code()
        otp_expires_at = datetime.now() + timedelta(minutes=OTP_EXPIRE_MINUTES)

        cursor.execute(
            "UPDATE users SET otp_code = %s, otp_expires_at = %s WHERE id = %s",
            (otp_code, otp_expires_at, user["id"])
        )
        db.commit()

        send_otp_email(data.email, user["full_name"], otp_code)

        return {"status": "success", "message": "Kode OTP baru sudah dikirim ke email kamu."}
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
        query = "SELECT id, full_name, password_hash, is_verified FROM users WHERE email = %s"
        cursor.execute(query, (data.email,))
        user = cursor.fetchone()
        
        # B. Jika email tidak ditemukan
        if not user:
            return {"status": "error", "message": "Email atau password salah!"}

        # B2. Akun ini terdaftar lewat Google saja, tidak punya password
        if not user['password_hash']:
            return {"status": "error", "message": "Akun ini terdaftar dengan Google. Silakan gunakan tombol 'Login with Google'."}

        # B3. Akun belum verifikasi OTP
        if not user['is_verified']:
            return {"status": "error", "message": "Akun belum diverifikasi. Silakan cek OTP di email kamu.", "email": data.email, "needs_verification": True}
        
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


# 6b. Model & Endpoint untuk Login/Daftar via Google
class GoogleLoginInput(BaseModel):
    id_token: str

@app.post("/api/auth/google")
def google_login(data: GoogleLoginInput):
    if not GOOGLE_CLIENT_ID:
        return {"status": "error", "message": "GOOGLE_CLIENT_ID belum dikonfigurasi di server."}

    # A. Verifikasi token asli dari Google (memastikan bukan token palsu)
    try:
        id_info = google_id_token.verify_oauth2_token(
            data.id_token, google_requests.Request(), GOOGLE_CLIENT_ID
        )
    except ValueError:
        return {"status": "error", "message": "Token Google tidak valid."}

    google_sub = id_info["sub"]           # ID unik akun Google
    email = id_info.get("email")
    # Dibatasi 10 karakter, konsisten dengan batas nama di form Register manual,
    # supaya nama panjang dari akun Google tidak overflow di tampilan kartu Home.
    full_name = (id_info.get("name", email) or email).strip()[:10]

    if not email:
        return {"status": "error", "message": "Google tidak memberikan email."}

    db = get_db_connection()
    if not db:
        return {"status": "error", "message": "Database connection failed"}

    cursor = db.cursor(dictionary=True)
    try:
        cursor.execute("SELECT id, full_name, google_id FROM users WHERE email = %s", (email,))
        user = cursor.fetchone()

        if user:
            # Akun sudah ada (mungkin daftar manual sebelumnya) -> tautkan google_id jika belum ada
            if not user["google_id"]:
                cursor.execute(
                    "UPDATE users SET google_id = %s, is_verified = TRUE WHERE id = %s",
                    (google_sub, user["id"])
                )
                db.commit()
            user_id = user["id"]
            name = user["full_name"]
        else:
            # Akun baru -> langsung terverifikasi karena email dari Google sudah pasti asli
            cursor.execute(
                """INSERT INTO users (full_name, email, password_hash, is_verified, google_id) 
                   VALUES (%s, %s, NULL, TRUE, %s)""",
                (full_name, email, google_sub)
            )
            db.commit()
            user_id = cursor.lastrowid
            name = full_name

        return {
            "status": "success",
            "message": f"Selamat datang, {name}!",
            "user": {"id": user_id, "full_name": name, "email": email}
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
            SELECT u.id, u.full_name, u.email, u.profile_photo,
                   COALESCE(AVG(r.rating), 0) as average_rating
            FROM users u
            JOIN user_skills us ON u.id = us.user_id
            LEFT JOIN reviews r ON u.id = r.reviewed_user_id
            WHERE us.skill_type = 'CAN' 
            AND us.skill_name IN ({placeholders})
            AND u.id != %s
            AND u.id NOT IN (SELECT COALESCE(swiped_id, 0) FROM swipes WHERE swiper_id = %s)
            AND u.id NOT IN (SELECT blocked_id FROM blocks WHERE blocker_id = %s)
            AND u.id NOT IN (SELECT blocker_id FROM blocks WHERE blocked_id = %s)
            GROUP BY u.id, u.full_name, u.email, u.profile_photo
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
                "average_rating": round(float(r_user['average_rating']), 1),
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

# Pencarian nama user (dipakai di halaman Explore -> kolom cari nama).
# BEDA dengan /api/discover: di sini TIDAK ada filter skill dan TIDAK
# mengecualikan user yang sudah pernah di-swipe, jadi user yang sudah
# pernah digeser di Home tetap bisa ditemukan lewat pencarian nama ini.
@app.get("/api/users/search")
def search_users_by_name(user_id: int, query: str = ""):
    connection = get_db_connection()
    if not connection:
        raise HTTPException(status_code=500, detail="Database connection failed")

    cursor = connection.cursor(dictionary=True)
    try:
        query = (query or "").strip()
        if not query:
            return {"status": "success", "count": 0, "data": []}

        search_query = """
            SELECT id, full_name, profile_photo
            FROM users
            WHERE full_name LIKE %s
            AND id != %s
            AND id NOT IN (SELECT blocked_id FROM blocks WHERE blocker_id = %s)
            AND id NOT IN (SELECT blocker_id FROM blocks WHERE blocked_id = %s)
            ORDER BY full_name ASC
            LIMIT 30
        """
        params = [f"{query}%", user_id, user_id, user_id]
        cursor.execute(search_query, params)
        users = cursor.fetchall()

        final_data = [
            {
                "id": u["id"],
                "name": u["full_name"],
                "profile_photo": u["profile_photo"],
            }
            for u in users
        ]

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
def get_user_profile(user_id: int, viewer_id: int = None):
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

        # 3. Hitung jumlah followers & following
        cursor.execute("SELECT COUNT(*) as c FROM follows WHERE following_id = %s", (user_id,))
        user_data['followers_count'] = cursor.fetchone()['c']

        cursor.execute("SELECT COUNT(*) as c FROM follows WHERE follower_id = %s", (user_id,))
        user_data['following_count'] = cursor.fetchone()['c']

        # 4. Status follow relatif terhadap viewer (kalau viewer_id dikirim & bukan profil sendiri)
        user_data['is_following'] = False
        if viewer_id and viewer_id != user_id:
            cursor.execute(
                "SELECT id FROM follows WHERE follower_id = %s AND following_id = %s",
                (viewer_id, user_id)
            )
            user_data['is_following'] = cursor.fetchone() is not None

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

        # 3. Putus juga hubungan follow (follower & following) di kedua arah
        query_delete_follow = """
            DELETE FROM follows
            WHERE (follower_id = %s AND following_id = %s) OR (follower_id = %s AND following_id = %s)
        """
        cursor.execute(query_delete_follow, (data.blocker_id, data.blocked_id, data.blocked_id, data.blocker_id))
        
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

# =====================================================================
# CHAPTER 10: FOLLOW SYSTEM (Followers / Following)
# =====================================================================

class FollowInput(BaseModel):
    follower_id: int
    following_id: int

@app.post("/api/follow")
def follow_user(data: FollowInput):
    if data.follower_id == data.following_id:
        raise HTTPException(status_code=400, detail="Tidak bisa follow diri sendiri")

    connection = get_db_connection()
    if not connection:
        raise HTTPException(status_code=500, detail="Database connection failed")
    cursor = connection.cursor()
    try:
        query = "INSERT IGNORE INTO follows (follower_id, following_id) VALUES (%s, %s)"
        cursor.execute(query, (data.follower_id, data.following_id))
        connection.commit()
        return {"status": "success", "message": "Berhasil mengikuti pengguna."}
    except mysql.connector.Error as err:
        raise HTTPException(status_code=500, detail=f"Database error: {err}")
    finally:
        cursor.close()
        connection.close()

@app.post("/api/unfollow")
def unfollow_user(data: FollowInput):
    connection = get_db_connection()
    if not connection:
        raise HTTPException(status_code=500, detail="Database connection failed")
    cursor = connection.cursor()
    try:
        query = "DELETE FROM follows WHERE follower_id = %s AND following_id = %s"
        cursor.execute(query, (data.follower_id, data.following_id))
        connection.commit()
        return {"status": "success", "message": "Berhasil berhenti mengikuti pengguna."}
    except mysql.connector.Error as err:
        raise HTTPException(status_code=500, detail=f"Database error: {err}")
    finally:
        cursor.close()
        connection.close()

@app.get("/api/followers/{user_id}")
def get_followers(user_id: int, viewer_id: int = None):
    """Daftar orang yang mem-follow user_id. Bisa dilihat siapa saja."""
    connection = get_db_connection()
    if not connection:
        raise HTTPException(status_code=500, detail="Database connection failed")
    cursor = connection.cursor(dictionary=True)
    try:
        query = """
            SELECT u.id, u.full_name, u.profile_photo
            FROM follows f
            JOIN users u ON u.id = f.follower_id
            WHERE f.following_id = %s
            ORDER BY f.created_at DESC
        """
        cursor.execute(query, (user_id,))
        followers = cursor.fetchall()

        # Tandai apakah viewer (yang sedang login) sudah follow tiap orang di list ini
        if viewer_id:
            for person in followers:
                cursor.execute(
                    "SELECT id FROM follows WHERE follower_id = %s AND following_id = %s",
                    (viewer_id, person['id'])
                )
                person['is_following'] = cursor.fetchone() is not None
        else:
            for person in followers:
                person['is_following'] = False

        return {"status": "success", "data": followers}
    except mysql.connector.Error as err:
        raise HTTPException(status_code=500, detail=f"Database error: {err}")
    finally:
        cursor.close()
        connection.close()

@app.get("/api/following/{user_id}")
def get_following(user_id: int, viewer_id: int = None):
    """Daftar orang yang di-follow oleh user_id. Bisa dilihat siapa saja."""
    connection = get_db_connection()
    if not connection:
        raise HTTPException(status_code=500, detail="Database connection failed")
    cursor = connection.cursor(dictionary=True)
    try:
        query = """
            SELECT u.id, u.full_name, u.profile_photo
            FROM follows f
            JOIN users u ON u.id = f.following_id
            WHERE f.follower_id = %s
            ORDER BY f.created_at DESC
        """
        cursor.execute(query, (user_id,))
        following = cursor.fetchall()

        if viewer_id:
            for person in following:
                cursor.execute(
                    "SELECT id FROM follows WHERE follower_id = %s AND following_id = %s",
                    (viewer_id, person['id'])
                )
                person['is_following'] = cursor.fetchone() is not None
        else:
            for person in following:
                person['is_following'] = False

        return {"status": "success", "data": following}
    except mysql.connector.Error as err:
        raise HTTPException(status_code=500, detail=f"Database error: {err}")
    finally:
        cursor.close()
        connection.close()

class RemoveFollowerInput(BaseModel):
    user_id: int      # pemilik akun (yang sedang menghapus follower-nya sendiri)
    follower_id: int  # follower yang ingin dihapus

@app.post("/api/followers/remove")
def remove_follower(data: RemoveFollowerInput):
    """Pemilik akun menghapus salah satu followernya sendiri (tidak sama dengan unfollow)."""
    connection = get_db_connection()
    if not connection:
        raise HTTPException(status_code=500, detail="Database connection failed")
    cursor = connection.cursor()
    try:
        query = "DELETE FROM follows WHERE follower_id = %s AND following_id = %s"
        cursor.execute(query, (data.follower_id, data.user_id))
        connection.commit()
        return {"status": "success", "message": "Follower berhasil dihapus."}
    except mysql.connector.Error as err:
        raise HTTPException(status_code=500, detail=f"Database error: {err}")
    finally:
        cursor.close()
        connection.close()

# =====================================================================
# CHAPTER 11: DIRECT CHAT (Tombol "Chat Sekarang" dari Profil)
# =====================================================================

class DirectChatInput(BaseModel):
    user_a_id: int
    user_b_id: int

@app.post("/api/match/direct")
def get_or_create_direct_match(data: DirectChatInput):
    """Dipanggil dari tombol 'Chat Sekarang' di profil user lain. Kalau belum pernah
    match, langsung buatkan sesi match baru supaya bisa langsung chat tanpa swipe dulu."""
    if data.user_a_id == data.user_b_id:
        raise HTTPException(status_code=400, detail="Tidak bisa chat dengan diri sendiri")

    connection = get_db_connection()
    if not connection:
        raise HTTPException(status_code=500, detail="Database connection failed")
    cursor = connection.cursor(dictionary=True)
    try:
        cursor.execute("""
            SELECT id FROM matches
            WHERE (user1_id = %s AND user2_id = %s) OR (user1_id = %s AND user2_id = %s)
            LIMIT 1
        """, (data.user_a_id, data.user_b_id, data.user_b_id, data.user_a_id))
        existing = cursor.fetchone()
        if existing:
            return {"status": "success", "match_id": existing['id']}

        cursor.execute(
            "INSERT INTO matches (user1_id, user2_id, status) VALUES (%s, %s, 'MATCHED')",
            (data.user_a_id, data.user_b_id)
        )
        connection.commit()
        return {"status": "success", "match_id": cursor.lastrowid}
    except mysql.connector.Error as err:
        raise HTTPException(status_code=500, detail=f"Database error: {err}")
    finally:
        cursor.close()
        connection.close()

# =====================================================================
# CHAPTER 12: PROFILE GALLERY (Foto Sertifikat / Profesional di Profil)
# =====================================================================

class GalleryPhotoInput(BaseModel):
    user_id: int
    photo_base64: str

@app.post("/api/gallery/add")
def add_gallery_photo(data: GalleryPhotoInput):
    connection = get_db_connection()
    if not connection:
        raise HTTPException(status_code=500, detail="Database connection failed")
    cursor = connection.cursor()
    try:
        query = "INSERT INTO profile_gallery (user_id, photo_base64) VALUES (%s, %s)"
        cursor.execute(query, (data.user_id, data.photo_base64))
        connection.commit()
        return {"status": "success", "message": "Foto berhasil ditambahkan.", "photo_id": cursor.lastrowid}
    except mysql.connector.Error as err:
        raise HTTPException(status_code=500, detail=f"Database error: {err}")
    finally:
        cursor.close()
        connection.close()

@app.get("/api/gallery/{user_id}")
def get_gallery_photos(user_id: int):
    connection = get_db_connection()
    if not connection:
        raise HTTPException(status_code=500, detail="Database connection failed")
    cursor = connection.cursor(dictionary=True)
    try:
        cursor.execute(
            "SELECT id, photo_base64, created_at FROM profile_gallery WHERE user_id = %s ORDER BY created_at DESC",
            (user_id,)
        )
        photos = cursor.fetchall()
        return {"status": "success", "data": photos}
    except mysql.connector.Error as err:
        raise HTTPException(status_code=500, detail=f"Database error: {err}")
    finally:
        cursor.close()
        connection.close()

@app.delete("/api/gallery/delete/{photo_id}")
def delete_gallery_photo(photo_id: int, user_id: int):
    """user_id (query param) wajib dikirim untuk memastikan hanya pemilik foto
    yang bisa menghapus fotonya sendiri."""
    connection = get_db_connection()
    if not connection:
        raise HTTPException(status_code=500, detail="Database connection failed")
    cursor = connection.cursor()
    try:
        cursor.execute("SELECT user_id FROM profile_gallery WHERE id = %s", (photo_id,))
        row = cursor.fetchone()
        if not row:
            raise HTTPException(status_code=404, detail="Foto tidak ditemukan")
        if row[0] != user_id:
            raise HTTPException(status_code=403, detail="Kamu tidak berhak menghapus foto ini")

        cursor.execute("DELETE FROM profile_gallery WHERE id = %s", (photo_id,))
        connection.commit()
        return {"status": "success", "message": "Foto berhasil dihapus."}
    except mysql.connector.Error as err:
        raise HTTPException(status_code=500, detail=f"Database error: {err}")
    finally:
        cursor.close()
        connection.close()
