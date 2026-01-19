import SwiftUI
import CoreData

/// A NavigationLink wrapper that safely handles Memory objects that may become
/// inaccessible due to CloudKit sync deletions.
///
/// When a memory is deleted on another device, CloudKit syncs that deletion to
/// this device. The UI may still hold references to the Memory object, but
/// accessing its properties would crash the app with NSObjectInaccessibleException.
///
/// SafeMemoryNavigationLink checks `isAccessible` before navigating and shows
/// an alert if the memory is no longer available.
struct SafeMemoryNavigationLink<Label: View>: View {
    let memory: Memory
    let destination: () -> MemoryDetailView
    let label: Label

    @State private var showingUnavailableAlert = false
    @State private var isNavigating = false

    init(
        memory: Memory,
        @ViewBuilder label: () -> Label
    ) {
        self.memory = memory
        self.destination = { MemoryDetailView(memory: memory) }
        self.label = label()
    }

    var body: some View {
        Button {
            if memory.isAccessible {
                isNavigating = true
            } else {
                showingUnavailableAlert = true
            }
        } label: {
            label
        }
        .buttonStyle(.plain)
        .navigationDestination(isPresented: $isNavigating) {
            if memory.isAccessible {
                destination()
            } else {
                ContentUnavailableView(
                    "Memory Unavailable",
                    systemImage: "exclamationmark.icloud",
                    description: Text("This memory was deleted or is not available on this device.")
                )
            }
        }
        .alert("Memory Unavailable", isPresented: $showingUnavailableAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("This memory was deleted or is not available on this device.")
        }
    }
}

/// A wrapper view for displaying memory content only when the memory is accessible.
/// Use this for inline content (not navigation) where the memory might become unavailable.
struct SafeMemoryView<Content: View>: View {
    @ObservedObject var memory: Memory
    let content: () -> Content

    init(memory: Memory, @ViewBuilder content: @escaping () -> Content) {
        self.memory = memory
        self.content = content
    }

    var body: some View {
        if memory.isAccessible {
            content()
        }
        // If not accessible, renders nothing - the view disappears gracefully
    }
}

#Preview {
    NavigationStack {
        VStack {
            Text("Safe Memory Navigation Demo")
        }
    }
}
