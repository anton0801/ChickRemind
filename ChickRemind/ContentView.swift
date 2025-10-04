import SwiftUI
import UserNotifications

// Model for Reminder
struct Reminder: Identifiable, Codable {
    let id: UUID
    var title: String
    var type: ReminderType
    var date: Date
    var repeatInterval: RepeatInterval
    var notes: String?
    var isCompleted: Bool = false
}

enum ReminderType: String, Codable, CaseIterable {
    case feeding = "Feeding"
    case cleaning = "Cleaning"
    case vaccination = "Vaccination"
    case other = "Other"
    
    var icon: String {
        switch self {
        case .feeding: return "custom.chicken.feeding"
        case .cleaning: return "custom.chicken.cleaning"
        case .vaccination: return "custom.chicken.vaccination"
        case .other: return "custom.chicken.other"
        }
    }
}

enum RepeatInterval: String, Codable, CaseIterable {
    case none = "None"
    case daily = "Daily"
    case weekly = "Weekly"
}

// Reminder Store
class ReminderStore: ObservableObject {
    @Published var reminders: [Reminder] = []
    
    init() {
        loadReminders()
    }
    
    func saveReminders() {
        if let encoded = try? JSONEncoder().encode(reminders) {
            UserDefaults.standard.set(encoded, forKey: "reminders")
        }
    }
    
    func loadReminders() {
        if let data = UserDefaults.standard.data(forKey: "reminders"),
           let decoded = try? JSONDecoder().decode([Reminder].self, from: data) {
            reminders = decoded
        }
    }
    
    func addReminder(_ reminder: Reminder) {
        reminders.append(reminder)
        saveReminders()
        scheduleNotification(for: reminder)
    }
    
    func updateReminder(_ reminder: Reminder) {
        if let index = reminders.firstIndex(where: { $0.id == reminder.id }) {
            reminders[index] = reminder
            saveReminders()
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [reminder.id.uuidString])
            scheduleNotification(for: reminder)
        }
    }
    
    func deleteReminder(_ reminder: Reminder) {
        reminders.removeAll { $0.id == reminder.id }
        saveReminders()
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [reminder.id.uuidString])
    }
    
    func completeReminder(_ reminder: Reminder) {
        if let index = reminders.firstIndex(where: { $0.id == reminder.id }) {
            reminders[index].isCompleted = true
            saveReminders()
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [reminder.id.uuidString])
        }
    }
    
    private func scheduleNotification(for reminder: Reminder) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                let content = UNMutableNotificationContent()
                content.title = "Cluck! It's time!"
                content.body = "Task: \(reminder.title)"
                content.sound = UNNotificationSound(named: UNNotificationSoundName(rawValue: "chicken.caf"))
                
                let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: reminder.date)
                let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: reminder.repeatInterval != .none)
                
                let request = UNNotificationRequest(identifier: reminder.id.uuidString, content: content, trigger: trigger)
                UNUserNotificationCenter.current().add(request)
            }
        }
    }
}

// Custom Colors
extension Color {
    static let backgroundStart = Color(hex: "#121212")
    static let backgroundEnd = Color(hex: "#1C2526")
    static let accent = Color(hex: "#FF8C42")
    static let accentBlue = Color(hex: "#42A5F5")
    static let accentGreen = Color(hex: "#66BB6A")
    static let primaryText = Color(hex: "#FFFFFF")
    static let secondaryText = Color(hex: "#AAAAAA")
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255, opacity: Double(a) / 255)
    }
}

// Custom Font
let titleFont = Font.custom("Inter-Bold", size: 24)
let bodyFont = Font.custom("Inter-Regular", size: 16)
let captionFont = Font.custom("Inter-Regular", size: 14)

// App Entry
@main
struct ChickRemindApp: App {
    @StateObject var reminderStore = ReminderStore()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(reminderStore)
                .preferredColorScheme(.dark)
        }
    }
}

struct ContentView: View {
    @AppStorage("isOnboarded") var isOnboarded: Bool = false
    
    var body: some View {
        if !isOnboarded {
            OnboardingView(isOnboarded: $isOnboarded)
        } else {
            MainTabView()
        }
    }
}

struct OnboardingView: View {
    @Binding var isOnboarded: Bool
    @State private var currentPage = 0
    
    var body: some View {
        ZStack {
            LinearGradient(gradient: Gradient(colors: [.backgroundStart, .backgroundEnd]), startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            
            VStack {
                TabView(selection: $currentPage) {
                    OnboardingSlide(title: "Never forget to care for your chickens", image: "custom.chicken.feeding", description: "Feeding time illustration")
                        .tag(0)
                    OnboardingSlide(title: "Automatic reminders", image: "custom.chicken.alarm", description: "Chicken with alarm clock")
                        .tag(1)
                    OnboardingSlide(title: "Keep your flock healthy", image: "custom.chicken.vaccination", description: "Chicken with medical kit")
                        .tag(2)
                }
                .tabViewStyle(PageTabViewStyle())
                .indexViewStyle(PageIndexViewStyle(backgroundDisplayMode: .always))
                
                Button(action: {
                    withAnimation(.spring()) {
                        if currentPage < 2 {
                            currentPage += 1
                        } else {
                            isOnboarded = true
                        }
                    }
                }) {
                    Text(currentPage < 2 ? "Next" : "Get Started")
                        .font(.custom("Inter-Bold", size: 18))
                        .foregroundColor(.primaryText)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(
                            ZStack {
                                RoundedRectangle(cornerRadius: 15)
                                    .fill(Color.accent)
                                RoundedRectangle(cornerRadius: 15)
                                    .stroke(Color.primaryText.opacity(0.3), lineWidth: 2)
                            }
                        )
                        .padding(.horizontal, 20)
                        .scaleEffect(currentPage < 2 ? 1.0 : 1.05)
                        .animation(.easeInOut(duration: 0.3), value: currentPage)
                }
                .padding(.bottom, 20)
            }
        }
    }
}

struct OnboardingSlide: View {
    let title: String
    let image: String
    let description: String
    @State private var isAnimating = false
    
    var body: some View {
        VStack(spacing: 20) {
            Image(image)
                .resizable()
                .scaledToFit()
                .frame(width: 150, height: 150)
                .foregroundColor(.primaryText)
                .rotationEffect(.degrees(isAnimating ? 15 : -15))
                .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: isAnimating)
                .onAppear { isAnimating = true }
            
            Text(title)
                .font(titleFont)
                .foregroundColor(.primaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Text(description)
                .font(bodyFont)
                .foregroundColor(.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding()
    }
}

struct MainTabView: View {
    var body: some View {
        TabView {
            DashboardView()
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }
            
            HistoryView()
                .tabItem {
                    Label("History", systemImage: "clock.arrow.circlepath")
                }
            
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
        }
        .accentColor(.accent)
        .background(
            LinearGradient(gradient: Gradient(colors: [.backgroundStart, .backgroundEnd]), startPoint: .top, endPoint: .bottom)
        )
    }
}

struct DashboardView: View {
    @EnvironmentObject var reminderStore: ReminderStore
    @State private var showingAddReminder = false
    @State private var searchText = ""
    
    var activeReminders: [Reminder] {
        let active = reminderStore.reminders.filter { !$0.isCompleted && $0.date > Date() }
        if searchText.isEmpty {
            return active
        } else {
            return active.filter {
                $0.title.lowercased().contains(searchText.lowercased()) ||
                ($0.notes?.lowercased().contains(searchText.lowercased()) ?? false)
            }
        }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                LinearGradient(gradient: Gradient(colors: [.backgroundStart, .backgroundEnd]), startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()
                
                VStack {
                    Text("Your Reminders")
                        .font(titleFont)
                        .foregroundColor(.primaryText)
                        .padding(.top, 20)
                    
                    TextField("Search tasks...", text: $searchText)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.backgroundEnd.opacity(0.8))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(Color.accent.opacity(0.5), lineWidth: 1)
                                )
                        )
                        .padding(.horizontal)
                        .foregroundColor(.primaryText)
                        .font(bodyFont)
                    
                    if activeReminders.isEmpty {
                        
                        Spacer()
                        
                        VStack(spacing: 20) {
                            Image("custom.chicken.other")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 120, height: 120)
                                .foregroundColor(.primaryText)
                                .scaleEffect(searchText.isEmpty ? 1.05 : 1.0)
                                .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: searchText.isEmpty)
                            
                            Text(searchText.isEmpty ? "No reminders yet!" : "No matching reminders found")
                                .font(titleFont)
                                .foregroundColor(.primaryText)
                            
                            Text(searchText.isEmpty ? "Add your first task to get started!" : "Try a different search term.")
                                .font(bodyFont)
                                .foregroundColor(.secondaryText)
                                .multilineTextAlignment(.center)
                            
                            Button(action: {
                                showingAddReminder = true
                            }) {
                                HStack {
                                    Image(systemName: "plus")
                                    Text("Add First Task")
                                }
                                .font(.custom("Inter-Bold", size: 18))
                                .foregroundColor(.primaryText)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 15)
                                            .fill(Color.accent)
                                        RoundedRectangle(cornerRadius: 15)
                                            .stroke(Color.primaryText.opacity(0.3), lineWidth: 2)
                                    }
                                )
                                .padding(.horizontal)
                            }
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 15)
                                .fill(Color.backgroundEnd.opacity(0.9))
                                .shadow(color: .black.opacity(0.2), radius: 5)
                        )
                        .padding(.horizontal)
                        Spacer()
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 15) {
                                ForEach(activeReminders) { reminder in
                                    ReminderCard(reminder: reminder)
                                        .swipeActions {
                                            Button("Delete") {
                                                withAnimation(.spring()) {
                                                    reminderStore.deleteReminder(reminder)
                                                }
                                            }
                                            .tint(.red)
                                            
                                            Button("Edit") {
                                                // Add edit functionality
                                            }
                                            .tint(.blue)
                                        }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    
                    if !activeReminders.isEmpty {
                        Button(action: {
                            showingAddReminder = true
                        }) {
                            HStack {
                                Image(systemName: "plus")
                                Text("Add Reminder")
                            }
                            .font(.custom("Inter-Bold", size: 18))
                            .foregroundColor(.primaryText)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(
                                ZStack {
                                    RoundedRectangle(cornerRadius: 15)
                                        .fill(Color.accent)
                                    RoundedRectangle(cornerRadius: 15)
                                        .stroke(Color.primaryText.opacity(0.3), lineWidth: 2)
                                }
                            )
                            .padding(.horizontal)
                            .scaleEffect(showingAddReminder ? 0.95 : 1.0)
                            .animation(.spring(), value: showingAddReminder)
                        }
                        .padding(.bottom, 20)
                    }
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showingAddReminder) {
                AddReminderView()
            }
        }
    }
}

struct ReminderCard: View {
    let reminder: Reminder
    @EnvironmentObject var reminderStore: ReminderStore
    @State private var isAnimating = false
    
    var body: some View {
        HStack(spacing: 15) {
            Image(reminder.type.icon)
                .resizable()
                .scaledToFit()
                .frame(width: 50, height: 50)
                .foregroundColor(.primaryText)
                .rotationEffect(.degrees(isAnimating ? 15 : 0))
                .animation(.easeInOut(duration: 0.5), value: isAnimating)
                .onAppear {
                    isAnimating = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        isAnimating = false
                    }
                }
            
            VStack(alignment: .leading, spacing: 5) {
                Text(reminder.title)
                    .font(bodyFont)
                    .foregroundColor(.primaryText)
                
                Text(reminder.date, style: .date)
                    .font(captionFont)
                    .foregroundColor(.secondaryText)
                
                if let notes = reminder.notes, !notes.isEmpty {
                    Text(notes)
                        .font(captionFont)
                        .foregroundColor(.secondaryText)
                        .lineLimit(2)
                }
            }
            
            Spacer()
            
            Button(action: {
                withAnimation(.spring()) {
                    reminderStore.completeReminder(reminder)
                }
            }) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.accent)
                    .scaleEffect(isAnimating ? 1.2 : 1.0)
                    .animation(.spring(), value: isAnimating)
            }
        }
        .padding()
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 15)
                    .fill(Color.backgroundEnd.opacity(0.8))
                RoundedRectangle(cornerRadius: 15)
                    .stroke(Color.accent.opacity(0.3), lineWidth: 1)
            }
        )
        .shadow(color: .black.opacity(0.2), radius: 5, x: 0, y: 2)
        .padding(.horizontal, 5)
    }
}


struct AddReminderView: View {
    @EnvironmentObject var reminderStore: ReminderStore
    @Environment(\.dismiss) var dismiss
    
    @State private var title = ""
    @State private var type: ReminderType = .feeding
    @State private var date = Date()
    @State private var repeatInterval: RepeatInterval = .none
    @State private var notes = ""
    @State private var isAnimating = false
    
    var body: some View {
        NavigationView {
            ZStack {
                LinearGradient(gradient: Gradient(colors: [.backgroundStart, .backgroundEnd]), startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Header with animated chicken
                        VStack(spacing: 10) {
                            Image("custom.chicken.other")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 80, height: 80)
                                .foregroundColor(.primaryText)
                                .rotationEffect(.degrees(isAnimating ? 15 : -15))
                                .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: isAnimating)
                                .onAppear { isAnimating = true }
                            
                            Text("New Reminder")
                                .font(titleFont)
                                .foregroundColor(.primaryText)
                        }
                        .padding(.top, 20)
                        
                        // Form Card
                        VStack(alignment: .leading, spacing: 15) {
                            FormFieldView(
                                icon: "pencil",
                                placeholder: "Title",
                                content: AnyView(
                                    TextField("Title", text: $title)
                                )
                            )
                            
                            FormFieldView(
                                icon: "list.bullet",
                                placeholder: nil,
                                content: AnyView(
                                    Picker("Task Type", selection: $type) {
                                        ForEach(ReminderType.allCases, id: \.rawValue) { type in
                                            HStack {
                                                Image(type.icon)
                                                    .resizable()
                                                    .scaledToFit()
                                                    .frame(width: 24, height: 24)
                                                Text(type.rawValue)
                                            }
                                        }
                                    }
                                    .pickerStyle(.menu)
                                )
                            )
                            
                            FormFieldView(
                                icon: "calendar",
                                placeholder: nil,
                                content: AnyView(
                                    DatePicker("Date & Time", selection: $date)
                                )
                            )
                            
                            FormFieldView(
                                icon: "repeat",
                                placeholder: nil,
                                content: AnyView(
                                    Picker("Repeat", selection: $repeatInterval) {
                                        ForEach(RepeatInterval.allCases, id: \.rawValue) { interval in
                                            Text(interval.rawValue)
                                        }
                                    }
                                    .pickerStyle(.segmented)
                                )
                            )
                            
                            FormFieldView(
                                icon: "note.text",
                                placeholder: "Notes (optional)",
                                content: AnyView(
                                    TextField("Notes (optional)", text: $notes)
                                )
                            )
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 15)
                                .fill(Color.backgroundEnd.opacity(0.9))
                                .shadow(color: .black.opacity(0.2), radius: 5)
                        )
                        .padding(.horizontal)
                        
                        // Buttons
                        FormButtonsView(
                            onCancel: {
                                dismiss()
                            },
                            onSave: {
                                let newReminder = Reminder(id: UUID(), title: title, type: type, date: date, repeatInterval: repeatInterval, notes: notes)
                                reminderStore.addReminder(newReminder)
                                dismiss()
                            }
                        )
                    }
                }
                .navigationBarHidden(true)
            }
        }
    }
    
}

struct FormFieldView: View {
    let icon: String
    let placeholder: String?
    let content: AnyView
    
    @AppStorage("accentColor") var accentColor: String = "orange"
    
    var currentAccent: Color {
        switch accentColor {
        case "blue": return .accentBlue
        case "green": return .accentGreen
        default: return .accent
        }
    }
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.secondaryText)
            content
                .foregroundColor(.primaryText)
                .font(bodyFont)
                .padding(.vertical, 10)
                .padding(.horizontal)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.backgroundEnd.opacity(0.8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(currentAccent.opacity(0.5), lineWidth: 1)
                        )
                )
        }
    }
}

struct FormButtonsView: View {
    let onCancel: () -> Void
    let onSave: () -> Void
    @State private var isAnimating = false
    
    @AppStorage("accentColor") var accentColor: String = "orange"
    
    var currentAccent: Color {
        switch accentColor {
        case "blue": return .accentBlue
        case "green": return .accentGreen
        default: return .accent
        }
    }
    
    var body: some View {
        HStack(spacing: 15) {
            Button(action: {
                withAnimation(.spring()) {
                    onCancel()
                }
            }) {
                Text("Cancel")
                    .font(.custom("Inter-Bold", size: 18))
                    .foregroundColor(.primaryText)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 15)
                            .fill(Color.backgroundEnd.opacity(0.8))
                            .overlay(
                                RoundedRectangle(cornerRadius: 15)
                                    .stroke(Color.primaryText.opacity(0.5), lineWidth: 2)
                            )
                    )
                    .scaleEffect(isAnimating ? 0.95 : 1.0)
                    .animation(.spring(), value: isAnimating)
            }
            
            Button(action: {
                withAnimation(.spring()) {
                    isAnimating = true
                    onSave()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        isAnimating = false
                    }
                }
            }) {
                Text("Save")
                    .font(.custom("Inter-Bold", size: 18))
                    .foregroundColor(.primaryText)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(
                        ZStack {
                            RoundedRectangle(cornerRadius: 15)
                                .fill(currentAccent)
                            RoundedRectangle(cornerRadius: 15)
                                .stroke(Color.primaryText.opacity(0.3), lineWidth: 2)
                        }
                    )
                    .scaleEffect(isAnimating ? 0.95 : 1.0)
                    .animation(.spring(), value: isAnimating)
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 20)
    }
}

struct HistoryView: View {
    @EnvironmentObject var reminderStore: ReminderStore
    @State private var filterType: ReminderType? = nil
    
    var filteredReminders: [Reminder] {
        let completed = reminderStore.reminders.filter { $0.isCompleted }
        if let filter = filterType {
            return completed.filter { $0.type == filter }
        }
        return completed
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                LinearGradient(gradient: Gradient(colors: [.backgroundStart, .backgroundEnd]), startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()
                
                VStack {
                    Picker("Filter by Type", selection: $filterType) {
                        Text("All").tag(ReminderType?.none)
                        ForEach(ReminderType.allCases, id: \.rawValue) { type in
                            Text(type.rawValue).tag(ReminderType?.some(type))
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    
                    if filteredReminders.isEmpty {
                        Spacer()
                        VStack(spacing: 20) {
                            Image("custom.chicken.other")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 120, height: 120)
                                .foregroundColor(.primaryText)
                                .scaleEffect(1.05)
                                .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: true)
                            
                            Text("No completed tasks yet!")
                                .font(titleFont)
                                .foregroundColor(.primaryText)
                            
                            Text("Complete a task to see it here.")
                                .font(bodyFont)
                                .foregroundColor(.secondaryText)
                                .multilineTextAlignment(.center)
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 15)
                                .fill(Color.backgroundEnd.opacity(0.9))
                                .shadow(color: .black.opacity(0.2), radius: 5)
                        )
                        .padding(.horizontal)
                        Spacer()
                    } else {
                        List(filteredReminders) { reminder in
                            HStack {
                                Image(reminder.type.icon)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 40, height: 40)
                                    .foregroundColor(.primaryText)
                                
                                VStack(alignment: .leading) {
                                    Text(reminder.title)
                                        .font(bodyFont)
                                        .foregroundColor(.primaryText)
                                    
                                    Text(reminder.date, style: .date)
                                        .font(captionFont)
                                        .foregroundColor(.secondaryText)
                                }
                                
                                Spacer()
                                
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.backgroundEnd.opacity(0.8))
                                    .shadow(color: .black.opacity(0.2), radius: 5, x: 0, y: 2)
                            )
                        }
                        
                    }
                }
                .navigationTitle("History")
            }
        }
    }
}

struct SettingsView: View {
    @AppStorage("soundEnabled") var soundEnabled: Bool = true
    @AppStorage("vibrationEnabled") var vibrationEnabled: Bool = true
    @AppStorage("accentColor") var accentColor: String = "orange"
    @AppStorage("notificationWindow") var notificationWindow: Int = 15
    @State private var selectedSound = "Default"
    @State private var isAnimating = false
    
    var currentAccent: Color {
        switch accentColor {
        case "blue": return .accentBlue
        case "green": return .accentGreen
        default: return .accent
        }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                LinearGradient(gradient: Gradient(colors: [.backgroundStart, .backgroundEnd]), startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Notifications Section
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Image(systemName: "bell.fill")
                                    .foregroundColor(currentAccent)
                                Text("Notifications")
                                    .font(.custom("Inter-Bold", size: 18))
                                    .foregroundColor(.primaryText)
                            }
                            
                            Toggle(isOn: $soundEnabled.animation(.spring())) {
                                HStack {
                                    Image(systemName: "speaker.wave.2.fill")
                                        .foregroundColor(.secondaryText)
                                    Text("Sound")
                                        .foregroundColor(.primaryText)
                                        .font(bodyFont)
                                }
                            }
                            .padding(.vertical, 5)
                            .scaleEffect(soundEnabled && isAnimating ? 1.05 : 1.0)
                            .onChange(of: soundEnabled) { _ in
                                withAnimation(.spring()) { isAnimating = true }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { isAnimating = false }
                            }
                            
                            Picker("Sound Type", selection: $selectedSound) {
                                Text("Default").tag("Default")
                                Text("Chicken Cluck").tag("Chicken")
                            }
                            .pickerStyle(.menu)
                            .foregroundColor(.primaryText)
                            .font(bodyFont)
                            .padding(.vertical, 5)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.backgroundEnd.opacity(0.8))
                                    .shadow(color: .black.opacity(0.2), radius: 5)
                            )
                            
                            Toggle(isOn: $vibrationEnabled.animation(.spring())) {
                                HStack {
                                    Image(systemName: "waveform.path")
                                        .foregroundColor(.secondaryText)
                                    Text("Vibration")
                                        .foregroundColor(.primaryText)
                                        .font(bodyFont)
                                }
                            }
                            .padding(.vertical, 5)
                            .scaleEffect(vibrationEnabled && isAnimating ? 1.05 : 1.0)
                            .onChange(of: vibrationEnabled) { _ in
                                withAnimation(.spring()) { isAnimating = true }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { isAnimating = false }
                            }
                            
                            HStack {
                                Image(systemName: "clock.fill")
                                    .foregroundColor(.secondaryText)
                                Text("Notification Window")
                                    .foregroundColor(.primaryText)
                                    .font(bodyFont)
                                Spacer()
                                Picker("Minutes", selection: $notificationWindow) {
                                    Text("5 min").tag(5)
                                    Text("15 min").tag(15)
                                    Text("30 min").tag(30)
                                    Text("60 min").tag(60)
                                }
                                .pickerStyle(.menu)
                                .foregroundColor(.primaryText)
                            }
                            .padding(.vertical, 5)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.backgroundEnd.opacity(0.8))
                                    .shadow(color: .black.opacity(0.2), radius: 5)
                            )
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 15)
                                .fill(Color.backgroundEnd.opacity(0.9))
                                .shadow(color: .black.opacity(0.2), radius: 5)
                        )
                        .padding(.horizontal)
                        
                        // Appearance Section
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Image(systemName: "paintpalette.fill")
                                    .foregroundColor(currentAccent)
                                Text("Appearance")
                                    .font(.custom("Inter-Bold", size: 18))
                                    .foregroundColor(.primaryText)
                            }
                            
                            HStack {
                                Image(systemName: "circle.fill")
                                    .foregroundColor(.secondaryText)
                                Text("Accent Color")
                                    .foregroundColor(.primaryText)
                                    .font(bodyFont)
                                Spacer()
                                Picker("Accent Color", selection: $accentColor) {
                                    Text("Orange").tag("orange")
                                    Text("Blue").tag("blue")
                                    Text("Green").tag("green")
                                }
                                .pickerStyle(.menu)
                                .foregroundColor(.primaryText)
                            }
                            .padding(.vertical, 5)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.backgroundEnd.opacity(0.8))
                                    .shadow(color: .black.opacity(0.2), radius: 5)
                            )
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 15)
                                .fill(Color.backgroundEnd.opacity(0.9))
                                .shadow(color: .black.opacity(0.2), radius: 5)
                        )
                        .padding(.horizontal)
                    }
                    .padding(.top, 20)
                }
                .navigationTitle("Settings")
                
            }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(ReminderStore())
        .preferredColorScheme(.dark)
}
