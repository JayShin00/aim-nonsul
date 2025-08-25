import firebase_admin
from firebase_admin import credentials, firestore
import pandas as pd
from datetime import datetime
import pytz  # 한국시간 변환용

# 서비스 계정 키 경로
SERVICE_ACCOUNT_KEY_PATH = 'aim-nonsul-84e84-firebase-adminsdk-fbsvc-ff11833235.json'
# CSV 파일 경로
CSV_FILE_PATH = 'assets/exam_schedule.csv'
# Firestore 컬렉션 이름
COLLECTION_NAME = 'examSchedules'

# 한국시간(KST) 타임존 객체
kst = pytz.timezone("Asia/Seoul")

# Firebase Admin SDK 초기화
cred = credentials.Certificate(SERVICE_ACCOUNT_KEY_PATH)
firebase_admin.initialize_app(cred)
db = firestore.client()

def upload_csv_to_firestore(csv_file, collection_name):
    """
    CSV 파일을 Firestore에 동기화하는 함수
    - 기존 데이터가 있으면 업데이트, 없으면 새로 추가
    - examDate가 비어있는 데이터는 건너뛰기
    - NaN 값 처리를 위해 dtype=str, keep_default_na=False 사용
    """
    try:
        # CSV 파일 읽기
        df = pd.read_csv(csv_file, dtype=str, keep_default_na=False)
        total_rows = len(df)
        
        updated_count = 0
        added_count = 0
        skipped_count = 0
        error_count = 0
        
        print(f"📊 총 {total_rows}개 데이터 동기화 시작...")
        print(f"📁 파일: {csv_file}")
        print(f"🗄️  컬렉션: {collection_name}")
        print("-" * 50)
        
        for index, row in df.iterrows():
            try:
                doc_id = str(row["id"]).strip()
                date_str = row['examDate'].strip()
                time_str = row['examTime'].strip()
                
                if not date_str:
                    print(f"⏭️  [{index+1:4d}] 건너뛰기: examDate 없음 - {row['university']} {row['department']}")
                    skipped_count += 1
                    continue
                
                # 날짜/시간 처리 (한국시간 적용)
                if not time_str:
                    exam_datetime = datetime.strptime(date_str, "%Y-%m-%d")
                else:
                    combined_str = f"{date_str} {time_str}"
                    exam_datetime = datetime.strptime(combined_str, "%Y-%m-%d %H:%M")
                
                # 한국시간(KST)으로 변환
                exam_datetime = kst.localize(exam_datetime)
                
                # Firestore에 저장할 데이터
                data = {
                    "id": int(doc_id),
                    "university": row["university"],
                    "category": row["category"],
                    "department": row["department"],
                    "examDateTime": exam_datetime,
                }
                
                existing_docs = db.collection(collection_name).where("id", "==", int(doc_id)).limit(1).get()
                if existing_docs:
                    existing_docs[0].reference.update(data)
                    updated_count += 1
                    print(f"🔄 [{index+1:4d}] 업데이트: ID {doc_id} - {row['university']} {row['department']}")
                else:
                    db.collection(collection_name).add(data)
                    added_count += 1
                    print(f"➕ [{index+1:4d}] 신규추가: ID {doc_id} - {row['university']} {row['department']}")
                
                if (updated_count + added_count) % 100 == 0:
                    print(f"📈 진행률: {updated_count + added_count}/{total_rows}")
                    
            except Exception as e:
                error_count += 1
                print(f"❌ [{index+1:4d}] 처리 실패: {e}")
                print(f"   📋 문제 데이터: ID={row.get('id', 'N/A')}, {row.get('university', 'N/A')} {row.get('department', 'N/A')}")
        
        print("-" * 50)
        print(f"✅ 동기화 완료")
        print(f"   📖 전체: {total_rows}개")
        print(f"   🔄 업데이트: {updated_count}개")
        print(f"   ➕ 신규추가: {added_count}개")
        print(f"   ⏭️  건너뛰기: {skipped_count}개")
        print(f"   ❌ 실패: {error_count}개")
        
    except Exception as e:
        print(f"💥 CSV 파일 처리 중 치명적 오류: {e}")

if __name__ == "__main__":
    upload_csv_to_firestore(CSV_FILE_PATH, COLLECTION_NAME)