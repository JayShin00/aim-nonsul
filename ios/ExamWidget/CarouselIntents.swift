//
//  CarouselIntents.swift
//  ExamWidget
//
//  Created by Claude Code
//

import AppIntents
import WidgetKit
import Foundation

// MARK: - Navigation Intents
@available(iOS 17.0, *)
struct NavigateNextIntent: AppIntent {
    static var title: LocalizedStringResource = "Next Exam"
    static var description = IntentDescription("Navigate to the next exam in the carousel")
    
    func perform() async throws -> some IntentResult {
        // Update carousel index
        let userDefaults = UserDefaults(suiteName: "group.com.aim.aimNonsul")
        let carouselData = loadCarouselData(from: userDefaults)
        
        if let data = carouselData, !data.examList.isEmpty {
            let currentIndex = data.currentIndex
            let nextIndex = (currentIndex + 1) % data.examList.count
            
            // Save new index
            userDefaults?.set(nextIndex, forKey: "current_index")
            
            // Update traditional widget data for compatibility
            if nextIndex < data.examList.count {
                let exam = data.examList[nextIndex]
                saveExamData(exam: exam, to: userDefaults)
            }
        }
        
        // Reload widget timelines
        WidgetCenter.shared.reloadTimelines(ofKind: "ExamWidget")
        
        return .result()
    }
}

@available(iOS 17.0, *)
struct NavigatePreviousIntent: AppIntent {
    static var title: LocalizedStringResource = "Previous Exam"
    static var description = IntentDescription("Navigate to the previous exam in the carousel")
    
    func perform() async throws -> some IntentResult {
        // Update carousel index
        let userDefaults = UserDefaults(suiteName: "group.com.aim.aimNonsul")
        let carouselData = loadCarouselData(from: userDefaults)
        
        if let data = carouselData, !data.examList.isEmpty {
            let currentIndex = data.currentIndex
            let previousIndex = currentIndex == 0 ? data.examList.count - 1 : currentIndex - 1
            
            // Save new index
            userDefaults?.set(previousIndex, forKey: "current_index")
            
            // Update traditional widget data for compatibility
            if previousIndex < data.examList.count {
                let exam = data.examList[previousIndex]
                saveExamData(exam: exam, to: userDefaults)
            }
        }
        
        // Reload widget timelines
        WidgetCenter.shared.reloadTimelines(ofKind: "ExamWidget")
        
        return .result()
    }
}

// MARK: - Data Models
struct CarouselData {
    let examList: [ExamData]
    let currentIndex: Int
    let totalCount: Int
}

struct ExamData {
    let university: String
    let department: String
    let category: String
    let examDateTime: Date
    let isPrimary: Bool
    let id: String
}

// MARK: - Helper Functions
func loadCarouselData(from userDefaults: UserDefaults?) -> CarouselData? {
    guard let carouselJsonString = userDefaults?.string(forKey: "flutter.carousel_data") ?? userDefaults?.string(forKey: "carousel_data"),
          let carouselJsonData = carouselJsonString.data(using: .utf8),
          let carouselJson = try? JSONSerialization.jsonObject(with: carouselJsonData) as? [String: Any] else {
        return nil
    }
    
    guard let examListArray = carouselJson["examList"] as? [[String: Any]] else {
        return nil
    }
    
    let examList = examListArray.compactMap { examDict -> ExamData? in
        guard let university = examDict["university"] as? String,
              let department = examDict["department"] as? String,
              let category = examDict["category"] as? String,
              let examDateTimeString = examDict["examDateTime"] as? String,
              let isPrimary = examDict["isPrimary"] as? Bool,
              let id = examDict["id"] as? String else {
            return nil
        }
        
        // Parse ISO 8601 date
        let dateFormatter = ISO8601DateFormatter()
        guard let examDateTime = dateFormatter.date(from: examDateTimeString) else {
            return nil
        }
        
        return ExamData(
            university: university,
            department: department,
            category: category,
            examDateTime: examDateTime,
            isPrimary: isPrimary,
            id: id
        )
    }
    
    let currentIndex = userDefaults?.integer(forKey: "current_index") ?? 0
    let validIndex = min(max(0, currentIndex), examList.count - 1)
    
    return CarouselData(
        examList: examList,
        currentIndex: validIndex,
        totalCount: examList.count
    )
}

func saveExamData(exam: ExamData, to userDefaults: UserDefaults?) {
    let dateFormat = DateFormatter()
    dateFormat.dateFormat = "yyyy-MM-dd"
    let timeFormat = DateFormatter()
    timeFormat.dateFormat = "HH:mm"
    
    let examDate = dateFormat.string(from: exam.examDateTime)
    let examTime = timeFormat.string(from: exam.examDateTime)
    
    userDefaults?.set(exam.isPrimary ? "⭐ \(exam.department)" : exam.department, forKey: "exam_title")
    userDefaults?.set(exam.university, forKey: "exam_university")
    userDefaults?.set(examDate, forKey: "exam_date")
    userDefaults?.set(examTime, forKey: "exam_time")
}