import firebase_admin
from firebase_admin import credentials
from firebase_admin import firestore
import pandas as pd
from datetime import datetime

# 서비스 계정 키 경로
SERVICE_ACCOUNT_KEY_PATH = 'aim-nonsul-firebase-adminsdk-fbsvc-bc7f3e2260.json'
# CSV 파일 경로
CSV_FILE_PATH = 'assets/exam_schedule.csv'
# Firestore 컬렉션 이름
COLLECTION_NAME = 'examSchedules'

# Firebase Admin SDK 초기화
cred = credentials.Certificate(SERVICE_ACCOUNT_KEY_PATH)
firebase_admin.initialize_app(cred)

db = firestore.client()

def upload_csv_to_firestore(csv_file, collection_name):
    try:
        df = pd.read_csv(csv_file)
        for index, row in df.iterrows():
            # 날짜+시간 결합 → datetime 변환
            date_str = row['examDate']  # e.g. "2025-11-08"
            time_str = row['examTime']  # e.g. "13:00"
            combined_str = f"{date_str} {time_str}"
            exam_datetime = datetime.strptime(combined_str, "%Y-%m-%d %H:%M")

            # 저장할 데이터 구성
            data = {
                "id": int(row["id"]),
                "university": row["university"],
                "department": row["department"],
                "address": row["address"],
                "examDateTime": exam_datetime,
            }

            doc_ref = db.collection(collection_name).document()  # 자동 ID
            doc_ref.set(data)
            print(f"Document {doc_ref.id} added.")

        print(f"Data from {csv_file} successfully uploaded to Firestore collection: {collection_name}")
    except Exception as e:
        print(f"Error uploading data: {e}")

if __name__ == "__main__":
    upload_csv_to_firestore(CSV_FILE_PATH, COLLECTION_NAME)