import SwiftUI
import WebKit
import Network
import UserNotifications
import FirebaseMessaging
import AppsFlyerLib
import FirebaseCore
import UserNotifications
import AppTrackingTransparency

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
    @UIApplicationDelegateAdaptor(ApplicationDelegate.self) var delegateSelf
    
    var body: some Scene {
        WindowGroup {
            LaunchView()
                .environmentObject(reminderStore)
                .preferredColorScheme(.dark)
        }
    }
}


class ApplicationDelegate: UIResponder, UIApplicationDelegate, AppsFlyerLibDelegate, MessagingDelegate, UNUserNotificationCenterDelegate {
    
    private var conversionData: [AnyHashable: Any] = [:]
    
    
    // Notification handling
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let payload = response.notification.request.content.userInfo
        processNotifPayload(payload)
        completionHandler()
    }
    
    func application(_ application: UIApplication,
                     didReceiveRemoteNotification userInfo: [AnyHashable : Any],
                     fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        processNotifPayload(userInfo)
        completionHandler(.newData)
    }
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        let payload = notification.request.content.userInfo
        processNotifPayload(payload)
        completionHandler([.banner, .sound])
    }
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        FirebaseApp.configure()
        
        // Messaging setup
        Messaging.messaging().delegate = self
        UNUserNotificationCenter.current().delegate = self
        application.registerForRemoteNotifications()
        
        
        AppsFlyerLib.shared().appsFlyerDevKey = "gJWZYZaT564jDLLzjJSWyZ"
        AppsFlyerLib.shared().appleAppID = "6753625490"
        AppsFlyerLib.shared().delegate = self
        AppsFlyerLib.shared().start()
        
        if let notifPayload = launchOptions?[.remoteNotification] as? [AnyHashable: Any] {
            processNotifPayload(notifPayload)
        }
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(activateTracking),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
        
        return true
    }
    
    // AppsFlyer callbacks
    func onConversionDataSuccess(_ data: [AnyHashable: Any]) {
        conversionData = data
        NotificationCenter.default.post(name: Notification.Name("ConversionDataReceived"), object: nil, userInfo: ["conversionData": conversionData])
    }
    
    
    @objc private func activateTracking() {
        AppsFlyerLib.shared().start()
        if #available(iOS 14, *) {
            ATTrackingManager.requestTrackingAuthorization { _ in
            }
        }
    }
    
    func onConversionDataFail(_ error: Error) {
        NotificationCenter.default.post(name: Notification.Name("ConversionDataReceived"), object: nil, userInfo: ["conversionData": [:]])
    }
    
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        messaging.token { token, err in
            if let _ = err {
            }
            UserDefaults.standard.set(token, forKey: "fcm_token")
        }
    }
    
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Messaging.messaging().apnsToken = deviceToken
    }
    
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
    }
    
}

extension ApplicationDelegate {
    
    
    private func processNotifPayload(_ payload: [AnyHashable: Any]) {
        var linkStr: String?
        if let link = payload["url"] as? String {
            linkStr = link
        } else if let info = payload["data"] as? [String: Any], let link = info["url"] as? String {
            linkStr = link
        }
        
        if let linkStr = linkStr {
            UserDefaults.standard.set(linkStr, forKey: "temp_url")
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                NotificationCenter.default.post(name: NSNotification.Name("LoadTempURL"), object: nil, userInfo: ["tempUrl": linkStr])
            }
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



//#Preview {
//    ContentView()
//        .environmentObject(ReminderStore())
//        .preferredColorScheme(.dark)
//}


class OrbitNavigator: NSObject, WKNavigationDelegate, WKUIDelegate {
    private let orbitCore: OrbitCore
    
    private var bounceCounter: Int = 0
    private let bounceCap: Int = 70
    private var stablePoint: URL?

    func webView(_ webView: WKWebView, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        let authZone = challenge.protectionSpace
        if authZone.authenticationMethod == NSURLAuthenticationMethodServerTrust {
            if let trustRoot = authZone.serverTrust {
                let passKey = URLCredential(trust: trustRoot)
                completionHandler(.useCredential, passKey)
            } else {
                completionHandler(.performDefaultHandling, nil)
            }
        } else {
            completionHandler(.performDefaultHandling, nil)
        }
    }
    
    private func storeOrbitData(from bubble: WKWebView) {
        bubble.configuration.websiteDataStore.httpCookieStore.getAllCookies { items in
            var domainVault: [String: [String: [HTTPCookiePropertyKey: Any]]] = [:]
            items.forEach { item in
                var domainBin = domainVault[item.domain] ?? [:]
                domainBin[item.name] = item.properties as? [HTTPCookiePropertyKey: Any]
                domainVault[item.domain] = domainBin
            }
            UserDefaults.standard.set(domainVault, forKey: "orbit_vault")
        }
    }
    
    init(core: OrbitCore) {
        self.orbitCore = core
        super.init()
    }
    
    func webView(
        _ webView: WKWebView,
        createWebViewWith configuration: WKWebViewConfiguration,
        for navigationAction: WKNavigationAction,
        windowFeatures: WKWindowFeatures
    ) -> WKWebView? {
        guard navigationAction.targetFrame == nil else {
            return nil
        }
        
        let newBubble = BubbleForge.createMainBubble(using: configuration)
        prepareBubble(newBubble)
        anchorBubble(newBubble)
        
        orbitCore.extraBubbles.append(newBubble)
        if isValidEntry(in: newBubble, entry: navigationAction.request) {
            newBubble.load(navigationAction.request)
        }
        return newBubble
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        let lockScript = """
                var viewportMeta = document.createElement('meta');
                viewportMeta.name = 'viewport';
                viewportMeta.content = 'width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no';
                document.head.appendChild(viewportMeta);
                var lockStyle = document.createElement('style');
                lockStyle.innerText = 'body { touch-action: pan-x pan-y; } input, textarea, select { font-size: 16px !important; maximum-scale=1.0; }';
                document.head.appendChild(lockStyle);
                document.addEventListener('gesturestart', e => e.preventDefault());
                """;
        webView.evaluateJavaScript(lockScript) { _, fail in
            if let fail = fail {
                print("Lock injection failed: \(fail)")
            }
        }
    }
    
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        if (error as NSError).code == NSURLErrorHTTPTooManyRedirects, let safePoint = stablePoint {
            webView.load(URLRequest(url: safePoint))
        }
    }
    
    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        guard let point = navigationAction.request.url else {
            decisionHandler(.allow)
            return
        }
        
        if point.absoluteString.hasPrefix("http") || point.absoluteString.hasPrefix("https") {
            stablePoint = point
            decisionHandler(.allow)
        } else {
            UIApplication.shared.open(point, options: [:], completionHandler: nil)
            decisionHandler(.cancel)
        }
    }
    
    func webView(_ webView: WKWebView, didReceiveServerRedirectForProvisionalNavigation navigation: WKNavigation!) {
        bounceCounter += 1
        if bounceCounter > bounceCap {
            webView.stopLoading()
            if let safePoint = stablePoint {
                webView.load(URLRequest(url: safePoint))
            }
            return
        }
        stablePoint = webView.url
        storeOrbitData(from: webView)
    }
    
    private func prepareBubble(_ bubble: WKWebView) {
        bubble.translatesAutoresizingMaskIntoConstraints = false
        bubble.scrollView.isScrollEnabled = true
        bubble.scrollView.minimumZoomScale = 1.0
        bubble.scrollView.maximumZoomScale = 1.0
        bubble.scrollView.bouncesZoom = false
        bubble.allowsBackForwardNavigationGestures = true
        bubble.navigationDelegate = self
        bubble.uiDelegate = self
        orbitCore.mainBubble.addSubview(bubble)
        
        let slideDetector = UIScreenEdgePanGestureRecognizer(target: self, action: #selector(catchSlide(_:)))
        slideDetector.edges = .left
        bubble.addGestureRecognizer(slideDetector)
    }
    
    private func isValidEntry(in bubble: WKWebView, entry: URLRequest) -> Bool {
        if let entryPath = entry.url?.absoluteString, !entryPath.isEmpty, entryPath != "about:blank" {
            return true
        }
        return false
    }
    
    private func anchorBubble(_ bubble: WKWebView) {
        NSLayoutConstraint.activate([
            bubble.leadingAnchor.constraint(equalTo: orbitCore.mainBubble.leadingAnchor),
            bubble.trailingAnchor.constraint(equalTo: orbitCore.mainBubble.trailingAnchor),
            bubble.topAnchor.constraint(equalTo: orbitCore.mainBubble.topAnchor),
            bubble.bottomAnchor.constraint(equalTo: orbitCore.mainBubble.bottomAnchor)
        ])
    }
    
}

struct BubbleForge {
    
    static func createMainBubble(using setup: WKWebViewConfiguration? = nil) -> WKWebView {
        let blueprint = setup ?? forgeBlueprint()
        return WKWebView(frame: .zero, configuration: blueprint)
    }
    
    static func clearExtraBubbles(_ main: WKWebView, _ extras: [WKWebView], activePoint: URL?) -> Bool {
        if !extras.isEmpty {
            extras.forEach { $0.removeFromSuperview() }
            if let point = activePoint {
                main.load(URLRequest(url: point))
            }
            return true
        } else if main.canGoBack {
            main.goBack()
            return false
        }
        return false
    }
    
    private static func forgeBlueprint() -> WKWebViewConfiguration {
        let blueprint = WKWebViewConfiguration()
        blueprint.allowsInlineMediaPlayback = true
        blueprint.preferences = forgeSettings()
        blueprint.defaultWebpagePreferences = forgePageSettings()
        blueprint.requiresUserActionForMediaPlayback = false
        return blueprint
    }
    
    private static func forgeSettings() -> WKPreferences {
        let settings = WKPreferences()
        settings.javaScriptEnabled = true
        settings.javaScriptCanOpenWindowsAutomatically = true
        return settings
    }
    
    private static func forgePageSettings() -> WKWebpagePreferences {
        let settings = WKWebpagePreferences()
        settings.allowsContentJavaScript = true
        return settings
    }
}

extension Notification.Name {
    static let orbitSignals = Notification.Name("orbit_flow")
}

class OrbitCore: ObservableObject {
    @Published var mainBubble: WKWebView!
    @Published var extraBubbles: [WKWebView] = []
    
    func restoreVault() {
        guard let vaultData = UserDefaults.standard.dictionary(forKey: "orbit_vault") as? [String: [String: [HTTPCookiePropertyKey: AnyObject]]] else { return }
        let dataStore = mainBubble.configuration.websiteDataStore.httpCookieStore
        
        vaultData.values.flatMap { $0.values }.forEach { props in
            if let item = HTTPCookie(properties: props as! [HTTPCookiePropertyKey: Any]) {
                dataStore.setCookie(item)
            }
        }
    }
    
    func launchMainBubble() {
        mainBubble = BubbleForge.createMainBubble()
        mainBubble.scrollView.minimumZoomScale = 1.0
        mainBubble.scrollView.maximumZoomScale = 1.0
        mainBubble.scrollView.bouncesZoom = false
        mainBubble.allowsBackForwardNavigationGestures = true
    }
    
    func refreshOrbit() {
        mainBubble.reload()
    }
    func popTopBubble() {
        if let topBubble = extraBubbles.last {
            topBubble.removeFromSuperview()
            extraBubbles.removeLast()
        }
    }
    
    func collapseExtras(activePoint: URL?) {
        if !extraBubbles.isEmpty {
            if let topBubble = extraBubbles.last {
                topBubble.removeFromSuperview()
                extraBubbles.removeLast()
            }
            if let point = activePoint {
                mainBubble.load(URLRequest(url: point))
            }
        } else if mainBubble.canGoBack {
            mainBubble.goBack()
        }
    }
    
}

struct CoreOrbitView: UIViewRepresentable {
    let launchPoint: URL
    @StateObject private var core = OrbitCore()
    
    func makeUIView(context: Context) -> WKWebView {
        core.launchMainBubble()
        core.mainBubble.uiDelegate = context.coordinator
        core.mainBubble.navigationDelegate = context.coordinator
    
        core.restoreVault()
        core.mainBubble.load(URLRequest(url: launchPoint))
        return core.mainBubble
    }
    
    
    func makeCoordinator() -> OrbitNavigator {
        OrbitNavigator(core: core)
    }
    
    func updateUIView(_ bubble: WKWebView, context: Context) {
    }
}

extension OrbitNavigator {
    @objc func catchSlide(_ detector: UIScreenEdgePanGestureRecognizer) {
        if detector.state == .ended {
            guard let bubble = detector.view as? WKWebView else { return }
            if bubble.canGoBack {
                bubble.goBack()
            } else if let topBubble = orbitCore.extraBubbles.last, bubble == topBubble {
                orbitCore.collapseExtras(activePoint: nil)
            }
        }
    }
}

struct OrbitSurface: View {
    
    @State var orbitPath: String = ""
    
    var body: some View {
        ZStack(alignment: .bottom) {
            if let point = URL(string: orbitPath) {
                CoreOrbitView(
                    launchPoint: point
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .ignoresSafeArea(.keyboard, edges: .bottom)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            orbitPath = UserDefaults.standard.string(forKey: "temp_url") ?? (UserDefaults.standard.string(forKey: "saved_url") ?? "")
            if let tempPath = UserDefaults.standard.string(forKey: "temp_url"), !tempPath.isEmpty {
                UserDefaults.standard.set(nil, forKey: "temp_url")
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("LoadTempURL"))) { _ in
            if let tempPath = UserDefaults.standard.string(forKey: "temp_url"), !tempPath.isEmpty {
                orbitPath = tempPath
                UserDefaults.standard.set(nil, forKey: "temp_url")
            }
        }
    }
}

class LaunchOrbit: ObservableObject {
    
    @Published var activePhase: Phase = .ignition
    @Published var orbitPoint: URL?
    @Published var promptActive = false
    
    
    init() {
        NotificationCenter.default.addObserver(self, selector: #selector(captureSignal(_:)), name: NSNotification.Name("ConversionDataReceived"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(signalLost(_:)), name: NSNotification.Name("ConversionDataFailed"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(syncBeacon(_:)), name: NSNotification.Name("FCMTokenUpdated"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(reignite(_:)), name: NSNotification.Name("RetryConfig"), object: nil)
        
        scanOrbitPath()
    }
    
    private var signalData: [AnyHashable: Any] = [:]
    private var firstIgnition: Bool {
        !UserDefaults.standard.bool(forKey: "hasLaunched")
    }
    
    enum Phase {
        case ignition
        case orbit
        case backup
        case blackout
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    private func scanOrbitPath() {
        let orbitScan = NWPathMonitor()
        orbitScan.pathUpdateHandler = { path in
            DispatchQueue.main.async {
                if path.status != .satisfied {
                    self.enterBlackout()
                }
            }
        }
        orbitScan.start(queue: DispatchQueue.global())
    }
    
    @objc private func captureSignal(_ alert: Notification) {
        signalData = (alert.userInfo ?? [:])["conversionData"] as? [AnyHashable: Any] ?? [:]
        processSignal()
    }
    
    @objc private func signalLost(_ alert: Notification) {
        ignitionFailure()
    }
    
    @objc private func routeTempPoint(_ alert: Notification) {
        guard let info = alert.userInfo as? [String: Any],
              let tempPoint = info["tempUrl"] as? String else {
            return
        }
        
        DispatchQueue.main.async {
            self.orbitPoint = URL(string: tempPoint)!
            self.activePhase = .orbit
        }
    }
    
    
    @objc private func syncBeacon(_ alert: Notification) {
        if let beacon = alert.object as? String {
            UserDefaults.standard.set(beacon, forKey: "fcm_token")
            transmitOrbitData()
        }
    }
    
    @objc private func reignite(_ alert: Notification) {
        scanOrbitPath()
    }
    
    func transmitOrbitData() {
        guard let target = URL(string: "https://bubbleorbit.com/config.php") else {
            ignitionFailure()
            return
        }
        
        var transmission = URLRequest(url: target)
        transmission.httpMethod = "POST"
        transmission.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        var orbitPayload = signalData
        orbitPayload["af_id"] = AppsFlyerLib.shared().getAppsFlyerUID()
        orbitPayload["bundle_id"] = Bundle.main.bundleIdentifier ?? "com.example.app"
        orbitPayload["os"] = "iOS"
        orbitPayload["store_id"] = "id6753625490"
        orbitPayload["locale"] = Locale.preferredLanguages.first?.prefix(2).uppercased() ?? "EN"
        orbitPayload["push_token"] = UserDefaults.standard.string(forKey: "fcm_token") ?? Messaging.messaging().fcmToken
        orbitPayload["firebase_project_id"] = FirebaseApp.app()?.options.gcmSenderID
        
        do {
            transmission.httpBody = try JSONSerialization.data(withJSONObject: orbitPayload)
        } catch {
            ignitionFailure()
            return
        }
        
        URLSession.shared.dataTask(with: transmission) { data, resp, err in
            DispatchQueue.main.async {
                if let _ = err {
                    self.ignitionFailure()
                    return
                }
                
                guard let httpResp = resp as? HTTPURLResponse, httpResp.statusCode == 200,
                      let data = data else {
                    self.ignitionFailure()
                    return
                }
                
                do {
                    if let response = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        if let success = response["ok"] as? Bool, success {
                            if let pointStr = response["url"] as? String, let duration = response["expires"] as? TimeInterval {
                                UserDefaults.standard.set(pointStr, forKey: "saved_url")
                                UserDefaults.standard.set(duration, forKey: "saved_expires")
                                UserDefaults.standard.set("WebView", forKey: "app_mode")
                                UserDefaults.standard.set(true, forKey: "hasLaunched")
                                self.orbitPoint = URL(string: pointStr)
                                self.activePhase = .orbit
                                
                                if self.firstIgnition {
                                    self.checkPromptStatus()
                                }
                            }
                        } else {
                            self.activateBackup()
                        }
                    }
                } catch {
                    self.ignitionFailure()
                }
            }
        }.resume()
    }
    
    private func processSignal() {
        guard !signalData.isEmpty else { return }
        
        if UserDefaults.standard.string(forKey: "app_mode") == "Funtik" {
            DispatchQueue.main.async {
                self.activePhase = .backup
            }
            return
        }
        
        if firstIgnition {
            if let signalType = signalData["af_status"] as? String, signalType == "Organic" {
                self.activateBackup()
                return
            }
        }
        
        if let tempPoint = UserDefaults.standard.string(forKey: "temp_url"), !tempPoint.isEmpty {
            orbitPoint = URL(string: tempPoint)
            self.activePhase = .orbit
            return
        }
        
        if orbitPoint == nil {
            if !UserDefaults.standard.bool(forKey: "accepted_notifications") && !UserDefaults.standard.bool(forKey: "system_close_notifications") {
                checkPromptStatus()
            } else {
                transmitOrbitData()
            }
        }
    }
    
    private func ignitionFailure() {
        if let savedPoint = UserDefaults.standard.string(forKey: "saved_url"), let point = URL(string: savedPoint) {
            orbitPoint = point
            activePhase = .orbit
        } else {
            activateBackup()
        }
    }
    
    private func activateBackup() {
        UserDefaults.standard.set("Funtik", forKey: "app_mode")
        UserDefaults.standard.set(true, forKey: "hasLaunched")
        DispatchQueue.main.async {
            self.activePhase = .backup
        }
    }
    
    private func enterBlackout() {
        let mode = UserDefaults.standard.string(forKey: "app_mode")
        if mode == "WebView" {
            DispatchQueue.main.async {
                self.activePhase = .blackout
            }
        } else {
            activateBackup()
        }
    }
    
    func requestBeaconAccess() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, err in
            DispatchQueue.main.async {
                if granted {
                    UserDefaults.standard.set(true, forKey: "accepted_notifications")
                    UIApplication.shared.registerForRemoteNotifications()
                } else {
                    UserDefaults.standard.set(false, forKey: "accepted_notifications")
                    UserDefaults.standard.set(true, forKey: "system_close_notifications")
                }
                self.transmitOrbitData()
                self.promptActive = false
                if let err = err {
                    print("Beacon access failed: \(err)")
                }
            }
        }
    }
    
    private func checkPromptStatus() {
        if let lastCheck = UserDefaults.standard.value(forKey: "last_notification_ask") as? Date,
           Date().timeIntervalSince(lastCheck) < 259200 {
            transmitOrbitData()
            return
        }
        promptActive = true
    }
    
}

struct LaunchView: View {
    
    @StateObject private var controller = LaunchOrbit()
    @EnvironmentObject var reminderStore: ReminderStore
    
    @State private var isOrbitSpinning = false
    
    var body: some View {
        ZStack {
            if controller.activePhase == .ignition || controller.promptActive {
                orbitIgnitionScreen
            }
            
            if controller.promptActive {
                BeaconRequestView(
                    onAccept: {
                        controller.requestBeaconAccess()
                    },
                    onDecline: {
                        UserDefaults.standard.set(Date(), forKey: "last_notification_ask")
                        controller.promptActive = false
                        controller.transmitOrbitData()
                    }
                )
            } else {
                switch controller.activePhase {
                case .ignition:
                    EmptyView()
                case .orbit:
                    if let _ = controller.orbitPoint {
                        OrbitSurface()
                    } else {
                        ContentView()
                            .environmentObject(reminderStore)
                            .preferredColorScheme(.dark)
                    }
                case .backup:
                    ContentView()
                        .environmentObject(reminderStore)
                        .preferredColorScheme(.dark)
                case .blackout:
                    noSignalView
                }
            }
        }
    }
    
    private var orbitIgnitionScreen: some View {
        GeometryReader { geo in
            let landscapeMode = geo.size.width > geo.size.height
            
            ZStack {
                Image("loading_bg")
                    .resizable()
                    .scaledToFill()
                    .frame(width: geo.size.width, height: geo.size.height)
                    .ignoresSafeArea()
                
                VStack {
                    Image("pero")
                        .resizable()
                        .frame(width: 80, height: 80)
                        .rotationEffect(isOrbitSpinning ? .degrees(50) : .degrees(-50))
                        .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: isOrbitSpinning)
                        .onAppear {
                            isOrbitSpinning = true
                        }
                    
                    Text("LOADING...")
                        .font(.custom("Inter-Regular", size: 24))
                        .foregroundColor(.white)
                }
            }
        }
        .ignoresSafeArea()
        .onAppear {
            isOrbitSpinning = true
        }
    }
    
    private var noSignalView: some View {
        GeometryReader { geometry in
            
            ZStack {
                Image("loading_bg")
                    .resizable()
                    .scaledToFill()
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .ignoresSafeArea()
                
                Image("internet_check")
                    .resizable()
                    .frame(width: 250, height: 200)
            }
            
        }
        .ignoresSafeArea()
    }
    
}


#Preview {
    LaunchView()
        .environmentObject(ReminderStore())
        .preferredColorScheme(.dark)
}


struct BeaconRequestView: View {
    var onAccept: () -> Void
    var onDecline: () -> Void
    
    var body: some View {
        GeometryReader { geometry in
            let isLandscape = geometry.size.width > geometry.size.height
            
            ZStack {
                Image("notifications_bg")
                    .resizable()
                    .scaledToFill()
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .ignoresSafeArea()
                
                VStack(spacing: isLandscape ? 5 : 10) {
                    Spacer()
                    
                    Text("Allow notifications about bonuses and promos".uppercased())
                        .font(.custom("Inter-Regular_Bold", size: 20))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                    
                    Text("Stay tuned with best offers from our casino")
                        .font(.custom("Inter-Regular_Medium", size: 16))
                        .foregroundColor(Color.init(red: 186/255, green: 186/255, blue: 186/255))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 52)
                    
                    if isLandscape {
                        Button(action: onAccept) {
                            Image("confirm_btn")
                                .resizable()
                                .frame(height: 60)
                        }
                        .frame(width: 350)
                        .padding(.top, 24)
                        
                        Button(action: onDecline) {
                            Image("skip_btn")
                                .resizable()
                                .frame(height: 40)
                        }
                        .frame(width: 330)
                    } else {
                        Button(action: onAccept) {
                            Image("confirm_btn")
                                .resizable()
                                .frame(height: 60)
                        }
                        .padding(.horizontal, 32)
                        .padding(.top, 24)
                        
                        Button(action: onDecline) {
                            Image("skip_btn")
                                .resizable()
                                .frame(height: 40)
                        }
                        .padding(.horizontal, 42)
                    }
                    
                    Spacer()
                        .frame(height: isLandscape ? 50 : 70)
                }
                .padding(.horizontal, isLandscape ? 20 : 0)
            }
            
        }
        .ignoresSafeArea()
    }
}
