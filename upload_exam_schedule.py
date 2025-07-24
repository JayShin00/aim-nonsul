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
    """
    CSV 파일을 Firestore에 동기화하는 함수
    - 기존 데이터가 있으면 업데이트, 없으면 새로 추가
    - examDate가 비어있는 데이터는 건너뛰기
    - NaN 값 처리를 위해 dtype=str, keep_default_na=False 사용
    
    Args:
        csv_file (str): CSV 파일 경로
        collection_name (str): Firestore 컬렉션 이름
    """
    try:
        # CSV 파일 읽기 - 모든 컬럼을 문자열로, NaN을 빈 문자열로 처리
        df = pd.read_csv(csv_file, dtype=str, keep_default_na=False)
        total_rows = len(df)
        
        # 카운터 초기화
        updated_count = 0      # 기존 데이터 업데이트 개수
        added_count = 0        # 신규 데이터 추가 개수
        skipped_count = 0      # 건너뛴 데이터 개수
        error_count = 0        # 에러 발생 개수
        
        print(f"📊 총 {total_rows}개 데이터 동기화 시작...")
        print(f"📁 파일: {csv_file}")
        print(f"🗄️  컬렉션: {collection_name}")
        print("-" * 50)
        
        for index, row in df.iterrows():
            try:
                # 고유 ID 추출 (문자열로 변환하여 안전성 확보)
                doc_id = str(row["id"]).strip()
                
                # examDate가 비어있는지 확인
                date_str = row['examDate'].strip()
                time_str = row['examTime'].strip()
                
                # examDate가 비어있으면 건너뛰기
                if not date_str:
                    print(f"⏭️  [{index+1:4d}] 건너뛰기: examDate 없음 - {row['university']} {row['department']}")
                    skipped_count += 1
                    continue
                
                # 날짜/시간 처리
                exam_datetime = None
                
                if not time_str:
                    # 시간이 없으면 날짜만 (00:00:00으로 설정)
                    exam_datetime = datetime.strptime(date_str, "%Y-%m-%d")
                else:
                    # 날짜와 시간을 결합
                    combined_str = f"{date_str} {time_str}"
                    exam_datetime = datetime.strptime(combined_str, "%Y-%m-%d %H:%M")
                
                # Firestore에 저장할 데이터 구성
                data = {
                    "id": int(doc_id),                    # 고유 ID (정수형)
                    "university": row["university"],      # 대학교명
                    "category": row["category"],          # 계열 (인문/자연/공통 등)
                    "department": row["department"],      # 학과명
                    "examDateTime": exam_datetime,        # 시험 날짜/시간
                }
                
                # 기존 문서 존재 여부 확인 (id 필드로 검색)
                existing_docs = db.collection(collection_name).where("id", "==", int(doc_id)).limit(1).get()
                
                if existing_docs:
                    # 기존 문서가 있으면 업데이트
                    doc_ref = existing_docs[0].reference
                    doc_ref.update(data)
                    updated_count += 1
                    print(f"🔄 [{index+1:4d}] 업데이트: ID {doc_id} - {row['university']} {row['department']}")
                else:
                    # 새 문서 추가
                    db.collection(collection_name).add(data)
                    added_count += 1
                    print(f"➕ [{index+1:4d}] 신규추가: ID {doc_id} - {row['university']} {row['department']}")
                
                # 진행률 출력 (100개마다)
                if (updated_count + added_count) % 100 == 0:
                    print(f"📈 진행률: {updated_count + added_count}/{total_rows} (업데이트: {updated_count}, 추가: {added_count})")
                    
            except Exception as e:
                # 개별 행 처리 중 에러 발생 시
                error_count += 1
                print(f"❌ [{index+1:4d}] 처리 실패: {e}")
                print(f"   📋 문제 데이터: ID={row.get('id', 'N/A')}, {row.get('university', 'N/A')} {row.get('department', 'N/A')}")
        
        # 최종 결과 출력
        print("-" * 50)
        print(f"✅ 동기화 완료")
        print(f"   📖 전체: {total_rows}개")
        print(f"   🔄 업데이트: {updated_count}개")
        print(f"   ➕ 신규추가: {added_count}개")
        print(f"   ⏭️  건너뛰기: {skipped_count}개")
        print(f"   ❌ 실패: {error_count}개")
        
    except Exception as e:
        # CSV 파일 읽기 또는 전체 프로세스 에러
        print(f"💥 CSV 파일 처리 중 치명적 오류: {e}")
        print(f"   📁 파일 경로: {csv_file}")
        print(f"   🔍 파일 존재 여부, 형식, 권한을 확인해주세요.")

if __name__ == "__main__":
    upload_csv_to_firestore(CSV_FILE_PATH, COLLECTION_NAME)