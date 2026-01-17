import SwiftUI

struct ContentView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @State private var selectedTab: Tab = .home

    enum Tab: String, CaseIterable {
        case home = "Home"
        case lovedOnes = "Loved Ones"
        case timeline = "Timeline"
        case events = "Events"
        case settings = "Settings"

        var icon: String {
            switch self {
            case .home: return "house.fill"
            case .lovedOnes: return "person.2.fill"
            case .timeline: return "clock.fill"
            case .events: return "calendar"
            case .settings: return "gearshape.fill"
            }
        }
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem {
                    Label(Tab.home.rawValue, systemImage: Tab.home.icon)
                }
                .tag(Tab.home)

            LovedOnesView()
                .tabItem {
                    Label(Tab.lovedOnes.rawValue, systemImage: Tab.lovedOnes.icon)
                }
                .tag(Tab.lovedOnes)

            TimelineView()
                .tabItem {
                    Label(Tab.timeline.rawValue, systemImage: Tab.timeline.icon)
                }
                .tag(Tab.timeline)

            EventsView()
                .tabItem {
                    Label(Tab.events.rawValue, systemImage: Tab.events.icon)
                }
                .tag(Tab.events)

            SettingsView()
                .tabItem {
                    Label(Tab.settings.rawValue, systemImage: Tab.settings.icon)
                }
                .tag(Tab.settings)
        }
        .tint(themeManager.theme.primaryColor)
    }
}

#Preview {
    ContentView()
        .environmentObject(ThemeManager())
}
