import XCTest
@testable import Daycatcher

final class EnumTests: XCTestCase {

    // MARK: - MemoryType Tests

    func testMemoryTypeRawValues() {
        XCTAssertEqual(MemoryType.photo.rawValue, "photo")
        XCTAssertEqual(MemoryType.video.rawValue, "video")
        XCTAssertEqual(MemoryType.audio.rawValue, "audio")
        XCTAssertEqual(MemoryType.text.rawValue, "text")
    }

    func testMemoryTypeDisplayNames() {
        XCTAssertEqual(MemoryType.photo.displayName, "Photo")
        XCTAssertEqual(MemoryType.video.displayName, "Video")
        XCTAssertEqual(MemoryType.audio.displayName, "Audio")
        XCTAssertEqual(MemoryType.text.displayName, "Note")
    }

    func testMemoryTypeIcons() {
        XCTAssertEqual(MemoryType.photo.icon, "photo.fill")
        XCTAssertEqual(MemoryType.video.icon, "video.fill")
        XCTAssertEqual(MemoryType.audio.icon, "mic.fill")
        XCTAssertEqual(MemoryType.text.icon, "note.text")
    }

    func testMemoryTypeAllCases() {
        XCTAssertEqual(MemoryType.allCases.count, 4)
    }

    // MARK: - RelationshipType Tests

    func testRelationshipTypeRawValues() {
        XCTAssertEqual(RelationshipType.child.rawValue, "child")
        XCTAssertEqual(RelationshipType.partner.rawValue, "partner")
        XCTAssertEqual(RelationshipType.parent.rawValue, "parent")
        XCTAssertEqual(RelationshipType.pet.rawValue, "pet")
    }

    func testRelationshipTypeDisplayNames() {
        XCTAssertEqual(RelationshipType.child.displayName, "Child")
        XCTAssertEqual(RelationshipType.partner.displayName, "Partner")
        XCTAssertEqual(RelationshipType.grandparent.displayName, "Grandparent")
        XCTAssertEqual(RelationshipType.pet.displayName, "Pet")
    }

    func testRelationshipTypeIcons() {
        XCTAssertEqual(RelationshipType.child.icon, "figure.child")
        XCTAssertEqual(RelationshipType.partner.icon, "heart.fill")
        XCTAssertEqual(RelationshipType.pet.icon, "pawprint.fill")
    }

    func testRelationshipTypeAllCases() {
        XCTAssertEqual(RelationshipType.allCases.count, 8)
    }

    // MARK: - Gender Tests

    func testGenderRawValues() {
        XCTAssertEqual(Gender.male.rawValue, "male")
        XCTAssertEqual(Gender.female.rawValue, "female")
        XCTAssertEqual(Gender.other.rawValue, "other")
        XCTAssertEqual(Gender.preferNotToSay.rawValue, "prefer_not_to_say")
    }

    func testGenderDisplayNames() {
        XCTAssertEqual(Gender.male.displayName, "Male")
        XCTAssertEqual(Gender.female.displayName, "Female")
        XCTAssertEqual(Gender.preferNotToSay.displayName, "Prefer not to say")
    }

    // MARK: - EventType Tests

    func testEventTypeRawValues() {
        XCTAssertEqual(EventType.birthday.rawValue, "birthday")
        XCTAssertEqual(EventType.anniversary.rawValue, "anniversary")
        XCTAssertEqual(EventType.milestone.rawValue, "milestone")
        XCTAssertEqual(EventType.custom.rawValue, "custom")
    }

    func testEventTypeIcons() {
        XCTAssertEqual(EventType.birthday.icon, "birthday.cake.fill")
        XCTAssertEqual(EventType.anniversary.icon, "heart.fill")
        XCTAssertEqual(EventType.milestone.icon, "star.fill")
        XCTAssertEqual(EventType.custom.icon, "calendar")
    }

    // MARK: - ReminderOffset Tests

    func testReminderOffsetDays() {
        XCTAssertEqual(ReminderOffset.sameDay.days, 0)
        XCTAssertEqual(ReminderOffset.oneDay.days, 1)
        XCTAssertEqual(ReminderOffset.twoDays.days, 2)
        XCTAssertEqual(ReminderOffset.threeDays.days, 3)
        XCTAssertEqual(ReminderOffset.oneWeek.days, 7)
    }

    func testReminderOffsetDisplayNames() {
        XCTAssertEqual(ReminderOffset.sameDay.displayName, "Same day")
        XCTAssertEqual(ReminderOffset.oneDay.displayName, "1 day before")
        XCTAssertEqual(ReminderOffset.oneWeek.displayName, "1 week before")
    }

    // MARK: - AgeStage Tests

    func testAgeStageForNewborn() {
        XCTAssertEqual(AgeStage.stage(forAgeInMonths: 0), .newborn)
        XCTAssertEqual(AgeStage.stage(forAgeInMonths: 2), .newborn)
    }

    func testAgeStageForInfant() {
        XCTAssertEqual(AgeStage.stage(forAgeInMonths: 3), .infant)
        XCTAssertEqual(AgeStage.stage(forAgeInMonths: 11), .infant)
    }

    func testAgeStageForBaby() {
        XCTAssertEqual(AgeStage.stage(forAgeInMonths: 12), .baby)
        XCTAssertEqual(AgeStage.stage(forAgeInMonths: 23), .baby)
    }

    func testAgeStageForToddler() {
        XCTAssertEqual(AgeStage.stage(forAgeInMonths: 24), .toddler)
        XCTAssertEqual(AgeStage.stage(forAgeInMonths: 35), .toddler)
    }

    func testAgeStageForPreschooler() {
        XCTAssertEqual(AgeStage.stage(forAgeInMonths: 36), .preschooler)
        XCTAssertEqual(AgeStage.stage(forAgeInMonths: 59), .preschooler)
    }

    func testAgeStageForChild() {
        XCTAssertEqual(AgeStage.stage(forAgeInMonths: 60), .child)
        XCTAssertEqual(AgeStage.stage(forAgeInMonths: 143), .child)
    }

    func testAgeStageForTeenager() {
        XCTAssertEqual(AgeStage.stage(forAgeInMonths: 144), .teenager)
        XCTAssertEqual(AgeStage.stage(forAgeInMonths: 239), .teenager)
    }

    func testAgeStageForAdult() {
        XCTAssertEqual(AgeStage.stage(forAgeInMonths: 240), .adult)
        XCTAssertEqual(AgeStage.stage(forAgeInMonths: 500), .adult)
    }

    // MARK: - Season Tests

    func testSeasonForWinter() {
        let january = createDate(month: 1)
        let february = createDate(month: 2)
        let december = createDate(month: 12)

        XCTAssertEqual(Season.season(for: january), .winter)
        XCTAssertEqual(Season.season(for: february), .winter)
        XCTAssertEqual(Season.season(for: december), .winter)
    }

    func testSeasonForSpring() {
        let march = createDate(month: 3)
        let april = createDate(month: 4)
        let may = createDate(month: 5)

        XCTAssertEqual(Season.season(for: march), .spring)
        XCTAssertEqual(Season.season(for: april), .spring)
        XCTAssertEqual(Season.season(for: may), .spring)
    }

    func testSeasonForSummer() {
        let june = createDate(month: 6)
        let july = createDate(month: 7)
        let august = createDate(month: 8)

        XCTAssertEqual(Season.season(for: june), .summer)
        XCTAssertEqual(Season.season(for: july), .summer)
        XCTAssertEqual(Season.season(for: august), .summer)
    }

    func testSeasonForFall() {
        let september = createDate(month: 9)
        let october = createDate(month: 10)
        let november = createDate(month: 11)

        XCTAssertEqual(Season.season(for: september), .fall)
        XCTAssertEqual(Season.season(for: october), .fall)
        XCTAssertEqual(Season.season(for: november), .fall)
    }

    func testSeasonIcons() {
        XCTAssertEqual(Season.spring.icon, "leaf.fill")
        XCTAssertEqual(Season.summer.icon, "sun.max.fill")
        XCTAssertEqual(Season.fall.icon, "leaf.arrow.triangle.circlepath")
        XCTAssertEqual(Season.winter.icon, "snowflake")
    }

    // MARK: - Helpers

    private func createDate(month: Int) -> Date {
        var components = DateComponents()
        components.year = 2024
        components.month = month
        components.day = 15
        return Calendar.current.date(from: components)!
    }
}
