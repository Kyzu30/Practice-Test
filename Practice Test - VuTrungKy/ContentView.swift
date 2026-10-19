// Paste this entire file into ContentView.swift. Keep the default App.swift.
// Requires iOS 16 or later. Data is in memory only.
// Remove older copies of these classes from the app target to avoid duplicate declarations.

import SwiftUI
import Foundation
import Combine


// MARK: - Models.swift
enum AcademicError: LocalizedError {
    case invalidName, invalidAge, invalidCredits, invalidMark, invalidYear
    case duplicateRegistration, unknownStudent, unknownSubject, unknownRecord

    var errorDescription: String? {
        switch self {
        case .invalidName: return "Name and ID must not be empty."
        case .invalidAge: return "Age must be positive."
        case .invalidCredits: return "Credits must be greater than zero."
        case .invalidMark: return "Enter a finite mark from 0 to 10."
        case .invalidYear: return "The academic year must be positive."
        case .duplicateRegistration: return "This student already registered for this subject in this academic year."
        case .unknownStudent: return "Student not found."
        case .unknownSubject: return "Subject not found."
        case .unknownRecord: return "Registration not found."
        }
    }
}

private func nonEmpty(_ value: String) -> Bool {
    !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
}

final class Student: Identifiable {
    // Stable identity: changing an ID would break existing registrations.
    private(set) var id: String
    private(set) var name: String
    private(set) var age: Int

    init(id: String, name: String, age: Int) throws {
        guard nonEmpty(id), nonEmpty(name) else { throw AcademicError.invalidName }
        guard age > 0 else { throw AcademicError.invalidAge }
        self.id = id
        self.name = name
        self.age = age
    }

    func getID() -> String { id }
    func getName() -> String { name }
    func getAge() -> Int { age }

    func setName(_ value: String) throws {
        guard nonEmpty(value) else { throw AcademicError.invalidName }
        name = value
    }

    func setAge(_ value: Int) throws {
        guard value > 0 else { throw AcademicError.invalidAge }
        age = value
    }

    func displayInfo() -> String { "\(id) — \(name), age \(age)" }
}

final class Subject: Identifiable {
    private(set) var id: String
    private(set) var name: String
    private(set) var credits: Int

    init(id: String, name: String, credits: Int) throws {
        guard nonEmpty(id), nonEmpty(name) else { throw AcademicError.invalidName }
        guard credits > 0 else { throw AcademicError.invalidCredits }
        self.id = id
        self.name = name
        self.credits = credits
    }

    func getID() -> String { id }
    func getName() -> String { name }
    func getCredits() -> Int { credits }

    func setName(_ value: String) throws {
        guard nonEmpty(value) else { throw AcademicError.invalidName }
        name = value
    }

    func setCredits(_ value: Int) throws {
        guard value > 0 else { throw AcademicError.invalidCredits }
        credits = value
    }

    func displayInfo() -> String { "\(id) — \(name) (\(credits) credits)" }
}

final class StudentRecord: Identifiable {
    let id = UUID()
    let student: Student
    let subject: Subject
    // Starting year: 2026 represents 2026–2027.
    let academicYear: Int
    private(set) var mark: Double

    init(student: Student, subject: Subject, mark: Double, academicYear: Int) throws {
        try Self.validate(mark: mark)
        guard academicYear > 0 else { throw AcademicError.invalidYear }
        self.student = student
        self.subject = subject
        self.mark = mark
        self.academicYear = academicYear
    }

    static func validate(mark: Double) throws {
        guard mark.isFinite, (0...10).contains(mark) else { throw AcademicError.invalidMark }
    }

    func getMark() -> Double { mark }
    func setMark(_ value: Double) throws {
        try Self.validate(mark: value)
        mark = value
    }

    func isPassed() -> Bool { mark >= 5.0 }
}

enum AcademicRanking: String {
    case excellent = "Excellent", good = "Good", average = "Average", fail = "Fail"

    static func forAverage(_ value: Double) -> AcademicRanking {
        if value >= 8.5 { return .excellent }
        if value >= 7.0 { return .good }
        if value >= 5.0 { return .average }
        return .fail
    }
}


// MARK: - AcademicRegistry.swift
// Coordinates the three required classes; it does not replace them.
final class AcademicRegistry {
    let students: [Student]
    let subjects: [Subject]
    private(set) var records: [StudentRecord] = []

    init(students: [Student], subjects: [Subject]) {
        self.students = students
        self.subjects = subjects
    }

    @discardableResult
    func register(studentID: String, subjectID: String, academicYear: Int, mark: Double) throws -> StudentRecord {
        guard let student = students.first(where: { $0.id == studentID }) else { throw AcademicError.unknownStudent }
        guard let subject = subjects.first(where: { $0.id == subjectID }) else { throw AcademicError.unknownSubject }
        guard !records.contains(where: {
            $0.student.id == studentID && $0.subject.id == subjectID && $0.academicYear == academicYear
        }) else { throw AcademicError.duplicateRegistration }

        let record = try StudentRecord(student: student, subject: subject, mark: mark, academicYear: academicYear)
        records.append(record)
        return record
    }

    func records(for studentID: String, year: Int) -> [StudentRecord] {
        records.filter { $0.student.id == studentID && $0.academicYear == year }
    }

    func average(for studentID: String, year: Int) -> Double? {
        let selected = records(for: studentID, year: year)
        let credits = selected.reduce(0.0) { $0 + Double($1.subject.credits) }
        guard credits > 0 else { return nil }
        let weightedTotal = selected.reduce(0.0) { $0 + $1.mark * Double($1.subject.credits) }
        return weightedTotal / credits
    }

    func ranking(for studentID: String, year: Int) -> AcademicRanking? {
        guard let value = average(for: studentID, year: year) else { return nil }
        return AcademicRanking.forAverage(value)
    }

    func hasPassedAll(for studentID: String, year: Int) -> Bool {
        let selected = records(for: studentID, year: year)
        return !selected.isEmpty && selected.allSatisfy { $0.isPassed() }
    }

    func updateMark(recordID: UUID, mark: Double) throws {
        guard let record = records.first(where: { $0.id == recordID }) else { throw AcademicError.unknownRecord }
        try record.setMark(mark)
    }

    static func sample() throws -> AcademicRegistry {
        let students = try [
            Student(id: "S01", name: "Nguyen An", age: 20),
            Student(id: "S02", name: "Tran Binh", age: 21),
            Student(id: "S03", name: "Le Chi", age: 20),
            Student(id: "S04", name: "Pham Dung", age: 22)
        ]
        let subjects = try [
            Subject(id: "CS01", name: "Swift Programming", credits: 3),
            Subject(id: "CS02", name: "Database Systems", credits: 4),
            Subject(id: "MA01", name: "Mathematics", credits: 2),
            Subject(id: "EN01", name: "English", credits: 2)
        ]
        let registry = AcademicRegistry(students: students, subjects: subjects)
        let rows: [(String, String, Int, Double)] = [
            ("S01", "CS01", 2026, 9.0), ("S01", "CS02", 2026, 8.5),
            ("S02", "CS01", 2026, 7.0), ("S02", "MA01", 2026, 8.0),
            ("S03", "CS02", 2026, 5.0), ("S03", "EN01", 2026, 6.0),
            ("S04", "MA01", 2026, 4.0), ("S04", "EN01", 2026, 5.0),
            ("S01", "CS01", 2025, 6.0), ("S01", "EN01", 2025, 7.0)
        ]
        for (student, subject, year, mark) in rows {
            try registry.register(studentID: student, subjectID: subject, academicYear: year, mark: mark)
        }
        return registry
    }
}


// MARK: - AcademicStore.swift
@MainActor
final class AcademicStore: ObservableObject {
    let registry: AcademicRegistry
    // A class nested in an array does not automatically publish its property edits.
    // Publish one revision after each successful change made through this store.
    @Published private(set) var revision = 0

    init() {
        do { registry = try AcademicRegistry.sample() }
        catch { fatalError("Invalid developer-provided sample data: \(error)") }
    }

    func updateMark(recordID: UUID, mark: Double) throws {
        try registry.updateMark(recordID: recordID, mark: mark)
        revision += 1
    }

    func register(studentID: String, subjectID: String, year: Int, mark: Double) throws {
        try registry.register(studentID: studentID, subjectID: subjectID, academicYear: year, mark: mark)
        revision += 1
    }

    func refresh() { revision += 1 }
}


// MARK: - ContentView.swift
private enum StudentFilter: String, CaseIterable, Identifiable {
    case all = "All students"
    case goodOrBetter = "Average ≥ 7.0"
    case passedAll = "Passed all subjects"
    var id: String { rawValue }
}

@MainActor
struct ContentView: View {
    @StateObject private var store = AcademicStore()
    @State private var year = 2026
    @State private var filter = StudentFilter.all

    private var years: [Int] {
        Array(Set(store.registry.records.map { $0.academicYear } + [2025, 2026, 2027])).sorted(by: >)
    }

    private var filteredStudents: [Student] {
        store.registry.students.filter { student in
            switch filter {
            case .all: return true
            case .goodOrBetter: return (store.registry.average(for: student.id, year: year) ?? -1) >= 7
            case .passedAll: return store.registry.hasPassedAll(for: student.id, year: year)
            }
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Academic year and requirements") {
                    Picker("Year", selection: $year) {
                        ForEach(years, id: \.self) { value in
                            Text("\(String(value))–\(String(value + 1))").tag(value)
                        }
                    }
                    Picker("Show", selection: $filter) {
                        ForEach(StudentFilter.allCases) { Text($0.rawValue).tag($0) }
                    }
                }
                Section("Students (\(filteredStudents.count))") {
                    if filteredStudents.isEmpty { Text("No students meet this requirement.").foregroundStyle(.secondary) }
                    ForEach(filteredStudents) { student in
                        NavigationLink {
                            StudentDetailView(store: store, student: student, year: year)
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(student.name).font(.headline)
                                Text(student.displayInfo()).font(.caption).foregroundStyle(.secondary)
                                if let average = store.registry.average(for: student.id, year: year),
                                   let ranking = store.registry.ranking(for: student.id, year: year) {
                                    Text("Average: \(average, specifier: "%.2f") • \(ranking.rawValue)")
                                } else {
                                    Text("No registrations — not ranked").foregroundStyle(.secondary)
                                }
                            }.padding(.vertical, 4)
                        }
                    }
                }
            }
            .navigationTitle("Student Manager")
            .toolbar { Button("Refresh") { store.refresh() } }
        }
    }
}

@MainActor
struct StudentDetailView: View {
    @ObservedObject var store: AcademicStore
    let student: Student
    let year: Int
    @State private var editingRecord: StudentRecord?
    @State private var showingRegistration = false

    private var records: [StudentRecord] { store.registry.records(for: student.id, year: year) }

    var body: some View {
        List {
            Section("Student information") {
                Text(student.displayInfo())
                Text("Academic year: \(String(year))–\(String(year + 1))")
            }
            Section("Academic results") {
                if let average = store.registry.average(for: student.id, year: year),
                   let ranking = store.registry.ranking(for: student.id, year: year) {
                    Text("Weighted average: \(average, specifier: "%.2f")")
                    Text("Ranking: \(ranking.rawValue)")
                    Text("Passed subjects: \(records.filter { $0.isPassed() }.count)/\(records.count)")
                    Text(store.registry.hasPassedAll(for: student.id, year: year)
                         ? "All subjects passed" : "At least one subject failed")
                } else { Text("No registrations — not ranked") }
            }
            Section("Subjects — tap to update a mark") {
                ForEach(records) { record in
                    Button { editingRecord = record } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(record.subject.name).font(.headline).foregroundStyle(.primary)
                            Text("\(record.subject.credits) credits • Mark: \(record.mark, specifier: "%.2f")")
                                .foregroundStyle(.secondary)
                            Text(record.isPassed() ? "Pass" : "Fail")
                                .foregroundStyle(record.isPassed() ? Color.green : Color.red)
                        }.padding(.vertical, 4)
                    }
                }
                Button("Register a subject") { showingRegistration = true }
            }
        }
        .navigationTitle(student.name)
        .toolbar { Button("Refresh") { store.refresh() } }
        .sheet(item: $editingRecord) { record in MarkEditor(store: store, record: record) }
        .sheet(isPresented: $showingRegistration) {
            RegistrationEditor(store: store, student: student, year: year)
        }
    }
}

@MainActor
struct MarkEditor: View {
    @ObservedObject var store: AcademicStore
    let record: StudentRecord
    @Environment(\.dismiss) private var dismiss
    @State private var markText: String
    @State private var errorMessage: String?

    init(store: AcademicStore, record: StudentRecord) {
        self.store = store
        self.record = record
        _markText = State(initialValue: String(record.mark))
    }

    var body: some View {
        NavigationStack {
            Form {
                Text(record.subject.name)
                TextField("Mark (0–10)", text: $markText).keyboardType(.decimalPad)
                if let errorMessage { Text(errorMessage).foregroundStyle(.red) }
            }
            .navigationTitle("Update mark")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        do {
                            let normalized = markText.trimmingCharacters(in: .whitespacesAndNewlines)
                                .replacingOccurrences(of: ",", with: ".")
                            guard let mark = Double(normalized) else { throw AcademicError.invalidMark }
                            try store.updateMark(recordID: record.id, mark: mark)
                            dismiss()
                        } catch { errorMessage = error.localizedDescription }
                    }
                }
            }
        }
    }
}

@MainActor
struct RegistrationEditor: View {
    @ObservedObject var store: AcademicStore
    let student: Student
    let year: Int
    @Environment(\.dismiss) private var dismiss
    @State private var subjectID = ""
    @State private var markText = ""
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Text("\(student.name) • \(String(year))–\(String(year + 1))")
                Picker("Subject", selection: $subjectID) {
                    Text("Select a subject").tag("")
                    ForEach(store.registry.subjects) { subject in
                        Text(subject.displayInfo()).tag(subject.id)
                    }
                }
                TextField("Initial mark (0–10)", text: $markText).keyboardType(.decimalPad)
                Text("This assignment stores a mark with each registration.").font(.caption)
                if let errorMessage { Text(errorMessage).foregroundStyle(.red) }
            }
            .navigationTitle("Register subject")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        do {
                            let normalized = markText.trimmingCharacters(in: .whitespacesAndNewlines)
                                .replacingOccurrences(of: ",", with: ".")
                            guard let mark = Double(normalized) else { throw AcademicError.invalidMark }
                            try store.register(studentID: student.id, subjectID: subjectID, year: year, mark: mark)
                            dismiss()
                        } catch { errorMessage = error.localizedDescription }
                    }.disabled(subjectID.isEmpty)
                }
            }
        }
    }
}
