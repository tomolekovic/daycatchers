import SwiftUI
import PhotosUI
import CoreData

struct AddLovedOneView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var birthDate = Date()
    @State private var hasBirthDate = false
    @State private var relationship: RelationshipType = .child
    @State private var gender: Gender?
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var profileImageData: Data?
    @State private var isSharedWithFamily = false

    @State private var isSaving = false

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                // Profile Photo
                Section {
                    HStack {
                        Spacer()
                        profilePhotoView
                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                }

                // Basic Info
                Section("Basic Information") {
                    TextField("Name", text: $name)

                    Picker("Relationship", selection: $relationship) {
                        ForEach(RelationshipType.allCases) { type in
                            Label(type.displayName, systemImage: type.icon)
                                .tag(type)
                        }
                    }

                    Toggle("Has Birth Date", isOn: $hasBirthDate)

                    if hasBirthDate {
                        DatePicker("Birth Date", selection: $birthDate, displayedComponents: .date)
                    }

                    Picker("Gender", selection: $gender) {
                        Text("Not specified").tag(nil as Gender?)
                        ForEach(Gender.allCases) { g in
                            Text(g.displayName).tag(g as Gender?)
                        }
                    }
                }

                // Sharing
                Section {
                    Toggle("Share with Family", isOn: $isSharedWithFamily)
                } header: {
                    Text("Family Sharing")
                } footer: {
                    Text("If enabled, family members will be able to see and add memories for \(name.isEmpty ? "this person" : name).")
                }
            }
            .navigationTitle("Add Loved One")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                    }
                    .disabled(!isValid || isSaving)
                }
            }
        }
    }

    // MARK: - Profile Photo View

    private var profilePhotoView: some View {
        PhotosPicker(selection: $selectedPhoto, matching: .images) {
            if let imageData = profileImageData,
               let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 120, height: 120)
                    .clipShape(Circle())
                    .overlay(photoOverlay)
            } else {
                Circle()
                    .fill(themeManager.theme.surfaceColor)
                    .frame(width: 120, height: 120)
                    .overlay {
                        VStack(spacing: 8) {
                            Image(systemName: "camera.fill")
                                .font(.title2)
                            Text("Add Photo")
                                .font(themeManager.theme.captionFont)
                        }
                        .foregroundStyle(themeManager.theme.textSecondary)
                    }
            }
        }
        .onChange(of: selectedPhoto) { _, newValue in
            Task {
                if let data = try? await newValue?.loadTransferable(type: Data.self) {
                    profileImageData = data
                }
            }
        }
    }

    private var photoOverlay: some View {
        Circle()
            .fill(.black.opacity(0.3))
            .overlay {
                Image(systemName: "camera.fill")
                    .foregroundStyle(.white)
            }
    }

    // MARK: - Save

    private func save() {
        guard isValid else { return }
        isSaving = true

        let lovedOne = LovedOne(context: viewContext)
        lovedOne.id = UUID()
        lovedOne.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        lovedOne.birthDate = hasBirthDate ? birthDate : nil
        lovedOne.relationship = relationship.rawValue
        lovedOne.gender = gender?.rawValue
        lovedOne.isSharedWithFamily = isSharedWithFamily
        lovedOne.createdAt = Date()

        // Save profile image
        if let imageData = profileImageData {
            let filename = "\(lovedOne.id?.uuidString ?? UUID().uuidString).jpg"
            if MediaManager.shared.saveProfileImage(data: imageData, filename: filename) {
                lovedOne.profileImagePath = filename
            }
        }

        // Create birthday event if birth date exists
        if hasBirthDate {
            createBirthdayEvent(for: lovedOne)
        }

        do {
            try viewContext.save()
            dismiss()
        } catch {
            print("Error saving loved one: \(error)")
            isSaving = false
        }
    }

    private func createBirthdayEvent(for lovedOne: LovedOne) {
        let event = Event(context: viewContext)
        event.id = UUID()
        event.title = "\(lovedOne.name ?? "Birthday")'s Birthday"
        event.eventType = EventType.birthday.rawValue
        event.isAllDay = true
        event.reminderOffset = ReminderOffset.oneDay.rawValue
        event.lovedOne = lovedOne
        event.createdAt = Date()

        // Set date to next occurrence of birthday
        if let birthDate = lovedOne.birthDate {
            event.date = nextBirthday(from: birthDate)
        }
    }

    private func nextBirthday(from birthDate: Date) -> Date {
        let calendar = Calendar.current
        let now = Date()
        var components = calendar.dateComponents([.month, .day], from: birthDate)
        components.year = calendar.component(.year, from: now)

        guard let thisYearBirthday = calendar.date(from: components) else {
            return birthDate
        }

        if thisYearBirthday < now {
            components.year = (components.year ?? 0) + 1
            return calendar.date(from: components) ?? thisYearBirthday
        }

        return thisYearBirthday
    }
}

#Preview {
    AddLovedOneView()
        .environmentObject(ThemeManager())
}
