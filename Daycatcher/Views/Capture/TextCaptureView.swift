import SwiftUI

/// TextCaptureView allows users to create text-based memory notes.
struct TextCaptureView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss

    let lovedOne: LovedOne?
    let onCapture: (String, String?) -> Void // (content, title)

    @State private var title = ""
    @State private var content = ""
    @FocusState private var focusedField: Field?

    enum Field {
        case title, content
    }

    private var canSave: Bool {
        !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: themeManager.theme.spacingMedium) {
                    // Loved one context
                    if let lovedOne = lovedOne {
                        HStack(spacing: themeManager.theme.spacingSmall) {
                            Image(systemName: "person.fill")
                                .foregroundStyle(themeManager.theme.primaryColor)
                            Text("For \(lovedOne.name ?? "your loved one")")
                                .font(themeManager.theme.bodyFont)
                                .foregroundStyle(themeManager.theme.textSecondary)
                        }
                        .padding(.horizontal)
                    }

                    // Title field
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Title (optional)")
                            .font(themeManager.theme.captionFont)
                            .foregroundStyle(themeManager.theme.textSecondary)
                            .padding(.horizontal)

                        TextField("Give this memory a title...", text: $title)
                            .font(themeManager.theme.headlineFont)
                            .padding()
                            .background(themeManager.theme.surfaceColor)
                            .clipShape(RoundedRectangle(cornerRadius: themeManager.theme.cornerRadiusSmall))
                            .focused($focusedField, equals: .title)
                            .padding(.horizontal)
                    }

                    // Content field
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Note")
                                .font(themeManager.theme.captionFont)
                                .foregroundStyle(themeManager.theme.textSecondary)

                            Spacer()

                            Text("\(content.count) characters")
                                .font(themeManager.theme.captionFont)
                                .foregroundStyle(themeManager.theme.textSecondary)
                        }
                        .padding(.horizontal)

                        TextEditor(text: $content)
                            .font(themeManager.theme.bodyFont)
                            .foregroundStyle(themeManager.theme.textPrimary)
                            .scrollContentBackground(.hidden)
                            .padding()
                            .frame(minHeight: 200)
                            .background(themeManager.theme.surfaceColor)
                            .clipShape(RoundedRectangle(cornerRadius: themeManager.theme.cornerRadiusSmall))
                            .focused($focusedField, equals: .content)
                            .padding(.horizontal)
                    }

                    // Writing prompts
                    if content.isEmpty {
                        promptsSection
                    }
                }
                .padding(.vertical)
            }
            .background(themeManager.theme.backgroundColor)
            .navigationTitle("Add Note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
                        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
                        onCapture(trimmedContent, trimmedTitle.isEmpty ? nil : trimmedTitle)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(!canSave)
                }

                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        focusedField = nil
                    }
                }
            }
            .onAppear {
                focusedField = .content
            }
        }
    }

    // MARK: - Writing Prompts

    private var promptsSection: some View {
        VStack(alignment: .leading, spacing: themeManager.theme.spacingMedium) {
            Text("Need inspiration?")
                .font(themeManager.theme.captionFont)
                .foregroundStyle(themeManager.theme.textSecondary)
                .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: themeManager.theme.spacingSmall) {
                    ForEach(prompts, id: \.self) { prompt in
                        promptChip(prompt)
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    private func promptChip(_ prompt: String) -> some View {
        Button {
            content = prompt + " "
            focusedField = .content
        } label: {
            Text(prompt)
                .font(themeManager.theme.captionFont)
                .foregroundStyle(themeManager.theme.textPrimary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(themeManager.theme.surfaceColor)
                .clipShape(Capsule())
        }
    }

    private var prompts: [String] {
        if let lovedOne = lovedOne {
            let name = lovedOne.name ?? "They"
            return [
                "Today \(name) said something funny:",
                "\(name) made me smile when",
                "I want to remember how \(name)",
                "Something special about today:",
                "\(name)'s latest milestone:",
                "A moment I don't want to forget:"
            ]
        } else {
            return [
                "Today something special happened:",
                "I want to remember this moment:",
                "A funny thing that happened:",
                "Today I'm grateful for:",
                "A milestone worth remembering:",
                "Something that made me smile:"
            ]
        }
    }
}

#Preview {
    TextCaptureView(lovedOne: nil) { _, _ in }
        .environmentObject(ThemeManager())
}
