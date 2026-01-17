import SwiftUI
import CoreData

struct EditMemoryView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    @ObservedObject var memory: Memory

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \LovedOne.name, ascending: true)],
        animation: .default
    )
    private var lovedOnes: FetchedResults<LovedOne>

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Event.date, ascending: true)],
        animation: .default
    )
    private var events: FetchedResults<Event>

    @State private var title: String
    @State private var notes: String
    @State private var captureDate: Date
    @State private var selectedLovedOne: LovedOne?
    @State private var selectedEvent: Event?
    @State private var tagText: String = ""

    @State private var isSaving = false

    init(memory: Memory) {
        self.memory = memory
        _title = State(initialValue: memory.title ?? "")
        _notes = State(initialValue: memory.notes ?? "")
        _captureDate = State(initialValue: memory.captureDate ?? Date())
        _selectedLovedOne = State(initialValue: memory.lovedOne)
        _selectedEvent = State(initialValue: memory.linkedEvent)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    TextField("Title", text: $title)

                    DatePicker("Date", selection: $captureDate)

                    Picker("Person", selection: $selectedLovedOne) {
                        Text("None").tag(nil as LovedOne?)
                        ForEach(lovedOnes) { lovedOne in
                            Text(lovedOne.name ?? "Unknown").tag(lovedOne as LovedOne?)
                        }
                    }
                }

                Section("Notes") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 100)
                }

                Section("Tags") {
                    // Existing tags
                    if !memory.tagsArray.isEmpty {
                        FlowLayout(spacing: 8) {
                            ForEach(memory.tagsArray) { tag in
                                HStack(spacing: 4) {
                                    Text(tag.name ?? "")
                                    Button(action: { removeTag(tag) }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.caption)
                                    }
                                }
                                .font(themeManager.theme.captionFont)
                                .foregroundStyle(themeManager.theme.secondaryColor)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(themeManager.theme.secondaryColor.opacity(0.1))
                                .clipShape(Capsule())
                            }
                        }
                    }

                    // Add new tag
                    HStack {
                        TextField("Add tag", text: $tagText)
                            .textInputAutocapitalization(.never)

                        Button("Add") {
                            addTag()
                        }
                        .disabled(tagText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }

                Section("Link to Event") {
                    Picker("Event", selection: $selectedEvent) {
                        Text("None").tag(nil as Event?)
                        ForEach(filteredEvents) { event in
                            Text(event.title ?? "Event").tag(event as Event?)
                        }
                    }
                }
            }
            .navigationTitle("Edit Memory")
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
                    .disabled(isSaving)
                }
            }
        }
    }

    private var filteredEvents: [Event] {
        if let lovedOne = selectedLovedOne {
            return events.filter { $0.lovedOne == lovedOne }
        }
        return Array(events)
    }

    private func addTag() {
        let tagName = tagText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !tagName.isEmpty else { return }

        let tag = Tag.findOrCreate(name: tagName, in: viewContext)
        memory.addToTags(tag)
        tagText = ""
    }

    private func removeTag(_ tag: Tag) {
        memory.removeFromTags(tag)
    }

    private func save() {
        isSaving = true

        memory.title = title.isEmpty ? nil : title
        memory.notes = notes.isEmpty ? nil : notes
        memory.captureDate = captureDate
        memory.lovedOne = selectedLovedOne
        memory.linkedEvent = selectedEvent

        do {
            try viewContext.save()
            dismiss()
        } catch {
            print("Error saving memory: \(error)")
            isSaving = false
        }
    }
}

#Preview {
    EditMemoryView(memory: {
        let context = PersistenceController.preview.container.viewContext
        let memory = Memory(context: context)
        memory.id = UUID()
        memory.title = "First Steps"
        memory.type = MemoryType.photo.rawValue
        memory.captureDate = Date()
        return memory
    }())
    .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    .environmentObject(ThemeManager())
}
