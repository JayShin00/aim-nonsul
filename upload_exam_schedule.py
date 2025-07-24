import firebase_admin
from firebase_admin import credentials, firestore
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
        total_rows = len(df)
        success_count = 0
        error_count = 0
        
        print(f"총 {total_rows}개 데이터 업로드 시작...")
        
        for index, row in df.iterrows():
            try:
                # 날짜+시간 결합 → datetime 변환
                date_str = row['examDate']  # 예: 2025-11-22
                time_str = row['examTime']  # 예: 09:00
                
                # examTime이 비어있는 경우 날짜만으로 datetime 생성
                if pd.isna(time_str) or time_str == '' or time_str.strip() == '':
                    exam_datetime = datetime.strptime(date_str, "%Y-%m-%d")
                else:
                    combined_str = f"{date_str} {time_str}"
                    exam_datetime = datetime.strptime(combined_str, "%Y-%m-%d %H:%M")

                # 저장할 데이터 구성
                data = {
                    "id": int(row["id"]),
                    "university": row["university"],
                    "category": row["category"],
                    "department": row["department"],
                    "examDateTime": exam_datetime,
                }

                doc_ref = db.collection(collection_name).document()  # 자동 ID
                doc_ref.set(data)
                success_count += 1
                
                if success_count % 100 == 0:
                    print(f"진행률: {success_count}/{total_rows}")
                    
            except Exception as e:
                error_count += 1
                print(f"Row {index + 1} 업로드 실패: {e}")
                print(f"문제 데이터: {dict(row)}")

        print(f"!! 업로드 완료 - 성공: {success_count}개, 실패: {error_count}개")
        print(f"!! Data from {csv_file} uploaded to Firestore collection: {collection_name}")
    except Exception as e:
        print(f"!! Error uploading data: {e}")

if __name__ == "__main__":
    upload_csv_to_firestore(CSV_FILE_PATH, COLLECTION_NAME)