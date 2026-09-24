import sqlite3
DB_PATH = "/home/ubuntu/quran-telegram-bot/quran_bot.db"
conn = sqlite3.connect(DB_PATH)
cursor = conn.cursor()
cursor.execute("PRAGMA table_info(users)")
cols = [c[1] for c in cursor.fetchall()]
for col, type_def in [('hifz_current_page', 'INTEGER DEFAULT 1'), ('last_hifz_date', 'TEXT')]:
    if col not in cols:
        cursor.execute(f"ALTER TABLE users ADD COLUMN {col} {type_def}")
conn.commit()
conn.close()
print("DB Hifz Patched")
