import Flutter
import UIKit
import Security
import AVFoundation
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate, AVSpeechSynthesizerDelegate {
  private let speech = AVSpeechSynthesizer()
  private var speechChannel: FlutterMethodChannel?
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    #if DEBUG
    if UserDefaults.standard.bool(forKey: "courseRemindersEnabled") {
      scheduleCourseReminders { _ in }
    }
    #else
    disableCourseReminders()
    #endif
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    guard let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "LearningIdentity") else { return }
    let channel = FlutterMethodChannel(name: "learn_anywhere/identity", binaryMessenger: registrar.messenger())
    let reminderChannel = FlutterMethodChannel(name: "learn_anywhere/reminders", binaryMessenger: registrar.messenger())
    reminderChannel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else { return }
      let center = UNUserNotificationCenter.current()
      #if DEBUG
      switch call.method {
      case "updateCourse":
        guard let title = call.arguments as? String, !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
          result(FlutterError(code: "invalid", message: "Missing course title", details: nil)); return
        }
        let defaults = UserDefaults.standard
        let changed = defaults.string(forKey: "reminderCourseTitle") != title
        defaults.set(title, forKey: "reminderCourseTitle")
        if changed && defaults.bool(forKey: "courseRemindersEnabled") {
          center.add(self.noonCourseReminder()) { error in
            DispatchQueue.main.async {
              if let error = error { result(FlutterError(code: "schedule", message: error.localizedDescription, details: nil)) }
              else { result(nil) }
            }
          }
        } else { result(nil) }
      case "setSuggestions":
        guard let suggestions = call.arguments as? [String], !suggestions.isEmpty,
          suggestions.count <= 3, suggestions.allSatisfy({ !$0.isEmpty && $0.count <= 160 }) else {
          result(FlutterError(code: "invalid", message: "Invalid reminder suggestions.", details: nil)); return
        }
        UserDefaults.standard.set(suggestions, forKey: "courseReminderSuggestions")
        UserDefaults.standard.set(UserDefaults.standard.string(forKey: "reminderCourseTitle"), forKey: "suggestionCourseTitle")
        center.getPendingNotificationRequests { requests in
          let group = DispatchGroup()
          let lock = NSLock()
          var firstError: Error?
          for request in requests where request.identifier.hasPrefix("course-reminder-") && request.identifier != "course-reminder-noon" {
            guard let content = request.content.mutableCopy() as? UNMutableNotificationContent else { continue }
            content.body = self.readingSuggestion()
            group.enter()
            center.add(UNNotificationRequest(identifier: request.identifier, content: content, trigger: request.trigger)) { error in
              lock.lock(); if firstError == nil { firstError = error }; lock.unlock(); group.leave()
            }
          }
          group.notify(queue: .main) {
            if let error = firstError { result(FlutterError(code: "schedule", message: error.localizedDescription, details: nil)) }
            else { result(nil) }
          }
        }
      case "testOneMinute":
        center.requestAuthorization(options: [.alert, .sound]) { granted, error in
          guard granted, error == nil else {
            DispatchQueue.main.async { result(FlutterError(code: "permission", message: "Allow notifications in Settings first.", details: nil)) }; return
          }
          let noon = self.noonCourseReminder().content
          let random = UNMutableNotificationContent()
          random.title = "Time for a little learning"
          random.body = self.readingSuggestion()
          random.sound = .default
          let group = DispatchGroup()
          let lock = NSLock()
          var firstError: Error?
          for (index, content) in [noon, random].enumerated() {
            group.enter()
            center.add(UNNotificationRequest(identifier: "course-reminder-test-\(index)", content: content,
              trigger: UNTimeIntervalNotificationTrigger(timeInterval: 60, repeats: false))) { error in
              lock.lock(); if firstError == nil { firstError = error }; lock.unlock()
              group.leave()
            }
          }
          group.notify(queue: .main) {
            if let error = firstError {
              center.removePendingNotificationRequests(withIdentifiers: ["course-reminder-test-0", "course-reminder-test-1"])
              result(FlutterError(code: "schedule", message: error.localizedDescription, details: nil))
            } else { result(nil) }
          }
        }
      case "status":
        center.getNotificationSettings { settings in
          let enabled = UserDefaults.standard.bool(forKey: "courseRemindersEnabled") &&
            (settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional)
          DispatchQueue.main.async { result(enabled) }
        }
      case "setEnabled":
        guard let enabled = call.arguments as? Bool else {
          result(FlutterError(code: "invalid", message: "Expected a reminder preference", details: nil)); return
        }
        if !enabled {
          UserDefaults.standard.set(false, forKey: "courseRemindersEnabled")
          center.getPendingNotificationRequests { requests in
            center.removePendingNotificationRequests(withIdentifiers: requests.filter { $0.identifier.hasPrefix("course-reminder-") }.map { $0.identifier })
            DispatchQueue.main.async { result(false) }
          }
          return
        }
        center.requestAuthorization(options: [.alert, .sound]) { granted, error in
          guard granted, error == nil else {
            DispatchQueue.main.async { result(FlutterError(code: "permission", message: "Allow notifications in iPhone Settings to enable course reminders.", details: nil)) }
            return
          }
          UserDefaults.standard.set(true, forKey: "courseRemindersEnabled")
          self.scheduleCourseReminders { error in
            DispatchQueue.main.async {
              if let error = error {
                UserDefaults.standard.set(false, forKey: "courseRemindersEnabled")
                center.getPendingNotificationRequests { requests in
                  center.removePendingNotificationRequests(withIdentifiers: requests.filter { $0.identifier.hasPrefix("course-reminder-") }.map { $0.identifier })
                }
                result(FlutterError(code: "schedule", message: error.localizedDescription, details: nil))
              } else { result(true) }
            }
          }
        }
      default: result(FlutterMethodNotImplemented)
      }
      #else
      self.disableCourseReminders()
      switch call.method {
      case "status", "setEnabled": result(false)
      case "updateCourse", "setSuggestions", "testOneMinute": result(nil)
      default: result(FlutterMethodNotImplemented)
      }
      #endif
    }
    speech.delegate = self
    let audioChannel = FlutterMethodChannel(name: "learn_anywhere/speech", binaryMessenger: registrar.messenger())
    speechChannel = audioChannel
    audioChannel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else { return }
      switch call.method {
      case "speak":
        guard let args = call.arguments as? [String: Any],
              let text = args["text"] as? String,
              let language = args["language"] as? String else {
          result(FlutterError(code: "invalid", message: "Missing lesson text", details: nil))
          return
        }
        guard let voice = AVSpeechSynthesisVoice.speechVoices().first(where: {
          $0.language.split(separator: "-").first.map(String.init) == language
        }) else {
          result(FlutterError(code: "no_voice", message: "No matching voice on this device", details: nil))
          return
        }
        do {
          try AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
          try AVAudioSession.sharedInstance().setActive(true)
        } catch {
          result(FlutterError(code: "audio", message: "Could not start audio", details: nil))
          return
        }
        self.speech.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = voice
        let speed = args["speed"] as? Double ?? 1
        utterance.rate = Float(speed) * AVSpeechUtteranceDefaultSpeechRate
        self.speech.speak(utterance)
        result(nil)
      case "pause": self.speech.pauseSpeaking(at: .immediate); result(nil)
      case "resume": self.speech.continueSpeaking(); result(nil)
      case "stop": self.speech.stopSpeaking(at: .immediate); self.finishSpeech(); result(nil)
      default: result(FlutterMethodNotImplemented)
      }
    }
    channel.setMethodCallHandler { call, result in
      if call.method == "isSimulator" {
        #if targetEnvironment(simulator)
        result(true)
        #else
        result(false)
        #endif
        return
      }
      let query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: "learn_anywhere.backend",
        kSecAttrAccount as String: "installation-token"
      ]
      if call.method == "clear" {
        let status = SecItemDelete(query as CFDictionary)
        if status == errSecSuccess || status == errSecItemNotFound { result(nil) }
        else { result(FlutterError(code: "keychain", message: "Could not clear installation token", details: status)) }
      } else if call.method == "read" {
        var read = query
        read[kSecReturnData as String] = true
        read[kSecMatchLimit as String] = kSecMatchLimitOne
        var value: CFTypeRef?
        let status = SecItemCopyMatching(read as CFDictionary, &value)
        if status == errSecItemNotFound { result(nil) }
        else if status == errSecSuccess, let data = value as? Data { result(String(data: data, encoding: .utf8)) }
        else { result(FlutterError(code: "keychain", message: "Could not read installation token", details: status)) }
      } else if call.method == "write", let token = call.arguments as? String {
        let data = Data(token.utf8)
        var status = SecItemUpdate(query as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if status == errSecItemNotFound {
          var item = query
          item[kSecValueData as String] = data
          item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
          status = SecItemAdd(item as CFDictionary, nil)
        }
        if status == errSecSuccess { result(nil) }
        else { result(FlutterError(code: "keychain", message: "Could not save installation token", details: status)) }
      } else { result(FlutterMethodNotImplemented) }
    }

  }
  // Keep a rolling 30-day window. Preserve pending times across app launches.
  private func scheduleCourseReminders(completion: @escaping (Error?) -> Void) {
    #if !DEBUG
    disableCourseReminders()
    completion(nil)
    return
    #else
    let center = UNUserNotificationCenter.current()
    center.getPendingNotificationRequests { requests in
      let existing = Set(requests.map { $0.identifier })
      let calendar = Calendar.current
      let now = Date()
      let group = DispatchGroup()
      let errorLock = NSLock()
      var firstError: Error?
      if !existing.contains("course-reminder-noon") {
        group.enter()
        center.add(self.noonCourseReminder()) { error in
          errorLock.lock()
          if firstError == nil { firstError = error }
          errorLock.unlock()
          group.leave()
        }
      }
      for offset in 1...30 {
        guard let day = calendar.date(byAdding: .day, value: offset, to: now) else { continue }
        var components = calendar.dateComponents([.year, .month, .day], from: day)
        let id = "course-reminder-\(components.year!)-\(components.month!)-\(components.day!)"
        if existing.contains(id) { continue }
        let minute = Int.random(in: 0..<600)
        components.hour = 9 + minute / 60
        components.minute = minute % 60
        components.second = 0
        let content = UNMutableNotificationContent()
        content.title = "Time for a little learning"
        content.body = self.readingSuggestion()
        content.sound = .default
        let request = UNNotificationRequest(identifier: id, content: content,
          trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false))
        group.enter()
        center.add(request) { error in
          errorLock.lock()
          if firstError == nil { firstError = error }
          errorLock.unlock()
          group.leave()
        }
      }
      group.notify(queue: .main) { completion(firstError) }
    }
    #endif
  }

  private func disableCourseReminders() {
    UserDefaults.standard.set(false, forKey: "courseRemindersEnabled")
    let center = UNUserNotificationCenter.current()
    center.getPendingNotificationRequests { requests in
      let ids = requests.filter { $0.identifier.hasPrefix("course-reminder-") }.map { $0.identifier }
      center.removePendingNotificationRequests(withIdentifiers: ids)
    }
  }

  private func readingSuggestion() -> String {
    let defaults = UserDefaults.standard
    if defaults.string(forKey: "suggestionCourseTitle") == defaults.string(forKey: "reminderCourseTitle"),
      let suggestions = defaults.stringArray(forKey: "courseReminderSuggestions"), let text = suggestions.randomElement() { return text }
    return "Open Learn Anywhere and read a lesson from your courses."
  }

  private func noonCourseReminder() -> UNNotificationRequest {
    let course = UserDefaults.standard.string(forKey: "reminderCourseTitle") ?? "Your course"
    let content = UNMutableNotificationContent()
    content.title = "A little learning at noon"
    content.body = "\(course) — one chapter a day goes a long way."
    content.sound = .default
    var components = DateComponents()
    components.hour = 12
    components.minute = 0
    return UNNotificationRequest(identifier: "course-reminder-noon", content: content,
      trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: true))
  }

  private func finishSpeech() {
    if speech.isSpeaking { return }
    speechChannel?.invokeMethod("state", arguments: "idle")
    try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
  }

  func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) { speechChannel?.invokeMethod("state", arguments: "speaking") }
  func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) { finishSpeech() }
  func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) { finishSpeech() }
  func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didPause utterance: AVSpeechUtterance) { speechChannel?.invokeMethod("state", arguments: "paused") }
  func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didContinue utterance: AVSpeechUtterance) { speechChannel?.invokeMethod("state", arguments: "speaking") }

}
