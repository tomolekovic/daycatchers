import SwiftUI
import PhotosUI
import CoreData

struct EditLovedOneView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    @ObservedObject var lovedOne: LovedOne

    @State private var name: String
    @State private var birthDate: Date
    @State private var hasBirthDate: Bool
    @State private var relationship: RelationshipType
    @State private var gender: Gender?
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var profileImageData: Data?
    @State private var isSharedWithFamily: Bool

    @State private var isSaving = false

    init(lovedOne: LovedOne) {
        self.lovedOne = lovedOne
        _name = State(initialValue: lovedOne.name ?? "")
        _birthDate = State(initialValue: lovedOne.birthDate ?? Date())
        _hasBirthDate = State(initialValue: lovedOne.birthDate != nil)
        _relationship = State(initialValue: lovedOne.relationshipType)
        _gender = State(initialValue: lovedOne.genderType)
        _isSharedWithFamily = State(initialValue: lovedOne.isSharedWithFamily)

        // Load existing profile image
        if let imageURL = lovedOne.profileImageURL,
           let data = try? Data(contentsOf: imageURL) {
            _profileImageData = State(initialValue: data)
        }
    }

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
            .navigationTitle("Edit")
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

        lovedOne.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        lovedOne.birthDate = hasBirthDate ? birthDate : nil
        lovedOne.relationship = relationship.rawValue
        lovedOne.gender = gender?.rawValue
        lovedOne.isSharedWithFamily = isSharedWithFamily

        // Save profile image if changed
        if selectedPhoto != nil, let imageData = profileImageData {
            // Delete old image if exists
            if let oldPath = lovedOne.profileImagePath {
                MediaManager.shared.deleteProfileImage(filename: oldPath)
            }

            let filename = "\(lovedOne.id?.uuidString ?? UUID().uuidString).jpg"
            if MediaManager.shared.saveProfileImage(data: imageData, filename: filename) {
                lovedOne.profileImagePath = filename
            }
        }

        do {
            try viewContext.save()
            dismiss()
        } catch {
            print("Error saving loved one: \(error)")
            isSaving = false
        }
    }
}

#Preview {
    EditLovedOneView(lovedOne: {
        let context = PersistenceController.preview.container.viewContext
        let lovedOne = LovedOne(context: context)
        lovedOne.id = UUID()
        lovedOne.name = "Emma"
        lovedOne.birthDate = Calendar.current.date(byAdding: .year, value: -3, to: Date())
        lovedOne.relationship = RelationshipType.child.rawValue
        return lovedOne
    }())
    .environmentObject(ThemeManager())
}
