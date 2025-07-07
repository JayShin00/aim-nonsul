//
//  ExamWidget.swift
//  ExamWidget
//
//  Created by Hyun Jaeyeon on 7/5/25.
//

import WidgetKit
import SwiftUI

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
        let difference = calendar.dateComponents([.day], from: today, to: examDay).day ?? 0
        
        if difference == 0 {
            return "D-Day"
        } else if difference > 0 {
            return "D-\(difference)"
        } else {
            return "종료"
        }
    }
    
    var dDayColor: Color {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let examDay = calendar.startOfDay(for: examDate)
        let difference = calendar.dateComponents([.day], from: today, to: examDay).day ?? 0
        
        if difference == 0 {
            return Color(red: 0.86, green: 0.21, blue: 0.27) // errorColor
        } else if difference < 0 {
            return Color(red: 0.56, green: 0.60, blue: 0.69) // textLight
        } else if difference <= 7 {
            return Color(red: 0.86, green: 0.21, blue: 0.27) // errorColor
        } else if difference <= 30 {
            return Color(red: 1.0, green: 0.76, blue: 0.03) // warningColor
        } else {
            return Color(red: 0.84, green: 0.20, blue: 0.52) // primaryColor
        }
    }
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        let sampleExam = ExamInfo(
            university: "서울대학교",
            department: "인문대학 국어국문학과",
            examDate: Calendar.current.date(byAdding: .day, value: 15, to: Date()) ?? Date(),
            isPrimary: true
        )
        return SimpleEntry(date: Date(), examInfo: sampleExam)
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        let examInfo = loadPrimaryExam()
        let entry = SimpleEntry(date: Date(), examInfo: examInfo)
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        let currentDate = Date()
        let examInfo = loadPrimaryExam()
        
        // 매 시간마다 업데이트하여 D-Day 계산을 정확하게 유지
        var entries: [SimpleEntry] = []
        for hourOffset in 0..<24 {
            let entryDate = Calendar.current.date(byAdding: .hour, value: hourOffset, to: currentDate)!
            let entry = SimpleEntry(date: entryDate, examInfo: examInfo)
            entries.append(entry)
        }
        
        // 하루 후에 다시 업데이트
        let nextUpdate = Calendar.current.date(byAdding: .day, value: 1, to: currentDate)!
        let timeline = Timeline(entries: entries, policy: .after(nextUpdate))
        completion(timeline)
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
}

struct ExamWidgetEntryView : View {
    var entry: Provider.Entry
    
    // AIM 테마 색상
    private let primaryColor = Color(red: 0.84, green: 0.20, blue: 0.52) // #D63384
    private let textPrimary = Color(red: 0.17, green: 0.24, blue: 0.31) // #2C3E50
    private let textSecondary = Color(red: 0.42, green: 0.46, blue: 0.49) // #6C757D
    private let backgroundColor = Color.white
    
    var body: some View {
        if let examInfo = entry.examInfo {
            VStack(alignment: .leading, spacing: 0) {                
                // 대학명
                Text(examInfo.university)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(textSecondary)
                    .lineLimit(1)
                
                // 학과명
                Text(examInfo.department)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(textPrimary)
                    .lineLimit(2)
                    .padding(.bottom, 8)
                
                // 시험일자와 D-Day
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("시험일")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(textSecondary)
                        
                        Text(examInfo.examDate, style: .date)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(textPrimary)
                    }
                    
                    Spacer()
                    
                    // D-Day 뱃지
                    Text(examInfo.dDayText)
                        .font(.system(size: 16, weight: .black))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(examInfo.dDayColor)
                        .cornerRadius(12)
                }
            }
            .padding(16)
            .background(backgroundColor)
            .cornerRadius(16)
        } else {
            // 데이터가 없을 때
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
            .background(backgroundColor)
            .cornerRadius(16)
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
        .supportedFamilies([.systemSmall, .systemMedium])
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
    SimpleEntry(date: .now, examInfo: sampleExam)
}
