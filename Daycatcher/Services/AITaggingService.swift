import Foundation
import Vision
import UIKit
import CoreData
import NaturalLanguage

/// Service for AI-powered auto-tagging of memories using Vision and NaturalLanguage frameworks
@MainActor
class AITaggingService: ObservableObject {
    static let shared = AITaggingService()

    @Published var isProcessing = false

    // Minimum confidence threshold for tags
    private let confidenceThreshold: Float = 0.5

    private init() {}

    // MARK: - Main Tagging Entry Point

    /// Analyze a memory and generate appropriate tags
    /// - Parameters:
    ///   - memory: The memory to tag
    ///   - image: Optional UIImage for photo/video memories
    ///   - context: Core Data context for saving tags
    func tagMemory(_ memory: Memory, image: UIImage? = nil, in context: NSManagedObjectContext) async {
        isProcessing = true
        defer { isProcessing = false }

        var suggestedTags: Set<String> = []

        // 1. Image-based tags (for photos and videos)
        if let image = image {
            let imageTags = await analyzeImage(image)
            suggestedTags.formUnion(imageTags)
        }

        // 2. Text-based tags (from notes, title, extracted text)
        let textContent = buildTextContent(from: memory)
        if !textContent.isEmpty {
            let textTags = analyzeText(textContent)
            suggestedTags.formUnion(textTags)
        }

        // 3. Age stage tag (based on loved one's birth date)
        if let ageTag = getAgeStageTag(for: memory) {
            suggestedTags.insert(ageTag)
        }

        // 4. Season tag
        if let seasonTag = getSeasonTag(for: memory) {
            suggestedTags.insert(seasonTag)
        }

        // 5. Time of day tag
        if let timeTag = getTimeOfDayTag(for: memory) {
            suggestedTags.insert(timeTag)
        }

        // 6. Memory type tag
        suggestedTags.insert(memory.memoryType.displayName)

        // Apply tags to memory
        await applyTags(suggestedTags, to: memory, in: context)
    }

    // MARK: - Image Analysis

    /// Analyze an image using Vision framework
    private func analyzeImage(_ image: UIImage) async -> Set<String> {
        var tags: Set<String> = []

        guard let cgImage = image.cgImage else { return tags }

        // Run classification
        let classificationTags = await performImageClassification(cgImage)
        tags.formUnion(classificationTags)

        // Detect faces (for "people" tag)
        let hasFaces = await detectFaces(cgImage)
        if hasFaces {
            tags.insert("People")
        }

        // Detect text in image
        let hasText = await detectText(cgImage)
        if hasText {
            tags.insert("Text")
        }

        return tags
    }

    /// Perform image classification using Vision
    private func performImageClassification(_ cgImage: CGImage) async -> Set<String> {
        await withCheckedContinuation { continuation in
            var resultTags: Set<String> = []

            let request = VNClassifyImageRequest { request, error in
                guard error == nil,
                      let observations = request.results as? [VNClassificationObservation] else {
                    continuation.resume(returning: resultTags)
                    return
                }

                // Get high-confidence classifications
                let validObservations = observations.filter { $0.confidence >= self.confidenceThreshold }

                for observation in validObservations.prefix(5) {
                    let tag = self.formatClassificationTag(observation.identifier)
                    if let tag = tag {
                        resultTags.insert(tag)
                    }
                }

                continuation.resume(returning: resultTags)
            }

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                print("Image classification error: \(error)")
                continuation.resume(returning: resultTags)
            }
        }
    }

    /// Detect faces in image
    private func detectFaces(_ cgImage: CGImage) async -> Bool {
        await withCheckedContinuation { continuation in
            let request = VNDetectFaceRectanglesRequest { request, error in
                guard error == nil,
                      let results = request.results as? [VNFaceObservation] else {
                    continuation.resume(returning: false)
                    return
                }
                continuation.resume(returning: !results.isEmpty)
            }

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(returning: false)
            }
        }
    }

    /// Detect text in image (for OCR tag)
    private func detectText(_ cgImage: CGImage) async -> Bool {
        await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                guard error == nil,
                      let results = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: false)
                    return
                }
                // Consider it has text if we find at least one confident recognition
                let hasText = results.contains { observation in
                    observation.topCandidates(1).first?.confidence ?? 0 > 0.5
                }
                continuation.resume(returning: hasText)
            }
            request.recognitionLevel = .fast

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(returning: false)
            }
        }
    }

    /// Format Vision classification identifier into a readable tag
    private func formatClassificationTag(_ identifier: String) -> String? {
        // Map common Vision classifications to user-friendly tags
        let tagMappings: [String: String] = [
            // Outdoor scenes
            "beach": "Beach",
            "ocean": "Beach",
            "mountain": "Mountains",
            "sky": "Outdoors",
            "outdoor": "Outdoors",
            "forest": "Nature",
            "tree": "Nature",
            "park": "Park",
            "garden": "Garden",
            "grass": "Outdoors",
            "sunset": "Sunset",
            "sunrise": "Sunrise",
            "snow": "Winter",
            "rain": "Rainy Day",

            // Indoor scenes
            "indoor": "Indoors",
            "room": "Indoors",
            "kitchen": "Home",
            "bedroom": "Home",
            "living_room": "Home",
            "bathroom": "Home",

            // Activities
            "playground": "Playground",
            "swimming": "Swimming",
            "sports": "Sports",
            "birthday": "Birthday",
            "party": "Party",
            "celebration": "Celebration",
            "wedding": "Wedding",
            "graduation": "Graduation",

            // Animals
            "dog": "Pet",
            "cat": "Pet",
            "pet": "Pet",
            "animal": "Animals",

            // Food
            "food": "Food",
            "meal": "Meal",
            "cake": "Celebration",
            "dessert": "Food",

            // Travel
            "airplane": "Travel",
            "car": "Travel",
            "train": "Travel",
            "hotel": "Travel",

            // School/Education
            "school": "School",
            "classroom": "School",
            "book": "Reading",

            // Art/Creativity
            "art": "Art",
            "drawing": "Art",
            "painting": "Art",
            "craft": "Crafts",

            // Special moments
            "baby": "Baby",
            "toddler": "Toddler",
            "child": "Childhood",
            "family": "Family",
            "portrait": "Portrait"
        ]

        let lowercased = identifier.lowercased()

        // Direct mapping
        if let mapped = tagMappings[lowercased] {
            return mapped
        }

        // Check for partial matches
        for (key, value) in tagMappings {
            if lowercased.contains(key) {
                return value
            }
        }

        // Skip generic or unhelpful classifications
        let skipList = ["object", "thing", "item", "other", "none", "unknown"]
        if skipList.contains(lowercased) {
            return nil
        }

        // Format the identifier as a capitalized tag if it seems meaningful
        let formatted = identifier
            .replacingOccurrences(of: "_", with: " ")
            .capitalized

        // Only return if it's reasonably short
        if formatted.count <= 20 {
            return formatted
        }

        return nil
    }

    // MARK: - Text Analysis

    /// Analyze text content using NaturalLanguage framework
    private func analyzeText(_ text: String) -> Set<String> {
        var tags: Set<String> = []

        // Extract named entities (places, people names, organizations)
        let entityTags = extractEntities(from: text)
        tags.formUnion(entityTags)

        // Extract keywords/themes using keyword patterns
        let keywordTags = extractKeywords(from: text)
        tags.formUnion(keywordTags)

        return tags
    }

    /// Extract named entities from text
    private func extractEntities(from text: String) -> Set<String> {
        var tags: Set<String> = []

        let tagger = NLTagger(tagSchemes: [.nameType])
        tagger.string = text

        let options: NLTagger.Options = [.omitPunctuation, .omitWhitespace]

        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .nameType, options: options) { tag, tokenRange in
            if let tag = tag {
                switch tag {
                case .placeName:
                    let place = String(text[tokenRange])
                    if place.count > 2 {
                        tags.insert(place)
                    }
                case .organizationName:
                    let org = String(text[tokenRange])
                    if org.count > 2 {
                        tags.insert(org)
                    }
                default:
                    break
                }
            }
            return true
        }

        return tags
    }

    /// Extract keywords from text using pattern matching
    private func extractKeywords(from text: String) -> Set<String> {
        var tags: Set<String> = []
        let lowercased = text.lowercased()

        // Activity keywords
        let activityKeywords: [String: String] = [
            "birthday": "Birthday",
            "party": "Party",
            "celebration": "Celebration",
            "holiday": "Holiday",
            "christmas": "Christmas",
            "easter": "Easter",
            "halloween": "Halloween",
            "thanksgiving": "Thanksgiving",
            "vacation": "Vacation",
            "trip": "Travel",
            "beach": "Beach",
            "pool": "Swimming",
            "park": "Park",
            "playground": "Playground",
            "school": "School",
            "graduation": "Graduation",
            "wedding": "Wedding",
            "first": "First",
            "milestone": "Milestone",
            "walk": "Walking",
            "crawl": "Crawling",
            "talk": "Talking",
            "smile": "Smile",
            "laugh": "Laughter",
            "sleep": "Sleeping",
            "eating": "Mealtime",
            "bath": "Bath Time",
            "bedtime": "Bedtime",
            "playtime": "Playtime",
            "reading": "Reading",
            "drawing": "Art",
            "painting": "Art",
            "music": "Music",
            "dance": "Dancing",
            "sport": "Sports",
            "soccer": "Soccer",
            "baseball": "Baseball",
            "basketball": "Basketball",
            "swimming": "Swimming",
            "bike": "Biking",
            "hiking": "Hiking",
            "camping": "Camping",
            "zoo": "Zoo",
            "museum": "Museum",
            "doctor": "Doctor Visit",
            "dentist": "Dentist",
            "haircut": "Haircut"
        ]

        for (keyword, tag) in activityKeywords {
            if lowercased.contains(keyword) {
                tags.insert(tag)
            }
        }

        // Emotion keywords
        let emotionKeywords: [String: String] = [
            "happy": "Happy",
            "excited": "Excited",
            "proud": "Proud Moment",
            "funny": "Funny",
            "silly": "Silly",
            "cute": "Cute",
            "sweet": "Sweet Moment",
            "love": "Love",
            "special": "Special Moment"
        ]

        for (keyword, tag) in emotionKeywords {
            if lowercased.contains(keyword) {
                tags.insert(tag)
            }
        }

        return tags
    }

    // MARK: - Contextual Tags

    /// Build text content from memory for analysis
    private func buildTextContent(from memory: Memory) -> String {
        var parts: [String] = []

        if let title = memory.title, !title.isEmpty {
            parts.append(title)
        }
        if let notes = memory.notes, !notes.isEmpty {
            parts.append(notes)
        }
        if let extractedText = memory.extractedText, !extractedText.isEmpty {
            parts.append(extractedText)
        }
        if let transcription = memory.transcription, !transcription.isEmpty {
            parts.append(transcription)
        }

        return parts.joined(separator: " ")
    }

    /// Get age stage tag based on loved one's birth date
    private func getAgeStageTag(for memory: Memory) -> String? {
        guard let lovedOne = memory.lovedOne,
              let birthDate = lovedOne.birthDate,
              let captureDate = memory.captureDate else {
            return nil
        }

        let calendar = Calendar.current
        let components = calendar.dateComponents([.month], from: birthDate, to: captureDate)

        guard let months = components.month, months >= 0 else {
            return nil
        }

        let stage = AgeStage.stage(forAgeInMonths: months)
        return stage.displayName
    }

    /// Get season tag based on capture date
    private func getSeasonTag(for memory: Memory) -> String? {
        guard let captureDate = memory.captureDate else { return nil }
        return Season.season(for: captureDate).displayName
    }

    /// Get time of day tag
    private func getTimeOfDayTag(for memory: Memory) -> String? {
        guard let captureDate = memory.captureDate else { return nil }

        let hour = Calendar.current.component(.hour, from: captureDate)

        switch hour {
        case 5..<8:
            return "Early Morning"
        case 8..<12:
            return "Morning"
        case 12..<14:
            return "Midday"
        case 14..<17:
            return "Afternoon"
        case 17..<20:
            return "Evening"
        case 20..<24, 0..<5:
            return "Night"
        default:
            return nil
        }
    }

    // MARK: - Apply Tags

    /// Apply suggested tags to a memory
    private func applyTags(_ tagNames: Set<String>, to memory: Memory, in context: NSManagedObjectContext) async {
        await context.perform {
            for tagName in tagNames {
                let trimmed = tagName.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { continue }

                let tag = Tag.findOrCreate(name: trimmed, isAIGenerated: true, in: context)
                memory.addToTags(tag)
            }

            do {
                try context.save()
            } catch {
                print("Error saving tags: \(error)")
            }
        }
    }

    // MARK: - OCR (Text Extraction)

    /// Extract text from an image using Vision OCR
    func extractText(from image: UIImage) async -> String? {
        guard let cgImage = image.cgImage else { return nil }

        return await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                guard error == nil,
                      let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: nil)
                    return
                }

                let text = observations
                    .compactMap { $0.topCandidates(1).first?.string }
                    .joined(separator: "\n")

                continuation.resume(returning: text.isEmpty ? nil : text)
            }

            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                print("OCR error: \(error)")
                continuation.resume(returning: nil)
            }
        }
    }

    // MARK: - Manual Tag Management

    /// Add a manual tag to a memory
    func addTag(_ tagName: String, to memory: Memory, in context: NSManagedObjectContext) {
        let tag = Tag.findOrCreate(name: tagName, isAIGenerated: false, in: context)
        memory.addToTags(tag)

        do {
            try context.save()
        } catch {
            print("Error adding tag: \(error)")
        }
    }

    /// Remove a tag from a memory
    func removeTag(_ tag: Tag, from memory: Memory, in context: NSManagedObjectContext) {
        memory.removeFromTags(tag)

        // Delete the tag if it's no longer used
        if tag.memoryCount == 0 {
            context.delete(tag)
        }

        do {
            try context.save()
        } catch {
            print("Error removing tag: \(error)")
        }
    }
}
