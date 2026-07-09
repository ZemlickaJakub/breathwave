import SwiftUI
import FamilyControls

/// Mindful Pause: choose distracting apps and guard them behind a breath.
/// Opening a guarded app shows a pause instead of the app right away.
struct FocusView: View {
    @Environment(FocusGuardService.self) private var focus
    @State private var pickerPresented = false

    var body: some View {
        @Bindable var focus = focus
        VStack(spacing: 28) {
            Spacer()
            Image(systemName: "hand.raised.fill")
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(.tint)
            Text("A breath before the scroll")
                .font(.title2.weight(.semibold))
                .multilineTextAlignment(.center)
            Text("Pick the apps that pull you in. When you open one, Breathwave asks you to pause and breathe first.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)

            content(focus: focus)
            Spacer()
        }
        .padding()
        .calmBackground()
        .navigationTitle("Mindful Pause")
        .navigationBarTitleDisplayMode(.inline)
        .familyActivityPicker(isPresented: $pickerPresented, selection: $focus.selection)
        .task { focus.refreshAuthorization() }
    }

    @ViewBuilder
    private func content(focus: FocusGuardService) -> some View {
        switch focus.authorization {
        case .approved:
            configured(focus: focus)
        case .denied:
            Text("Screen Time access is off. Turn it on in Settings › Screen Time to use Mindful Pause.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        case .undetermined:
            Button {
                Task { await focus.requestAuthorization() }
            } label: {
                Text("Get Started").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.horizontal, 40)
        }
    }

    @ViewBuilder
    private func configured(focus: FocusGuardService) -> some View {
        VStack(spacing: 16) {
            Button {
                pickerPresented = true
            } label: {
                Label(
                    focus.hasSelection ? "Edit chosen apps" : "Choose apps to pause",
                    systemImage: "apps.iphone"
                )
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)

            if focus.hasSelection {
                Button {
                    focus.isGuarding ? focus.stopGuarding() : focus.startGuarding()
                } label: {
                    Text(focus.isGuarding ? "Pause is on — turn off" : "Turn on the pause")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(focus.isGuarding ? .secondary : .accentColor)
            }
        }
        .padding(.horizontal, 40)
    }
}

#Preview {
    NavigationStack {
        FocusView()
    }
    .environment(FocusGuardService())
}
