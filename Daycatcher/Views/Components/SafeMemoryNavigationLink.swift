import SwiftUI
import CoreData

/// A NavigationLink wrapper that safely handles Memory objects that may become
/// inaccessible due to CloudKit sync deletions.
///
/// When a memory is deleted on another device, CloudKit syncs that deletion to
/// this device. The UI may still hold references to the Memory object, but
/// accessing its properties would crash the app with NSObjectInaccessibleException.
///
/// SafeMemoryNavigationLink checks `isAccessible` before triggering navigation
/// via a callback, and shows an alert if the memory is no longer available.
///
/// IMPORTANT: The parent view must add `.navigationDestination(item:)` outside
/// any lazy containers (LazyVGrid, LazyVStack, etc.) to handle the navigation.
struct SafeMemoryNavigationLink<Label: View>: View {
    let memory: Memory
    let onSelect: (Memory) -> Void
    let label: Label

    @State private var showingUnavailableAlert = false

    init(
        memory: Memory,
        onSelect: @escaping (Memory) -> Void,
        @ViewBuilder label: () -> Label
    ) {
        self.memory = memory
        self.onSelect = onSelect
        self.label = label()
    }

    var body: some View {
        Button {
            if memory.isAccessible {
                onSelect(memory)
            } else {
                showingUnavailableAlert = true
            }
        } label: {
            label
        }
        .buttonStyle(.plain)
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
