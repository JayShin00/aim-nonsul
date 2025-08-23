//
//  ExamWidget.swift
//  ExamWidget
//
//  Created by Hyun Jaeyeon on 7/5/25.
//

import WidgetKit
import SwiftUI
import AppIntents

// Carousel Navigation Intent (iOS 17+)
@available(iOS 17, *)
struct CarouselNavigationIntent: AppIntent {
    static var title: LocalizedStringResource = "Navigate Carousel"
    
    @Parameter(title: "Direction")
    var direction: String
    
    init() {
        self.direction = "next"
    }
    
    init(direction: String) {
        self.direction = direction
    }
    
    func perform() async throws -> some IntentResult {
        // iOS 위젯에서 UserDefaults를 통해 인덱스 업데이트
        if let userDefaults = UserDefaults(suiteName: "group.com.aim.aimNonsul") {
            let currentIndex = userDefaults.integer(forKey: "carousel_index")
            let totalCount = userDefaults.integer(forKey: "total_count")
            
            if totalCount > 0 {
                var nextIndex = currentIndex
                if direction == "next" {
                    nextIndex = (currentIndex + 1) % totalCount
                } else if direction == "previous" {
                    nextIndex = currentIndex == 0 ? totalCount - 1 : currentIndex - 1
                }
                
                userDefaults.set(nextIndex, forKey: "carousel_index")
                userDefaults.synchronize()
            }
        }
        
        return .result()
    }
}

// Carousel 데이터 구조
struct CarouselData {
    let examList: [ExamInfo]
    let currentIndex: Int
    let totalCount: Int
    
    static func fromUserDefaults() -> CarouselData? {
        guard let userDefaults = UserDefaults(suiteName: "group.com.aim.aimNonsul"),
              let carouselDataString = userDefaults.string(forKey: "carousel_data"),
              !carouselDataString.isEmpty,
              let data = carouselDataString.data(using: .utf8) else {
            return nil
        }
        
        do {
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let examListJson = json["examList"] as? [[String: Any]] {
                
                let examList = examListJson.compactMap { examJson -> ExamInfo? in
                    guard let university = examJson["university"] as? String,
                          let department = examJson["department"] as? String,
                          let dateString = examJson["examDateTime"] as? String,
                          let isPrimary = examJson["isPrimary"] as? Bool else {
                        return nil
                    }
                    
                    let formatter = ISO8601DateFormatter()
                    guard let examDate = formatter.date(from: dateString) else {
                        return nil
                    }
                    
                    return ExamInfo(
                        university: university,
                        department: department,
                        examDate: examDate,
                        isPrimary: isPrimary
                    )
                }
                
                let currentIndex = json["currentIndex"] as? Int ?? 0
                let totalCount = json["totalCount"] as? Int ?? examList.count
                
                return CarouselData(
                    examList: examList,
                    currentIndex: currentIndex,
                    totalCount: totalCount
                )
            }
        } catch {
            print("Failed to parse carousel data: \(error)")
        }
        
        return nil
    }
}

// 시험 정보 데이터 구조
struct ExamInfo {
    let university: String
    let department: String
    let examDate: Date
    let isPrimary: Bool
    
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
            isPrimary: true
        )
        return SimpleEntry(date: Date(), examInfo: sampleExam, carouselData: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        let carouselData = loadCarouselData()
        let examInfo = getCurrentExam(from: carouselData)
        let entry = SimpleEntry(date: Date(), examInfo: examInfo, carouselData: carouselData)
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        let currentDate = Date()
        let carouselData = loadCarouselData()
        let examInfo = getCurrentExam(from: carouselData)
        
        // 매 시간마다 업데이트하여 D-Day 계산을 정확하게 유지
        var entries: [SimpleEntry] = []
        for hourOffset in 0..<24 {
            let entryDate = Calendar.current.date(byAdding: .hour, value: hourOffset, to: currentDate)!
            let entry = SimpleEntry(date: entryDate, examInfo: examInfo, carouselData: carouselData)
            entries.append(entry)
        }
        
        // 하루 후에 다시 업데이트
        let nextUpdate = Calendar.current.date(byAdding: .day, value: 1, to: currentDate)!
        let timeline = Timeline(entries: entries, policy: .after(nextUpdate))
        completion(timeline)
    }
    
    private func loadCarouselData() -> CarouselData? {
        return CarouselData.fromUserDefaults()
    }
    
    private func getCurrentExam(from carouselData: CarouselData?) -> ExamInfo? {
        guard let carouselData = carouselData,
              carouselData.currentIndex < carouselData.examList.count else {
            return loadPrimaryExam() // fallback to old method
        }
        
        return carouselData.examList[carouselData.currentIndex]
    }
    
    private func loadPrimaryExam() -> ExamInfo? {
        // UserDefaults에서 home_widget 데이터 로드
        let userDefaults = UserDefaults(suiteName: "group.com.aim.aimNonsul")
        
        // home_widget에서 저장한 데이터 읽기
        if let examTitle = userDefaults?.string(forKey: "exam_title"),
           let examUniversity = userDefaults?.string(forKey: "exam_university"),
           let examDate = userDefaults?.string(forKey: "exam_date"),
           let examTime = userDefaults?.string(forKey: "exam_time"),
           !examTitle.isEmpty,
           !examDate.isEmpty {
            
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
                
                return ExamInfo(
                    university: examUniversity,
                    department: cleanTitle,
                    examDate: examDateTime,
                    isPrimary: isPrimary
                )
            }
        }
        
        // 데이터가 없거나 파싱 실패 시 nil 반환
        return nil
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let examInfo: ExamInfo?
    let carouselData: CarouselData?
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
            // D-Day와 네비게이션 (상단)
            HStack {
                Text(examInfo.dDayText)
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .foregroundColor(examInfo.dDayColor)
                Spacer()
                
                // 네비게이션 버튼들 (iOS 17+)
                if #available(iOS 17.0, *), let carouselData = entry.carouselData, carouselData.totalCount > 1 {
                    HStack(spacing: 6) {
                        Button(intent: CarouselNavigationIntent(direction: "previous")) {
                            Image(systemName: "chevron.left.circle.fill")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(primaryColor)
                                .background(
                                    Circle()
                                        .fill(Color.white)
                                        .frame(width: 24, height: 24)
                                        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                                )
                        }
                        .buttonStyle(.plain)
                        
                        Button(intent: CarouselNavigationIntent(direction: "next")) {
                            Image(systemName: "chevron.right.circle.fill")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(primaryColor)
                                .background(
                                    Circle()
                                        .fill(Color.white)
                                        .frame(width: 24, height: 24)
                                        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                } else if examInfo.isPrimary {
                    Image(systemName: "star.fill")
                        .font(.system(size: 12))
                        .foregroundColor(Color.yellow)
                }
            }
            .padding(.bottom, 6)
            
            // Dot indicator (if multiple exams)
            if let carouselData = entry.carouselData, carouselData.totalCount > 1 {
                HStack(spacing: 4) {
                    ForEach(0..<carouselData.totalCount, id: \.self) { index in
                        Circle()
                            .fill(index == carouselData.currentIndex ? primaryColor : textSecondary.opacity(0.3))
                            .frame(width: 4, height: 4)
                    }
                }
                .padding(.bottom, 6)
            }
            
            Spacer()
            
            // 학교명
            Text(examInfo.university)
                .font(.system(size: 14, weight: .semibold))
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
            
            // 시험일
            Text(examInfo.formattedDate)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(textSecondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(backgroundColor)
    }
    
    // 넓은 위젯 (systemMedium)
    private func mediumWidgetView(examInfo: ExamInfo) -> some View {
        HStack(spacing: 16) {
            // 왼쪽: 메인 콘텐츠
            VStack(alignment: .leading, spacing: 0) {
                // D-Day
                Text(examInfo.dDayText)
                    .font(.system(size: 32, weight: .black, design: .rounded))
                    .foregroundColor(examInfo.dDayColor)
                    .padding(.bottom, 8)
                
                Spacer()
                
                // 학교명
                Text(examInfo.university)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(textPrimary)
                    .lineLimit(1)
                
                // 학과명
                Text(examInfo.department)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(textSecondary)
                    .lineLimit(1)
                    .padding(.bottom, 4)
                
                // 시험일
                Text(examInfo.formattedDate)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(textSecondary)
            }
            
            Spacer()
            
            // 오른쪽: 네비게이션 및 지표
            VStack(spacing: 8) {
                // Dot indicator
                if let carouselData = entry.carouselData, carouselData.totalCount > 1 {
                    HStack(spacing: 4) {
                        ForEach(0..<carouselData.totalCount, id: \.self) { index in
                            Circle()
                                .fill(index == carouselData.currentIndex ? primaryColor : textSecondary.opacity(0.3))
                                .frame(width: 5, height: 5)
                        }
                    }
                } else if examInfo.isPrimary {
                    Image(systemName: "star.fill")
                        .font(.system(size: 16))
                        .foregroundColor(Color.yellow)
                }
                
                Spacer()
                
                // 네비게이션 버튼들 (iOS 17+)
                if #available(iOS 17.0, *), let carouselData = entry.carouselData, carouselData.totalCount > 1 {
                    VStack(spacing: 8) {
                        Button(intent: CarouselNavigationIntent(direction: "previous")) {
                            Image(systemName: "chevron.up.circle.fill")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundColor(primaryColor)
                                .background(
                                    Circle()
                                        .fill(Color.white)
                                        .frame(width: 36, height: 36)
                                        .shadow(color: .black.opacity(0.12), radius: 3, x: 0, y: 2)
                                )
                        }
                        .buttonStyle(.plain)
                        
                        Button(intent: CarouselNavigationIntent(direction: "next")) {
                            Image(systemName: "chevron.down.circle.fill")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundColor(primaryColor)
                                .background(
                                    Circle()
                                        .fill(Color.white)
                                        .frame(width: 36, height: 36)
                                        .shadow(color: .black.opacity(0.12), radius: 3, x: 0, y: 2)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(16)
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
        isPrimary: true
    )
    let sampleCarousel = CarouselData(
        examList: [sampleExam],
        currentIndex: 0,
        totalCount: 3
    )
    SimpleEntry(date: .now, examInfo: sampleExam, carouselData: sampleCarousel)
}

@available(iOS 17.0, *)
#Preview(as: .systemMedium) {
    ExamWidget()
} timeline: {
    let sampleExam = ExamInfo(
        university: "서울대학교",
        department: "인문대학 국어국문학과",
        examDate: Calendar.current.date(byAdding: .day, value: 15, to: Date()) ?? Date(),
        isPrimary: true
    )
    let sampleCarousel = CarouselData(
        examList: [sampleExam],
        currentIndex: 0,
        totalCount: 3
    )
    SimpleEntry(date: .now, examInfo: sampleExam, carouselData: sampleCarousel)
}
