import SwiftUI
import CoreData

struct EditEventView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    @ObservedObject var event: Event

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \LovedOne.name, ascending: true)],
        animation: .default
    )
    private var lovedOnes: FetchedResults<LovedOne>

    @State private var title: String
    @State private var eventType: EventType
    @State private var date: Date
    @State private var isAllDay: Bool
    @State private var notes: String
    @State private var selectedLovedOne: LovedOne?
    @State private var reminderOffset: ReminderOffset?

    @State private var isSaving = false

    init(event: Event) {
        self.event = event
        _title = State(initialValue: event.title ?? "")
        _eventType = State(initialValue: event.eventTypeValue)
        _date = State(initialValue: event.date ?? Date())
        _isAllDay = State(initialValue: event.isAllDay)
        _notes = State(initialValue: event.notes ?? "")
        _selectedLovedOne = State(initialValue: event.lovedOne)
        _reminderOffset = State(initialValue: event.reminderOffsetValue)
    }

    private var isValid: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Event Details") {
                    TextField("Title", text: $title)

                    Picker("Type", selection: $eventType) {
                        ForEach(EventType.allCases) { type in
                            Label(type.displayName, systemImage: type.icon)
                                .tag(type)
                        }
                    }

                    Toggle("All Day", isOn: $isAllDay)

                    if isAllDay {
                        DatePicker("Date", selection: $date, displayedComponents: .date)
                    } else {
                        DatePicker("Date & Time", selection: $date)
                    }

                    Picker("Person", selection: $selectedLovedOne) {
                        Text("None").tag(nil as LovedOne?)
                        ForEach(lovedOnes) { lovedOne in
                            Text(lovedOne.name ?? "Unknown").tag(lovedOne as LovedOne?)
                        }
                    }
                }

                Section("Reminder") {
                    Picker("Remind Me", selection: $reminderOffset) {
                        Text("No Reminder").tag(nil as ReminderOffset?)
                        ForEach(ReminderOffset.allCases) { offset in
                            Text(offset.displayName).tag(offset as ReminderOffset?)
                        }
                    }
                }

                Section("Notes") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 80)
                }
            }
            .navigationTitle("Edit Event")
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

    private func save() {
        guard isValid else { return }
        isSaving = true

        event.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        event.eventType = eventType.rawValue
        event.date = date
        event.isAllDay = isAllDay
        event.notes = notes.isEmpty ? nil : notes
        event.lovedOne = selectedLovedOne
        event.reminderOffset = reminderOffset?.rawValue

        do {
            try viewContext.save()
            dismiss()
        } catch {
            print("Error saving event: \(error)")
            isSaving = false
        }
    }
}

#Preview {
    EditEventView(event: {
        let context = PersistenceController.preview.container.viewContext
        let event = Event(context: context)
        event.id = UUID()
        event.title = "Emma's Birthday"
        event.eventType = EventType.birthday.rawValue
        event.date = Date()
        event.isAllDay = true
        return event
    }())
    .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    .environmentObject(ThemeManager())
}
