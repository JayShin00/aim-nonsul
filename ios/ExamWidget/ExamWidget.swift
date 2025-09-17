//
//  ExamWidget.swift
//  ExamWidget
//
//  Created by Hyun Jaeyeon on 7/5/25.
//

import WidgetKit
import SwiftUI
import AppIntents

// 시험 정보 데이터 구조
struct ExamInfo {
    let university: String
    let department: String
    let examDate: Date
    let isPrimary: Bool
    let id: String // Unique identifier for smooth transitions
    
    var dDayText: String {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let examDay = calendar.startOfDay(for: examDate)
        let daysBetween = calendar.dateComponents([.day], from: today, to: examDay).day ?? 0
        
        if daysBetween == 0 {
            return "D-Day"
        } else if daysBetween > 0 {
            return "D-\(daysBetween)"
        } else {
            return "종료"
        }
    }
    
    var dDayColor: Color {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let examDay = calendar.startOfDay(for: examDate)
        let daysBetween = calendar.dateComponents([.day], from: today, to: examDay).day ?? 0
        
        if daysBetween <= 0 {
            return Color.gray
        } else {
            return Color(red: 0.84, green: 0.20, blue: 0.52) // AIM 핑크
        }
    }
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy.MM.dd"
        return formatter.string(from: examDate)
    }
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        let sampleExam = ExamInfo(
            university: "서울대학교",
            department: "컴퓨터공학과",
            examDate: Calendar.current.date(byAdding: .day, value: 15, to: Date()) ?? Date(),
            isPrimary: true,
            id: "placeholder-exam"
        )
        return SimpleEntry(date: Date(), examInfo: sampleExam, carouselData: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        NSLog("ExamWidget: getSnapshot 호출됨")
        let carouselData = loadCarouselData()
        let examInfo = getCurrentExam(from: carouselData)
        let entry = SimpleEntry(date: Date(), examInfo: examInfo, carouselData: carouselData)
        NSLog("ExamWidget: getSnapshot 완료 - examInfo: \(examInfo?.id ?? "nil")")
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        let currentDate = Date()
        let carouselData = loadCarouselData()
        
        NSLog("ExamWidget: getTimeline 호출됨 - 현재 시간: \(currentDate)")
        
        guard let data = carouselData, !data.examList.isEmpty else {
            NSLog("ExamWidget: 데이터 없음 - 빈 엔트리 생성")
            // No exams, create single empty entry
            let entry = SimpleEntry(date: currentDate, examInfo: nil, carouselData: nil)
            let timeline = Timeline(entries: [entry], policy: .after(Calendar.current.date(byAdding: .hour, value: 1, to: currentDate)!))
            completion(timeline)
            return
        }
        
        NSLog("ExamWidget: Timeline 생성 시작 - \(data.examList.count)개 시험")
        var entries: [SimpleEntry] = []
        
        if data.examList.count > 1 {
            NSLog("ExamWidget: 다중 시험 Timeline 생성 - Carousel 모드")
            // Multiple exams: Create carousel timeline with auto-scroll starting from current index
            let intervalSeconds = 3 // 3 seconds per slide (fast carousel)
            let maxEntries = min(data.examList.count * 4, 20) // Limit total entries
            
            NSLog("ExamWidget: Carousel 설정 - \(intervalSeconds)초 간격, 최대 \(maxEntries)개 엔트리, 시작 인덱스: \(data.currentIndex)")
            
            for i in 0..<maxEntries {
                // Start from current index and cycle through
                let examIndex = (data.currentIndex + i) % data.examList.count
                let entryDate = Calendar.current.date(byAdding: .second, value: i * intervalSeconds, to: currentDate)!
                
                let examInfo = createExamInfo(from: data.examList[examIndex])
                let entryCarouselData = CarouselWidgetData(
                    examList: data.examList,
                    currentIndex: examIndex, // Use the actual exam index being displayed
                    totalCount: data.examList.count
                )
                
                let entry = SimpleEntry(date: entryDate, examInfo: examInfo, carouselData: entryCarouselData)
                entries.append(entry)
                
                NSLog("ExamWidget: 엔트리 \(i) 생성됨 - 시간: \(entryDate), 시험 인덱스: \(examIndex) (\(data.examList[examIndex].department))")
            }
            
            // Continue cycling after timeline ends
            let nextUpdate = Calendar.current.date(byAdding: .second, value: maxEntries * intervalSeconds, to: currentDate)!
            let timeline = Timeline(entries: entries, policy: .after(nextUpdate))
            NSLog("ExamWidget: Carousel Timeline 완료 - \(entries.count)개 엔트리, 다음 업데이트: \(nextUpdate)")
            completion(timeline)
        } else {
            NSLog("ExamWidget: 단일 시험 Timeline 생성")
            // Single exam: Update hourly to keep D-Day accurate
            for hourOffset in 0..<6 {
                let entryDate = Calendar.current.date(byAdding: .hour, value: hourOffset * 4, to: currentDate)!
                let examInfo = createExamInfo(from: data.examList[0])
                let entry = SimpleEntry(date: entryDate, examInfo: examInfo, carouselData: data)
                entries.append(entry)
                
                NSLog("ExamWidget: 단일 시험 엔트리 \(hourOffset) 생성됨 - 시간: \(entryDate)")
            }
            
            let nextUpdate = Calendar.current.date(byAdding: .day, value: 1, to: currentDate)!
            let timeline = Timeline(entries: entries, policy: .after(nextUpdate))
            NSLog("ExamWidget: 단일 시험 Timeline 완료 - \(entries.count)개 엔트리, 다음 업데이트: \(nextUpdate)")
            completion(timeline)
        }
    }
    
    private func loadCarouselData() -> CarouselWidgetData? {
        // UserDefaults에서 home_widget 데이터 로드
        let userDefaults = UserDefaults(suiteName: "group.com.aim.aimNonsul.ExamWidget")

        // 디버깅용 로그 (using NSLog for widget debugging)
        NSLog("ExamWidget: App Group ID = group.com.aim.aimNonsul.ExamWidget")
        NSLog("ExamWidget: UserDefaults 객체 생성 성공: \(userDefaults != nil ? "true" : "false")")
        
        // App Group 접근 가능 여부 확인
        if userDefaults == nil {
            NSLog("ExamWidget: CRITICAL ERROR - App Group 접근 실패! entitlements 확인 필요")
            return nil
        }
        
        // Check current index first for debugging
        let persistedCurrentIndex = userDefaults?.integer(forKey: "current_index") ?? 0
        NSLog("ExamWidget: 저장된 current_index: \(persistedCurrentIndex)")
        
        // Debug: Print all available keys (using NSLog for widget debugging)
        if let userDefaults = userDefaults {
            let allKeys = userDefaults.dictionaryRepresentation()
            NSLog("ExamWidget: 저장된 모든 키들: \(allKeys.count)개")
            for (key, value) in allKeys {
                NSLog("ExamWidget: '\(key)' = '\(String(describing: value))'")
            }
        } else {
            NSLog("ExamWidget: UserDefaults가 nil입니다!")
        }
        
        // First try to load carousel data (try without flutter prefix first, then with)
        var carouselJsonString: String?
        if let jsonString = userDefaults?.string(forKey: "carousel_data") {
            carouselJsonString = jsonString
            NSLog("ExamWidget: 발견된 carousel_data (접두사 없음): \(jsonString.count) 문자")
        } else if let jsonString = userDefaults?.string(forKey: "flutter.carousel_data") {
            carouselJsonString = jsonString
            NSLog("ExamWidget: 발견된 carousel_data (flutter. 접두사 있음): \(jsonString.count) 문자")
        } else {
            NSLog("ExamWidget: carousel_data 키를 찾을 수 없음")
        }
        
        if let jsonString = carouselJsonString {
            NSLog("ExamWidget: carousel_data 발견됨, 파싱 시도 중...")
            if let carouselData = parseCarouselData(jsonString: jsonString, userDefaults: userDefaults) {
                NSLog("ExamWidget: Carousel 데이터 로드 성공: \(carouselData.examList.count)개 시험")
                return carouselData
            } else {
                NSLog("ExamWidget: Carousel 데이터 파싱 실패, 원본 JSON: \(jsonString)")
                // Don't fall back immediately - carousel data exists but parsing failed
                // This indicates a data format issue we should fix
            }
        } else {
            NSLog("ExamWidget: carousel_data 키를 전혀 찾을 수 없음")
        }
        
        // Only fallback to traditional single exam data if carousel_data doesn't exist at all
        if carouselJsonString == nil {
            NSLog("ExamWidget: Carousel 데이터가 없으므로 개별 키로 fallback")
        } else {
            NSLog("ExamWidget: Carousel 데이터 파싱 실패했지만 강제로 개별 키 시도")
        }
        
        let examTitle = userDefaults?.string(forKey: "exam_title") ?? userDefaults?.string(forKey: "flutter.exam_title")
        let examUniversity = userDefaults?.string(forKey: "exam_university") ?? userDefaults?.string(forKey: "flutter.exam_university")
        let examDate = userDefaults?.string(forKey: "exam_date") ?? userDefaults?.string(forKey: "flutter.exam_date")
        let examTime = userDefaults?.string(forKey: "exam_time") ?? userDefaults?.string(forKey: "flutter.exam_time")
        
        NSLog("ExamWidget: 개별 키 결과 - title: \(examTitle ?? "nil"), university: \(examUniversity ?? "nil"), date: \(examDate ?? "nil"), time: \(examTime ?? "nil")")
        
        if let examTitle = examTitle,
           let examUniversity = examUniversity,
           let examDate = examDate,
           let examTime = examTime,
           !examTitle.isEmpty,
           !examDate.isEmpty {

            NSLog("ExamWidget: Fallback 단일 시험 데이터 로드 성공")

            // 날짜 파싱
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"

            let timeFormatter = DateFormatter()
            timeFormatter.dateFormat = "HH:mm"

            if let parsedDate = dateFormatter.date(from: examDate) {
                var examDateTime = parsedDate

                // 시간 정보가 있으면 추가
                if !examTime.isEmpty, let parsedTime = timeFormatter.date(from: examTime) {
                    let calendar = Calendar.current
                    let timeComponents = calendar.dateComponents([.hour, .minute], from: parsedTime)
                    examDateTime = calendar.date(bySettingHour: timeComponents.hour ?? 0,
                                               minute: timeComponents.minute ?? 0,
                                               second: 0,
                                               of: parsedDate) ?? parsedDate
                }

                // 대학명과 학과명 분리 (⭐ 제거)
                let cleanTitle = examTitle.replacingOccurrences(of: "⭐ ", with: "")
                let isPrimary = examTitle.contains("⭐")

                let examData = CarouselExamData(
                    university: examUniversity,
                    department: cleanTitle,
                    category: "",
                    examDateTime: examDateTime,
                    isPrimary: isPrimary,
                    id: UUID().uuidString
                )
                
                return CarouselWidgetData(
                    examList: [examData],
                    currentIndex: 0,
                    totalCount: 1
                )
            }
        }

        // 데이터가 없거나 파싱 실패 시 nil 반환
        NSLog("ExamWidget: 모든 데이터 로드 실패")
        return nil
    }
    
    private func parseCarouselData(jsonString: String, userDefaults: UserDefaults?) -> CarouselWidgetData? {
        NSLog("ExamWidget: JSON 파싱 시작: \(String(jsonString.prefix(200)))")
        
        guard let jsonData = jsonString.data(using: .utf8) else {
            NSLog("ExamWidget: JSON 데이터 변환 실패 - 문자열 길이: \(jsonString.count)")
            return nil
        }
        
        guard let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
            NSLog("ExamWidget: JSON 객체 변환 실패")
            // Try to log the raw JSON string to see what's wrong
            NSLog("ExamWidget: 실패한 JSON 원본: \(jsonString)")
            return nil
        }
        
        NSLog("ExamWidget: JSON 객체 변환 성공, 키들: \(Array(json.keys).joined(separator: ", "))")
        NSLog("ExamWidget: JSON 내용: \(json)")
        
        guard let examListArray = json["examList"] as? [[String: Any]] else {
            NSLog("ExamWidget: examList 배열 추출 실패 - examList 타입: \(String(describing: type(of: json["examList"])))")
            NSLog("ExamWidget: examList 내용: \(String(describing: json["examList"]))")
            return nil
        }
        
        NSLog("ExamWidget: examList 배열 추출 성공: \(examListArray.count)개 항목")
        
        let examList = examListArray.compactMap { examDict -> CarouselExamData? in
            NSLog("ExamWidget: 시험 데이터 파싱 중: \(examDict.keys.joined(separator: ", "))")
            NSLog("ExamWidget: 시험 데이터 전체 내용: \(examDict)")
            
            // Flexible string parsing with type coercion
            guard let university = examDict["university"] as? String ?? (examDict["university"] as? NSNull == nil ? String(describing: examDict["university"] ?? "") : nil),
                  let department = examDict["department"] as? String ?? (examDict["department"] as? NSNull == nil ? String(describing: examDict["department"] ?? "") : nil),
                  let category = examDict["category"] as? String ?? (examDict["category"] as? NSNull == nil ? String(describing: examDict["category"] ?? "") : nil),
                  let examDateTimeString = examDict["examDateTime"] as? String,
                  !university.isEmpty,
                  !department.isEmpty,
                  !examDateTimeString.isEmpty else {
                NSLog("ExamWidget: 필수 필드 누락 또는 비어있음:")
                NSLog("  university: '\(examDict["university"] as? String ?? "nil")' (type: \(String(describing: type(of: examDict["university"]))))")
                NSLog("  department: '\(examDict["department"] as? String ?? "nil")' (type: \(String(describing: type(of: examDict["department"]))))")
                NSLog("  category: '\(examDict["category"] as? String ?? "nil")' (type: \(String(describing: type(of: examDict["category"]))))")
                NSLog("  examDateTime: '\(examDict["examDateTime"] as? String ?? "nil")' (type: \(String(describing: type(of: examDict["examDateTime"]))))")
                return nil
            }
            
            // Handle isPrimary with flexible boolean parsing
            let isPrimary: Bool
            if let boolValue = examDict["isPrimary"] as? Bool {
                isPrimary = boolValue
            } else if let intValue = examDict["isPrimary"] as? Int {
                isPrimary = intValue != 0
            } else if let stringValue = examDict["isPrimary"] as? String {
                isPrimary = stringValue.lowercased() == "true" || stringValue == "1"
            } else {
                NSLog("ExamWidget: isPrimary 파싱 실패: \(String(describing: examDict["isPrimary"])) (type: \(String(describing: type(of: examDict["isPrimary"])))")
                isPrimary = false // Default to false instead of failing
            }
            
            // Handle id as either String, Int, or other types
            let id: String
            if let idString = examDict["id"] as? String {
                id = idString
            } else if let idInt = examDict["id"] as? Int {
                id = String(idInt)
            } else if let idDouble = examDict["id"] as? Double {
                id = String(Int(idDouble))
            } else {
                // Generate a default ID if none provided
                id = UUID().uuidString
                NSLog("ExamWidget: id 필드 파싱 실패, UUID 생성: \(String(describing: examDict["id"])) -> \(id)")
            }
            
            // Parse ISO 8601 date with fallback
            let dateFormatter = ISO8601DateFormatter()
            var examDateTime: Date?
            
            if let primaryDate = dateFormatter.date(from: examDateTimeString) {
                examDateTime = primaryDate
            } else {
                NSLog("ExamWidget: 날짜 파싱 실패: '\(examDateTimeString)'")
                // Try alternative date format
                let fallbackFormatter = DateFormatter()
                fallbackFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS"
                if let fallbackDate = fallbackFormatter.date(from: examDateTimeString) {
                    NSLog("ExamWidget: 대체 날짜 파싱 성공: \(fallbackDate)")
                    examDateTime = fallbackDate
                } else {
                    NSLog("ExamWidget: 모든 날짜 파싱 실패")
                    return nil
                }
            }
            
            NSLog("ExamWidget: 시험 데이터 파싱 성공: \(university) - \(department) (id: \(id), isPrimary: \(isPrimary ? "true" : "false"))")
            
            return CarouselExamData(
                university: university,
                department: department,
                category: category,
                examDateTime: examDateTime!, // examDateTime is guaranteed to be set by now
                isPrimary: isPrimary,
                id: id
            )
        }
        
        // Use persisted index from UserDefaults instead of JSON currentIndex
        let persistedIndex = userDefaults?.integer(forKey: "current_index") ?? 0
        let jsonCurrentIndex = json["currentIndex"] as? Int ?? 0
        let totalCount = json["totalCount"] as? Int ?? examList.count
        
        // Prefer persisted index if it's valid, otherwise fall back to JSON index
        let currentIndex = (persistedIndex < examList.count && persistedIndex >= 0) ? persistedIndex : jsonCurrentIndex
        let validIndex = min(max(0, currentIndex), examList.count - 1)
        
        NSLog("ExamWidget: Index selection - persisted: \(persistedIndex), json: \(jsonCurrentIndex), final: \(validIndex)")
        
        NSLog("ExamWidget: 최종 CarouselWidgetData 생성: \(examList.count)개 시험, 현재 인덱스: \(validIndex)")
        
        if examList.isEmpty {
            NSLog("ExamWidget: 파싱된 시험 목록이 비어있음!")
            return nil
        }
        
        return CarouselWidgetData(
            examList: examList,
            currentIndex: validIndex,
            totalCount: totalCount
        )
    }
    
    private func getCurrentExam(from carouselData: CarouselWidgetData?) -> ExamInfo? {
        guard let data = carouselData,
              !data.examList.isEmpty,
              data.currentIndex < data.examList.count else {
            return nil
        }
        
        return createExamInfo(from: data.examList[data.currentIndex])
    }
    
    private func createExamInfo(from examData: CarouselExamData) -> ExamInfo {
        return ExamInfo(
            university: examData.university,
            department: examData.department,
            examDate: examData.examDateTime,
            isPrimary: examData.isPrimary,
            id: examData.id
        )
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let examInfo: ExamInfo?
    let carouselData: CarouselWidgetData?
}

// MARK: - Carousel Data Models
struct CarouselWidgetData {
    let examList: [CarouselExamData]
    let currentIndex: Int
    let totalCount: Int
}

struct CarouselExamData {
    let university: String
    let department: String
    let category: String
    let examDateTime: Date
    let isPrimary: Bool
    let id: String
}

struct ExamWidgetEntryView : View {
    var entry: Provider.Entry
    @Environment(\.widgetFamily) var family

    // AIM 테마 색상
    private let primaryColor = Color(red: 0.84, green: 0.20, blue: 0.52) // #D63384
    private let textPrimary = Color(red: 0.17, green: 0.24, blue: 0.31) // #2C3E50
    private let textSecondary = Color(red: 0.42, green: 0.46, blue: 0.49) // #6C757D
    private let backgroundColor = Color.white

    var body: some View {
        // Debug logging for the view
        NSLog("ExamWidget: 뷰 렌더링 시작 - 타임스탬프: \(Date())")
        NSLog("ExamWidget: examInfo 존재 여부: \(entry.examInfo != nil ? "true" : "false")")
        NSLog("ExamWidget: carouselData 존재 여부: \(entry.carouselData != nil ? "true" : "false")")
        if let carouselData = entry.carouselData {
            NSLog("ExamWidget: carouselData - \(carouselData.examList.count)개 시험, 현재 인덱스: \(carouselData.currentIndex)")
            NSLog("ExamWidget: Widget Family: \(family)")
        }
        if let examInfo = entry.examInfo {
            NSLog("ExamWidget: 렌더링할 시험: \(examInfo.university) - \(examInfo.department) (id: \(examInfo.id))")
        }
        
        return Group {
            if let examInfo = entry.examInfo {
                switch family {
                case .systemSmall:
                    smallWidgetView(examInfo: examInfo)
                case .systemMedium:
                    mediumWidgetView(examInfo: examInfo)
                case .accessoryCircular:
                    accessoryCircularView(examInfo: examInfo)
                case .accessoryRectangular:
                    accessoryRectangularView(examInfo: examInfo)
                case .accessoryInline:
                    accessoryInlineView(examInfo: examInfo)
                default:
                    smallWidgetView(examInfo: examInfo)
                }
            } else {
                emptyStateView()
            }
        }
    }


@ViewBuilder
private func accessoryCircularView(examInfo: ExamInfo) -> some View {
    ZStack {
        Circle()
            .stroke(examInfo.dDayColor, lineWidth: 2)

        Text(examInfo.dDayText) // 예: "D-99"
            .font(.system(size: 16, weight: .bold, design: .rounded))
            .foregroundColor(examInfo.dDayColor)
    }
}

@ViewBuilder
private func accessoryRectangularView(examInfo: ExamInfo) -> some View {
    VStack(alignment: .leading, spacing: 2) {
        // 학교 + 학과 한 줄에
        Text("\(examInfo.university) \(examInfo.department)")
            .font(.caption2)
            .foregroundColor(textSecondary)
            .lineLimit(1)

        // D-Day 강조
        Text(examInfo.dDayText)
            .font(.system(size: 22, weight: .heavy, design: .rounded)) // ← 더 큼 + 굵게
            .foregroundColor(examInfo.dDayColor)
            .padding(.top, 2)
    }
    .frame(maxWidth: .infinity, alignment: .leading) // ← 왼쪽 정렬
}

@ViewBuilder
private func accessoryInlineView(examInfo: ExamInfo) -> some View {
    Text("논술까지 \(examInfo.dDayText)")
        .font(.caption2)
        .foregroundColor(examInfo.dDayColor)
}

    // 작은 위젯 (systemSmall)
    private func smallWidgetView(examInfo: ExamInfo) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // D-Day (왼쪽 상단, 가장 강조)
            HStack {
                Text(examInfo.dDayText)
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .foregroundColor(examInfo.dDayColor)
                Spacer()
                if examInfo.isPrimary {
                    Image(systemName: "star.fill")
                        .font(.system(size: 12))
                        .foregroundColor(Color.yellow)
                }
            }
            .padding(.bottom, 6)

            Spacer()

            // 학교명
            Text(examInfo.university)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            // 학과명
            Text(examInfo.department)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(textSecondary)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
                .padding(.bottom, 4)

            // 시험일, 페이지 인디케이터 및 네비게이션 버튼
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(examInfo.formattedDate)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(textSecondary)
                    
                    // Page indicator for multiple exams
                    if let carouselData = entry.carouselData, carouselData.examList.count > 1 {
                        createPageIndicator(currentIndex: carouselData.currentIndex, totalCount: carouselData.totalCount)
                            .font(.system(size: 8))
                    }
                }
                
                Spacer()
                
                // Navigation buttons (iOS 17+)
                if #available(iOS 17.0, *), let carouselData = entry.carouselData, carouselData.examList.count > 1 {
                    HStack(spacing: 4) {
                        // Previous button
                        Button(intent: NavigatePreviousIntent()) {
                            Image(systemName: "chevron.left.circle.fill")
                                .font(.system(size: 18))
                                .foregroundColor(primaryColor)
                        }
                        .buttonStyle(.plain)
                        .frame(width: 24, height: 24)
                        .contentShape(Rectangle())
                        
                        // Next button
                        Button(intent: NavigateNextIntent()) {
                            Image(systemName: "chevron.right.circle.fill")
                                .font(.system(size: 18))
                                .foregroundColor(primaryColor)
                        }
                        .buttonStyle(.plain)
                        .frame(width: 24, height: 24)
                        .contentShape(Rectangle())
                    }
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(backgroundColor)
    }

    // 넓은 위젯 (systemMedium)
    private func mediumWidgetView(examInfo: ExamInfo) -> some View {
        HStack(spacing: 0) {
            // Main content area
            VStack(alignment: .leading, spacing: 0) {
                // D-Day (왼쪽 상단, 가장 강조)
                HStack {
                    Text(examInfo.dDayText)
                        .font(.system(size: 32, weight: .black, design: .rounded))
                        .foregroundColor(examInfo.dDayColor)

                    Spacer()

                    if examInfo.isPrimary {
                        Image(systemName: "star.fill")
                            .font(.system(size: 16))
                            .foregroundColor(Color.yellow)
                    }
                }
                .padding(.bottom, 8)

                Spacer()

                // 학교, 학과 (한 줄에 배치)
                HStack(spacing: 0) {
                    Text(examInfo.university)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(textPrimary)
                        .lineLimit(1)

                    Text("·")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(textSecondary)

                    Text(examInfo.department)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(textSecondary)
                        .lineLimit(1)

                    Spacer()
                }
                .minimumScaleFactor(0.8)

                // 시험일 및 페이지 인디케이터
                VStack(alignment: .leading, spacing: 4) {
                    Text(examInfo.formattedDate)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(textSecondary)
                    
                    // Page indicator for multiple exams
                    if let carouselData = entry.carouselData, carouselData.examList.count > 1 {
                        createPageIndicator(currentIndex: carouselData.currentIndex, totalCount: carouselData.totalCount)
                            .font(.system(size: 10))
                    }
                }
            }
            .padding(.leading, 16)
            .padding(.vertical, 12)
            
            // Navigation buttons area (iOS 17+)
            if #available(iOS 17.0, *), let carouselData = entry.carouselData, carouselData.examList.count > 1 {
                VStack(spacing: 8) {
                    Spacer()
                    
                    // Previous button
                    Button(intent: NavigatePreviousIntent()) {
                        Image(systemName: "chevron.left.circle.fill")
                            .font(.system(size: 26))
                            .foregroundColor(primaryColor)
                    }
                    .buttonStyle(.plain)
                    .frame(width: 32, height: 32)
                    .contentShape(Rectangle())
                    
                    // Next button
                    Button(intent: NavigateNextIntent()) {
                        Image(systemName: "chevron.right.circle.fill")
                            .font(.system(size: 26))
                            .foregroundColor(primaryColor)
                    }
                    .buttonStyle(.plain)
                    .frame(width: 32, height: 32)
                    .contentShape(Rectangle())
                    
                    Spacer()
                }
                .padding(.trailing, 12)
                .padding(.vertical, 8)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(backgroundColor)
    }

    // 빈 상태
    private func emptyStateView() -> some View {
        VStack(spacing: 8) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 24))
                .foregroundColor(primaryColor)

            Text("AIM 논술")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(primaryColor)

            Text("모집단위를 추가해주세요")
                .font(.system(size: 12))
                .foregroundColor(textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(backgroundColor)
    }
    
    // MARK: - Helper Functions
    @ViewBuilder
    private func createPageIndicator(currentIndex: Int, totalCount: Int) -> some View {
        HStack(spacing: 4) {
            ForEach(0..<min(totalCount, 8), id: \.self) { index in
                Circle()
                    .fill(index == currentIndex ? primaryColor : textSecondary.opacity(0.3))
                    .frame(width: index == currentIndex ? 8 : 6, height: index == currentIndex ? 8 : 6)
            }
            
            if totalCount > 8 {
                Text("⋯")
                    .font(.system(size: 8))
                    .foregroundColor(textSecondary.opacity(0.5))
            }
        }
    }
}

struct ExamWidget: Widget {
    let kind: String = "ExamWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            if #available(iOS 17.0, *) {
                ExamWidgetEntryView(entry: entry)
                    .containerBackground(.fill.tertiary, for: .widget)
            } else {
                ExamWidgetEntryView(entry: entry)
                    .padding()
                    .background()
            }
        }
        .contentMarginsDisabled()
        .configurationDisplayName("AIM 논술 D-Day")
        .description("대표 모집단위의 시험 일정과 D-Day를 확인하세요.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular,
  .accessoryRectangular, .accessoryInline])
    }
}

@available(iOS 17.0, *)
#Preview(as: .systemSmall) {
    ExamWidget()
} timeline: {
    let sampleExam = ExamInfo(
        university: "서울대학교",
        department: "인문대학 국어국문학과",
        examDate: Calendar.current.date(byAdding: .day, value: 15, to: Date()) ?? Date(),
        isPrimary: true,
        id: "preview-exam-1"
    )
    let carouselData = CarouselWidgetData(
        examList: [
            CarouselExamData(university: "서울대학교", department: "인문대학 국어국문학과", category: "논술", examDateTime: Calendar.current.date(byAdding: .day, value: 15, to: Date()) ?? Date(), isPrimary: true, id: "1"),
            CarouselExamData(university: "연세대학교", department: "경영학과", category: "논술", examDateTime: Calendar.current.date(byAdding: .day, value: 20, to: Date()) ?? Date(), isPrimary: false, id: "2")
        ],
        currentIndex: 0,
        totalCount: 2
    )
    SimpleEntry(date: .now, examInfo: sampleExam, carouselData: carouselData)
}

@available(iOS 17.0, *)
#Preview(as: .systemMedium) {
    ExamWidget()
} timeline: {
    let sampleExam = ExamInfo(
        university: "서울대학교",
        department: "인문대학 국어국문학과",
        examDate: Calendar.current.date(byAdding: .day, value: 15, to: Date()) ?? Date(),
        isPrimary: true,
        id: "preview-exam-1"
    )
    let carouselData = CarouselWidgetData(
        examList: [
            CarouselExamData(university: "서울대학교", department: "인문대학 국어국문학과", category: "논술", examDateTime: Calendar.current.date(byAdding: .day, value: 15, to: Date()) ?? Date(), isPrimary: true, id: "1"),
            CarouselExamData(university: "연세대학교", department: "경영학과", category: "논술", examDateTime: Calendar.current.date(byAdding: .day, value: 20, to: Date()) ?? Date(), isPrimary: false, id: "2")
        ],
        currentIndex: 0,
        totalCount: 2
    )
    SimpleEntry(date: .now, examInfo: sampleExam, carouselData: carouselData)
}