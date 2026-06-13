import os
from sqlalchemy import create_engine, text
from dotenv import load_dotenv

load_dotenv()


def get_engine():
    host = os.getenv("DB_HOST", "localhost")
    port = os.getenv("DB_PORT", "3306")
    user = os.getenv("DB_USER", "root")
    password = os.getenv("DB_PASSWORD", "")
    db = os.getenv("DB_NAME", "")

    url = f"mysql+pymysql://{user}:{password}@{host}:{port}/{db}"
    engine = create_engine(url, echo=False)
    return engine


def test_connection():
    try:
        engine = get_engine()
        with engine.connect() as conn:
            conn.execute(text("SELECT 1"))
        print("[OK] Database connection successful.")
        return True
    except Exception as e:
        print(f"[ERROR] Database connection failed: {e}")
        return False