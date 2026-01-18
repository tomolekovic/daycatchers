import SwiftUI
import CoreData

struct AddEventView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \LovedOne.name, ascending: true)],
        animation: .default
    )
    private var lovedOnes: FetchedResults<LovedOne>

    @State private var title = ""
    @State private var eventType: EventType = .custom
    @State private var date = Date()
    @State private var isAllDay = true
    @State private var notes = ""
    @State private var selectedLovedOne: LovedOne?
    @State private var reminderOffset: ReminderOffset? = .oneDay

    @State private var isSaving = false

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
            .navigationTitle("Add Event")
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
            .onChange(of: eventType) { _, newValue in
                // Auto-fill title based on type
                if title.isEmpty {
                    switch newValue {
                    case .birthday:
                        if let name = selectedLovedOne?.name {
                            title = "\(name)'s Birthday"
                        }
                    case .anniversary:
                        title = "Anniversary"
                    default:
                        break
                    }
                }
            }
            .onChange(of: selectedLovedOne) { _, newValue in
                // Update title if birthday
                if eventType == .birthday, let name = newValue?.name {
                    title = "\(name)'s Birthday"
                }
            }
        }
    }

    private func save() {
        guard isValid else { return }
        isSaving = true

        let event = Event(context: viewContext)
        event.id = UUID()
        event.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        event.eventType = eventType.rawValue
        event.date = date
        event.isAllDay = isAllDay
        event.notes = notes.isEmpty ? nil : notes
        event.lovedOne = selectedLovedOne
        event.reminderOffset = reminderOffset?.rawValue
        event.createdAt = Date()

        do {
            try viewContext.save()

            // Schedule notification if reminder is set
            if let offset = reminderOffset {
                scheduleReminder(for: event, offset: offset)
            }

            dismiss()
        } catch {
            print("Error saving event: \(error)")
            isSaving = false
        }
    }

    private func scheduleReminder(for event: Event, offset: ReminderOffset) {
        Task {
            // Request authorization if not determined
            if NotificationManager.shared.needsAuthorizationRequest {
                let granted = await NotificationManager.shared.requestAuthorization()
                if !granted {
                    print("Notification permission not granted")
                    return
                }
            }

            // Check if authorized
            guard NotificationManager.shared.isAuthorized else {
                print("Notifications not authorized")
                return
            }

            // Schedule the notification
            await NotificationManager.shared.scheduleNotification(for: event)
        }
    }
}

#Preview {
    AddEventView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
        .environmentObject(ThemeManager())
}
