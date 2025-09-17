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
        NSLog("NavigateNextIntent: Started execution")
        
        // Update carousel index
        let userDefaults = UserDefaults(suiteName: "group.com.aim.aimNonsul.ExamWidget")
        let carouselData = loadCarouselData(from: userDefaults)
        
        if let data = carouselData, !data.examList.isEmpty {
            let currentIndex = data.currentIndex
            let nextIndex = (currentIndex + 1) % data.examList.count
            
            NSLog("NavigateNextIntent: Moving from index \(currentIndex) to \(nextIndex) out of \(data.examList.count) exams")
            
            // Save new index
            userDefaults?.set(nextIndex, forKey: "current_index")
            
            // Update traditional widget data for compatibility
            if nextIndex < data.examList.count {
                let exam = data.examList[nextIndex]
                saveExamData(exam: exam, to: userDefaults)
                NSLog("NavigateNextIntent: Updated traditional widget data for \(exam.university) - \(exam.department)")
            }
        } else {
            NSLog("NavigateNextIntent: No carousel data available or empty exam list")
        }
        
        // Force immediate widget update and reload timelines
        WidgetCenter.shared.reloadTimelines(ofKind: "ExamWidget")
        
        // Also trigger an immediate snapshot update for faster response
        WidgetCenter.shared.reloadAllTimelines()
        NSLog("NavigateNextIntent: Triggered widget timeline reload and forced refresh")
        
        return .result()
    }
}

@available(iOS 17.0, *)
struct NavigatePreviousIntent: AppIntent {
    static var title: LocalizedStringResource = "Previous Exam"
    static var description = IntentDescription("Navigate to the previous exam in the carousel")
    
    func perform() async throws -> some IntentResult {
        NSLog("NavigatePreviousIntent: Started execution")
        
        // Update carousel index
        let userDefaults = UserDefaults(suiteName: "group.com.aim.aimNonsul.ExamWidget")
        let carouselData = loadCarouselData(from: userDefaults)
        
        if let data = carouselData, !data.examList.isEmpty {
            let currentIndex = data.currentIndex
            let previousIndex = currentIndex == 0 ? data.examList.count - 1 : currentIndex - 1
            
            NSLog("NavigatePreviousIntent: Moving from index \(currentIndex) to \(previousIndex) out of \(data.examList.count) exams")
            
            // Save new index
            userDefaults?.set(previousIndex, forKey: "current_index")
            
            // Update traditional widget data for compatibility
            if previousIndex < data.examList.count {
                let exam = data.examList[previousIndex]
                saveExamData(exam: exam, to: userDefaults)
                NSLog("NavigatePreviousIntent: Updated traditional widget data for \(exam.university) - \(exam.department)")
            }
        } else {
            NSLog("NavigatePreviousIntent: No carousel data available or empty exam list")
        }
        
        // Force immediate widget update and reload timelines
        WidgetCenter.shared.reloadTimelines(ofKind: "ExamWidget")
        
        // Also trigger an immediate snapshot update for faster response
        WidgetCenter.shared.reloadAllTimelines()
        NSLog("NavigatePreviousIntent: Triggered widget timeline reload and forced refresh")
        
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
    // Check both possible keys: with and without flutter prefix
    var carouselJsonString: String?
    if let jsonString = userDefaults?.string(forKey: "carousel_data") {
        carouselJsonString = jsonString
        NSLog("CarouselIntents: Found carousel_data without prefix")
    } else if let jsonString = userDefaults?.string(forKey: "flutter.carousel_data") {
        carouselJsonString = jsonString
        NSLog("CarouselIntents: Found carousel_data with flutter prefix")
    } else {
        NSLog("CarouselIntents: No carousel data found for either key")
        return nil
    }
    
    guard let jsonString = carouselJsonString,
          let carouselJsonData = jsonString.data(using: .utf8),
          let carouselJson = try? JSONSerialization.jsonObject(with: carouselJsonData) as? [String: Any] else {
        NSLog("CarouselIntents: Failed to parse carousel JSON data")
        return nil
    }
    
    guard let examListArray = carouselJson["examList"] as? [[String: Any]] else {
        return nil
    }
    
    let examList = examListArray.compactMap { examDict -> ExamData? in
        NSLog("CarouselIntents: Parsing exam: \(examDict)")
        
        // Flexible string parsing with type coercion (same as main widget)
        guard let university = examDict["university"] as? String ?? (examDict["university"] as? NSNull == nil ? String(describing: examDict["university"] ?? "") : nil),
              let department = examDict["department"] as? String ?? (examDict["department"] as? NSNull == nil ? String(describing: examDict["department"] ?? "") : nil),
              let category = examDict["category"] as? String ?? (examDict["category"] as? NSNull == nil ? String(describing: examDict["category"] ?? "") : nil),
              let examDateTimeString = examDict["examDateTime"] as? String,
              !university.isEmpty,
              !department.isEmpty,
              !examDateTimeString.isEmpty else {
            NSLog("CarouselIntents: Failed to parse exam data - missing or empty required fields")
            return nil
        }
        
        // Handle isPrimary with flexible boolean parsing (same as main widget)
        let isPrimary: Bool
        if let boolValue = examDict["isPrimary"] as? Bool {
            isPrimary = boolValue
        } else if let intValue = examDict["isPrimary"] as? Int {
            isPrimary = intValue != 0
        } else if let stringValue = examDict["isPrimary"] as? String {
            isPrimary = stringValue.lowercased() == "true" || stringValue == "1"
        } else {
            isPrimary = false
        }
        
        // Handle id as either String, Int, or other types (same as main widget)
        let id: String
        if let idString = examDict["id"] as? String {
            id = idString
        } else if let idInt = examDict["id"] as? Int {
            id = String(idInt)
        } else if let idDouble = examDict["id"] as? Double {
            id = String(Int(idDouble))
        } else {
            id = UUID().uuidString
            NSLog("CarouselIntents: Generated UUID for missing id: \(id)")
        }
        
        // Parse ISO 8601 date with fallback
        let dateFormatter = ISO8601DateFormatter()
        var examDateTime: Date?
        
        if let primaryDate = dateFormatter.date(from: examDateTimeString) {
            examDateTime = primaryDate
        } else {
            // Try alternative date format
            let fallbackFormatter = DateFormatter()
            fallbackFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS"
            if let fallbackDate = fallbackFormatter.date(from: examDateTimeString) {
                examDateTime = fallbackDate
            } else {
                NSLog("CarouselIntents: Failed to parse date: \(examDateTimeString)")
                return nil
            }
        }
        
        NSLog("CarouselIntents: Successfully parsed exam: \(university) - \(department)")
        return ExamData(
            university: university,
            department: department,
            category: category,
            examDateTime: examDateTime!,
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