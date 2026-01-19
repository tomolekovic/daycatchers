import Foundation
import UIKit
import PDFKit
import CoreData

/// PDFExportService handles generating PDF memory books from Core Data entities.
@MainActor
final class PDFExportService: ObservableObject {
    static let shared = PDFExportService()

    @Published var isGenerating = false
    @Published var progress: Double = 0
    @Published var currentStep: String = ""

    private let fileManager = FileManager.default

    private init() {}

    // MARK: - Directory Management

    private var documentsDirectory: URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    private var exportsDirectory: URL {
        documentsDirectory.appendingPathComponent("Exports", isDirectory: true)
    }

    private func createExportsDirectoryIfNeeded() throws {
        if !fileManager.fileExists(atPath: exportsDirectory.path) {
            try fileManager.createDirectory(at: exportsDirectory, withIntermediateDirectories: true)
        }
    }

    // MARK: - PDF Generation

    /// Generate a memory book PDF for a loved one
    /// - Parameters:
    ///   - lovedOne: The person to generate the book for
    ///   - startDate: Optional start date filter
    ///   - endDate: Optional end date filter
    ///   - includePhotos: Whether to include photo/video thumbnails
    ///   - includeVideos: Whether to include video thumbnails
    ///   - includeMilestones: Whether to include events/milestones
    ///   - context: The managed object context
    /// - Returns: URL of the generated PDF file
    func generateMemoryBook(
        for lovedOne: LovedOne,
        from startDate: Date?,
        to endDate: Date?,
        includePhotos: Bool,
        includeVideos: Bool,
        includeMilestones: Bool,
        in context: NSManagedObjectContext
    ) async throws -> URL {
        isGenerating = true
        progress = 0
        currentStep = "Preparing..."

        defer {
            isGenerating = false
            progress = 1.0
            currentStep = ""
        }

        try createExportsDirectoryIfNeeded()

        // Fetch memories
        let memories = try await fetchMemories(
            for: lovedOne,
            from: startDate,
            to: endDate,
            includePhotos: includePhotos,
            includeVideos: includeVideos,
            in: context
        )

        // Fetch events if needed
        let events: [Event] = includeMilestones ? await fetchEvents(for: lovedOne, from: startDate, to: endDate, in: context) : []

        currentStep = "Generating PDF..."
        progress = 0.1

        // A4 page size: 595 x 842 points
        let pageWidth: CGFloat = 595
        let pageHeight: CGFloat = 842
        let margin: CGFloat = 40
        let contentWidth = pageWidth - (margin * 2)

        // Generate filename
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: Date())
        let sanitizedName = (lovedOne.name ?? "Unknown").replacingOccurrences(of: " ", with: "_")
        let filename = "\(sanitizedName)_MemoryBook_\(dateString).pdf"
        let outputURL = exportsDirectory.appendingPathComponent(filename)

        // Remove existing file if present
        try? fileManager.removeItem(at: outputURL)

        // Create PDF renderer
        let pdfRenderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight))

        let pdfData = pdfRenderer.pdfData { pdfContext in
            // Cover Page
            drawCoverPage(
                context: pdfContext,
                lovedOne: lovedOne,
                startDate: startDate,
                endDate: endDate,
                pageWidth: pageWidth,
                pageHeight: pageHeight,
                margin: margin
            )

            // Table of Contents
            drawTableOfContents(
                context: pdfContext,
                memories: memories,
                events: events,
                pageWidth: pageWidth,
                pageHeight: pageHeight,
                margin: margin,
                contentWidth: contentWidth
            )

            // Memory Pages
            let totalItems = memories.count + events.count
            var itemIndex = 0

            let groupedMemories = groupMemoriesByMonth(memories)
            for (monthKey, monthMemories) in groupedMemories.sorted(by: { $0.key > $1.key }) {
                drawMonthHeader(
                    context: pdfContext,
                    monthKey: monthKey,
                    pageWidth: pageWidth,
                    pageHeight: pageHeight,
                    margin: margin
                )

                for memory in monthMemories {
                    drawMemoryPage(
                        context: pdfContext,
                        memory: memory,
                        pageWidth: pageWidth,
                        pageHeight: pageHeight,
                        margin: margin,
                        contentWidth: contentWidth
                    )

                    itemIndex += 1
                    Task { @MainActor in
                        self.progress = 0.1 + (Double(itemIndex) / Double(totalItems)) * 0.8
                    }
                }
            }

            // Milestone Pages
            if !events.isEmpty {
                drawMilestonesSection(
                    context: pdfContext,
                    events: events,
                    pageWidth: pageWidth,
                    pageHeight: pageHeight,
                    margin: margin,
                    contentWidth: contentWidth
                )
            }
        }

        try pdfData.write(to: outputURL)
        progress = 1.0
        currentStep = "Complete!"

        return outputURL
    }

    // MARK: - Data Fetching

    private func fetchMemories(
        for lovedOne: LovedOne,
        from startDate: Date?,
        to endDate: Date?,
        includePhotos: Bool,
        includeVideos: Bool,
        in context: NSManagedObjectContext
    ) async throws -> [Memory] {
        let request: NSFetchRequest<Memory> = Memory.fetchRequest()

        var predicates: [NSPredicate] = [
            NSPredicate(format: "lovedOne == %@", lovedOne)
        ]

        // Date filter
        if let start = startDate {
            predicates.append(NSPredicate(format: "captureDate >= %@", start as NSDate))
        }
        if let end = endDate {
            predicates.append(NSPredicate(format: "captureDate <= %@", end as NSDate))
        }

        // Type filter
        var typePredicates: [NSPredicate] = [
            NSPredicate(format: "type == %@", MemoryType.text.rawValue),
            NSPredicate(format: "type == %@", MemoryType.audio.rawValue)
        ]
        if includePhotos {
            typePredicates.append(NSPredicate(format: "type == %@", MemoryType.photo.rawValue))
        }
        if includeVideos {
            typePredicates.append(NSPredicate(format: "type == %@", MemoryType.video.rawValue))
        }
        predicates.append(NSCompoundPredicate(orPredicateWithSubpredicates: typePredicates))

        request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Memory.captureDate, ascending: false)]

        return try context.fetch(request)
    }

    private func fetchEvents(
        for lovedOne: LovedOne,
        from startDate: Date?,
        to endDate: Date?,
        in context: NSManagedObjectContext
    ) async -> [Event] {
        let request: NSFetchRequest<Event> = Event.fetchRequest()

        var predicates: [NSPredicate] = [
            NSPredicate(format: "lovedOne == %@", lovedOne)
        ]

        if let start = startDate {
            predicates.append(NSPredicate(format: "date >= %@", start as NSDate))
        }
        if let end = endDate {
            predicates.append(NSPredicate(format: "date <= %@", end as NSDate))
        }

        request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Event.date, ascending: false)]

        return (try? context.fetch(request)) ?? []
    }

    // MARK: - Drawing Helpers

    private func drawCoverPage(
        context: UIGraphicsPDFRendererContext,
        lovedOne: LovedOne,
        startDate: Date?,
        endDate: Date?,
        pageWidth: CGFloat,
        pageHeight: CGFloat,
        margin: CGFloat
    ) {
        context.beginPage()

        // Profile image
        let profileImageSize: CGFloat = 150
        let profileImageRect = CGRect(
            x: (pageWidth - profileImageSize) / 2,
            y: margin + 100,
            width: profileImageSize,
            height: profileImageSize
        )

        if let imagePath = lovedOne.profileImagePath,
           let profileImage = MediaManager.shared.loadProfileImage(filename: imagePath) {
            // Draw circular profile image
            let circlePath = UIBezierPath(ovalIn: profileImageRect)
            context.cgContext.saveGState()
            circlePath.addClip()
            profileImage.draw(in: profileImageRect)
            context.cgContext.restoreGState()

            // Draw circle border
            UIColor.gray.setStroke()
            circlePath.lineWidth = 2
            circlePath.stroke()
        } else {
            // Draw placeholder circle
            let circlePath = UIBezierPath(ovalIn: profileImageRect)
            UIColor.systemGray5.setFill()
            circlePath.fill()

            // Draw initials
            let initials = (lovedOne.name ?? "?").prefix(1).uppercased()
            let initialsFont = UIFont.systemFont(ofSize: 60, weight: .medium)
            let initialsAttr: [NSAttributedString.Key: Any] = [
                .font: initialsFont,
                .foregroundColor: UIColor.systemGray
            ]
            let initialsSize = (initials as NSString).size(withAttributes: initialsAttr)
            let initialsRect = CGRect(
                x: profileImageRect.midX - initialsSize.width / 2,
                y: profileImageRect.midY - initialsSize.height / 2,
                width: initialsSize.width,
                height: initialsSize.height
            )
            (initials as NSString).draw(in: initialsRect, withAttributes: initialsAttr)
        }

        // Title - Name
        let titleFont = UIFont.systemFont(ofSize: 36, weight: .bold)
        let titleAttr: [NSAttributedString.Key: Any] = [
            .font: titleFont,
            .foregroundColor: UIColor.black
        ]
        let title = lovedOne.name ?? "Memory Book"
        let titleSize = (title as NSString).size(withAttributes: titleAttr)
        let titleRect = CGRect(
            x: (pageWidth - titleSize.width) / 2,
            y: profileImageRect.maxY + 40,
            width: titleSize.width,
            height: titleSize.height
        )
        (title as NSString).draw(in: titleRect, withAttributes: titleAttr)

        // Subtitle - "Memory Book"
        let subtitleFont = UIFont.systemFont(ofSize: 24, weight: .light)
        let subtitleAttr: [NSAttributedString.Key: Any] = [
            .font: subtitleFont,
            .foregroundColor: UIColor.darkGray
        ]
        let subtitle = "Memory Book"
        let subtitleSize = (subtitle as NSString).size(withAttributes: subtitleAttr)
        let subtitleRect = CGRect(
            x: (pageWidth - subtitleSize.width) / 2,
            y: titleRect.maxY + 10,
            width: subtitleSize.width,
            height: subtitleSize.height
        )
        (subtitle as NSString).draw(in: subtitleRect, withAttributes: subtitleAttr)

        // Date range
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        var dateRangeText = ""
        if let start = startDate, let end = endDate {
            dateRangeText = "\(dateFormatter.string(from: start)) - \(dateFormatter.string(from: end))"
        } else if let start = startDate {
            dateRangeText = "From \(dateFormatter.string(from: start))"
        } else if let end = endDate {
            dateRangeText = "Until \(dateFormatter.string(from: end))"
        }

        if !dateRangeText.isEmpty {
            let dateFont = UIFont.systemFont(ofSize: 16, weight: .regular)
            let dateAttr: [NSAttributedString.Key: Any] = [
                .font: dateFont,
                .foregroundColor: UIColor.gray
            ]
            let dateSize = (dateRangeText as NSString).size(withAttributes: dateAttr)
            let dateRect = CGRect(
                x: (pageWidth - dateSize.width) / 2,
                y: subtitleRect.maxY + 20,
                width: dateSize.width,
                height: dateSize.height
            )
            (dateRangeText as NSString).draw(in: dateRect, withAttributes: dateAttr)
        }

        // Footer - Generated date
        let footerFont = UIFont.systemFont(ofSize: 10, weight: .light)
        let footerAttr: [NSAttributedString.Key: Any] = [
            .font: footerFont,
            .foregroundColor: UIColor.lightGray
        ]
        let footerText = "Generated by Daycatcher on \(dateFormatter.string(from: Date()))"
        let footerSize = (footerText as NSString).size(withAttributes: footerAttr)
        let footerRect = CGRect(
            x: (pageWidth - footerSize.width) / 2,
            y: pageHeight - margin - footerSize.height,
            width: footerSize.width,
            height: footerSize.height
        )
        (footerText as NSString).draw(in: footerRect, withAttributes: footerAttr)
    }

    private func drawTableOfContents(
        context: UIGraphicsPDFRendererContext,
        memories: [Memory],
        events: [Event],
        pageWidth: CGFloat,
        pageHeight: CGFloat,
        margin: CGFloat,
        contentWidth: CGFloat
    ) {
        context.beginPage()

        // Title
        let titleFont = UIFont.systemFont(ofSize: 24, weight: .bold)
        let titleAttr: [NSAttributedString.Key: Any] = [
            .font: titleFont,
            .foregroundColor: UIColor.black
        ]
        let title = "Contents"
        (title as NSString).draw(at: CGPoint(x: margin, y: margin), withAttributes: titleAttr)

        var yOffset = margin + 50

        // Group memories by month
        let groupedMemories = groupMemoriesByMonth(memories)
        let itemFont = UIFont.systemFont(ofSize: 14, weight: .regular)
        let itemAttr: [NSAttributedString.Key: Any] = [
            .font: itemFont,
            .foregroundColor: UIColor.darkGray
        ]

        for (monthKey, monthMemories) in groupedMemories.sorted(by: { $0.key > $1.key }) {
            let text = "\(monthKey) (\(monthMemories.count) memories)"
            (text as NSString).draw(at: CGPoint(x: margin + 20, y: yOffset), withAttributes: itemAttr)
            yOffset += 25

            if yOffset > pageHeight - margin - 50 {
                context.beginPage()
                yOffset = margin
            }
        }

        // Events section
        if !events.isEmpty {
            yOffset += 20
            let sectionFont = UIFont.systemFont(ofSize: 16, weight: .semibold)
            let sectionAttr: [NSAttributedString.Key: Any] = [
                .font: sectionFont,
                .foregroundColor: UIColor.black
            ]
            ("Milestones & Events" as NSString).draw(at: CGPoint(x: margin, y: yOffset), withAttributes: sectionAttr)
            yOffset += 30

            for event in events.prefix(10) {
                let text = "• \(event.title ?? "Untitled")"
                (text as NSString).draw(at: CGPoint(x: margin + 20, y: yOffset), withAttributes: itemAttr)
                yOffset += 20
            }

            if events.count > 10 {
                let moreText = "... and \(events.count - 10) more events"
                (moreText as NSString).draw(at: CGPoint(x: margin + 20, y: yOffset), withAttributes: itemAttr)
            }
        }
    }

    private func drawMonthHeader(
        context: UIGraphicsPDFRendererContext,
        monthKey: String,
        pageWidth: CGFloat,
        pageHeight: CGFloat,
        margin: CGFloat
    ) {
        context.beginPage()

        // Month header
        let headerFont = UIFont.systemFont(ofSize: 28, weight: .bold)
        let headerAttr: [NSAttributedString.Key: Any] = [
            .font: headerFont,
            .foregroundColor: UIColor.black
        ]
        (monthKey as NSString).draw(at: CGPoint(x: margin, y: margin), withAttributes: headerAttr)

        // Decorative line
        let linePath = UIBezierPath()
        linePath.move(to: CGPoint(x: margin, y: margin + 45))
        linePath.addLine(to: CGPoint(x: pageWidth - margin, y: margin + 45))
        UIColor.systemGray4.setStroke()
        linePath.lineWidth = 1
        linePath.stroke()
    }

    private func drawMemoryPage(
        context: UIGraphicsPDFRendererContext,
        memory: Memory,
        pageWidth: CGFloat,
        pageHeight: CGFloat,
        margin: CGFloat,
        contentWidth: CGFloat
    ) {
        context.beginPage()

        var yOffset = margin

        // Date header
        let dateFont = UIFont.systemFont(ofSize: 12, weight: .medium)
        let dateAttr: [NSAttributedString.Key: Any] = [
            .font: dateFont,
            .foregroundColor: UIColor.gray
        ]
        let dateText = memory.formattedDate
        (dateText as NSString).draw(at: CGPoint(x: margin, y: yOffset), withAttributes: dateAttr)
        yOffset += 25

        // Title
        if let title = memory.title, !title.isEmpty {
            let titleFont = UIFont.systemFont(ofSize: 20, weight: .semibold)
            let titleAttr: [NSAttributedString.Key: Any] = [
                .font: titleFont,
                .foregroundColor: UIColor.black
            ]
            (title as NSString).draw(at: CGPoint(x: margin, y: yOffset), withAttributes: titleAttr)
            yOffset += 35
        }

        // Memory type badge
        let badgeFont = UIFont.systemFont(ofSize: 10, weight: .medium)
        let badgeAttr: [NSAttributedString.Key: Any] = [
            .font: badgeFont,
            .foregroundColor: UIColor.white
        ]
        let badgeText = memory.memoryType.displayName
        let badgeSize = (badgeText as NSString).size(withAttributes: badgeAttr)
        let badgePadding: CGFloat = 8
        let badgeRect = CGRect(
            x: margin,
            y: yOffset,
            width: badgeSize.width + badgePadding * 2,
            height: badgeSize.height + badgePadding
        )

        // Badge background color based on type
        let badgeColor: UIColor
        switch memory.memoryType {
        case .photo: badgeColor = .systemBlue
        case .video: badgeColor = .systemPurple
        case .audio: badgeColor = .systemOrange
        case .text: badgeColor = .systemGreen
        }

        let badgePath = UIBezierPath(roundedRect: badgeRect, cornerRadius: 4)
        badgeColor.setFill()
        badgePath.fill()

        (badgeText as NSString).draw(
            at: CGPoint(x: badgeRect.minX + badgePadding, y: badgeRect.minY + badgePadding / 2),
            withAttributes: badgeAttr
        )
        yOffset += badgeRect.height + 20

        // Thumbnail for photo/video
        if memory.memoryType == .photo || memory.memoryType == .video {
            if let thumbnailPath = memory.thumbnailPath,
               let thumbnail = MediaManager.shared.loadThumbnail(filename: thumbnailPath) {
                let maxImageWidth = contentWidth
                let maxImageHeight: CGFloat = 350

                let aspectRatio = thumbnail.size.width / thumbnail.size.height
                var imageWidth = maxImageWidth
                var imageHeight = imageWidth / aspectRatio

                if imageHeight > maxImageHeight {
                    imageHeight = maxImageHeight
                    imageWidth = imageHeight * aspectRatio
                }

                let imageRect = CGRect(
                    x: margin + (contentWidth - imageWidth) / 2,
                    y: yOffset,
                    width: imageWidth,
                    height: imageHeight
                )

                // Draw image with rounded corners
                let imagePath = UIBezierPath(roundedRect: imageRect, cornerRadius: 8)
                context.cgContext.saveGState()
                imagePath.addClip()
                thumbnail.draw(in: imageRect)
                context.cgContext.restoreGState()

                yOffset += imageHeight + 20
            }
        }

        // Notes
        if let notes = memory.notes, !notes.isEmpty {
            let notesFont = UIFont.systemFont(ofSize: 14, weight: .regular)
            let notesStyle = NSMutableParagraphStyle()
            notesStyle.lineSpacing = 6
            let notesAttr: [NSAttributedString.Key: Any] = [
                .font: notesFont,
                .foregroundColor: UIColor.darkGray,
                .paragraphStyle: notesStyle
            ]

            let notesRect = CGRect(x: margin, y: yOffset, width: contentWidth, height: pageHeight - yOffset - margin - 50)
            (notes as NSString).draw(in: notesRect, withAttributes: notesAttr)
            yOffset += 100
        }

        // Location
        if let location = memory.locationName, !location.isEmpty {
            let locationFont = UIFont.systemFont(ofSize: 12, weight: .regular)
            let locationAttr: [NSAttributedString.Key: Any] = [
                .font: locationFont,
                .foregroundColor: UIColor.gray
            ]
            let locationText = "📍 \(location)"
            (locationText as NSString).draw(at: CGPoint(x: margin, y: pageHeight - margin - 40), withAttributes: locationAttr)
        }

        // Tags
        let tags = memory.tagsArray.compactMap { $0.name }.prefix(5)
        if !tags.isEmpty {
            let tagFont = UIFont.systemFont(ofSize: 10, weight: .medium)
            let tagAttr: [NSAttributedString.Key: Any] = [
                .font: tagFont,
                .foregroundColor: UIColor.systemBlue
            ]
            let tagsText = tags.map { "#\($0)" }.joined(separator: "  ")
            (tagsText as NSString).draw(at: CGPoint(x: margin, y: pageHeight - margin - 20), withAttributes: tagAttr)
        }
    }

    private func drawMilestonesSection(
        context: UIGraphicsPDFRendererContext,
        events: [Event],
        pageWidth: CGFloat,
        pageHeight: CGFloat,
        margin: CGFloat,
        contentWidth: CGFloat
    ) {
        // Section header page
        context.beginPage()

        let headerFont = UIFont.systemFont(ofSize: 28, weight: .bold)
        let headerAttr: [NSAttributedString.Key: Any] = [
            .font: headerFont,
            .foregroundColor: UIColor.black
        ]
        ("Milestones & Events" as NSString).draw(at: CGPoint(x: margin, y: margin), withAttributes: headerAttr)

        // Decorative line
        let linePath = UIBezierPath()
        linePath.move(to: CGPoint(x: margin, y: margin + 45))
        linePath.addLine(to: CGPoint(x: pageWidth - margin, y: margin + 45))
        UIColor.systemGray4.setStroke()
        linePath.lineWidth = 1
        linePath.stroke()

        var yOffset = margin + 70

        for event in events {
            if yOffset > pageHeight - margin - 100 {
                context.beginPage()
                yOffset = margin
            }

            // Event type icon
            let typeFont = UIFont.systemFont(ofSize: 20)
            let typeIcon: String
            switch event.eventTypeValue {
            case .birthday: typeIcon = "🎂"
            case .anniversary: typeIcon = "❤️"
            case .milestone: typeIcon = "⭐"
            case .custom: typeIcon = "📅"
            }
            (typeIcon as NSString).draw(at: CGPoint(x: margin, y: yOffset), withAttributes: [.font: typeFont])

            // Event title
            let titleFont = UIFont.systemFont(ofSize: 16, weight: .semibold)
            let titleAttr: [NSAttributedString.Key: Any] = [
                .font: titleFont,
                .foregroundColor: UIColor.black
            ]
            ((event.title ?? "Untitled") as NSString).draw(at: CGPoint(x: margin + 35, y: yOffset), withAttributes: titleAttr)

            // Event date
            let dateFont = UIFont.systemFont(ofSize: 12, weight: .regular)
            let dateAttr: [NSAttributedString.Key: Any] = [
                .font: dateFont,
                .foregroundColor: UIColor.gray
            ]
            (event.formattedDate as NSString).draw(at: CGPoint(x: margin + 35, y: yOffset + 22), withAttributes: dateAttr)

            // Event notes
            if let notes = event.notes, !notes.isEmpty {
                let notesFont = UIFont.systemFont(ofSize: 12, weight: .regular)
                let notesAttr: [NSAttributedString.Key: Any] = [
                    .font: notesFont,
                    .foregroundColor: UIColor.darkGray
                ]
                let notesRect = CGRect(x: margin + 35, y: yOffset + 42, width: contentWidth - 35, height: 40)
                (notes as NSString).draw(in: notesRect, withAttributes: notesAttr)
                yOffset += 90
            } else {
                yOffset += 60
            }
        }
    }

    // MARK: - Helpers

    private func groupMemoriesByMonth(_ memories: [Memory]) -> [String: [Memory]] {
        var grouped: [String: [Memory]] = [:]
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"

        for memory in memories {
            let key = formatter.string(from: memory.captureDate ?? Date())
            if grouped[key] == nil {
                grouped[key] = []
            }
            grouped[key]?.append(memory)
        }

        return grouped
    }

    // MARK: - Cleanup

    /// List all exported PDFs
    func listExports() -> [URL] {
        guard let contents = try? fileManager.contentsOfDirectory(
            at: exportsDirectory,
            includingPropertiesForKeys: [.creationDateKey],
            options: .skipsHiddenFiles
        ) else {
            return []
        }

        return contents.filter { $0.pathExtension == "pdf" }
            .sorted { url1, url2 in
                let date1 = (try? url1.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date.distantPast
                let date2 = (try? url2.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date.distantPast
                return date1 > date2
            }
    }

    /// Delete an exported PDF
    func deleteExport(at url: URL) throws {
        try fileManager.removeItem(at: url)
    }

    /// Get total size of exports
    func exportsSize() -> Int64 {
        var totalSize: Int64 = 0

        if let enumerator = fileManager.enumerator(at: exportsDirectory, includingPropertiesForKeys: [.fileSizeKey]) {
            for case let fileURL as URL in enumerator {
                if let fileSize = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                    totalSize += Int64(fileSize)
                }
            }
        }

        return totalSize
    }
}
