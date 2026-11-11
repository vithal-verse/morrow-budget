import Foundation
import Combine

public enum TransactionKind: String, Codable, CaseIterable, Identifiable {
    case openingBalance
    case income
    case expense

    public var id: String { rawValue }
    public var label: String {
        switch self {
        case .openingBalance: "Starting balance"
        case .income: "Income"
        case .expense: "Expense"
        }
    }
}

public struct Transaction: Codable, Identifiable, Equatable {
    public var id: UUID
    public var kind: TransactionKind
    public var amount: Double
    public var title: String
    public var category: String
    public var date: Date
    public var note: String

    public init(id: UUID = UUID(), kind: TransactionKind, amount: Double, title: String, category: String = "General", date: Date = .now, note: String = "") {
        self.id = id
        self.kind = kind
        self.amount = amount
        self.title = title
        self.category = category
        self.date = date
        self.note = note
    }
}

public struct InventoryItem: Codable, Identifiable, Equatable {
    public var id: UUID
    public var name: String
    public var quantity: Int
    public var unitCost: Double
    public var unitPrice: Double
    public var sold: Int

    public init(id: UUID = UUID(), name: String, quantity: Int, unitCost: Double, unitPrice: Double, sold: Int = 0) {
        self.id = id
        self.name = name
        self.quantity = quantity
        self.unitCost = unitCost
        self.unitPrice = unitPrice
        self.sold = sold
    }

    public var quantityOnHand: Int { max(0, quantity - sold) }
    public var revenue: Double { Double(sold) * unitPrice }
    public var costOfGoodsSold: Double { Double(sold) * unitCost }
    public var profit: Double { revenue - costOfGoodsSold }
}

public struct PlanItem: Codable, Identifiable, Equatable {
    public var id: UUID
    public var title: String
    public var targetAmount: Double
    public var savedAmount: Double
    public var dueDate: Date?
    public var isComplete: Bool

    public init(id: UUID = UUID(), title: String, targetAmount: Double, savedAmount: Double = 0, dueDate: Date? = nil, isComplete: Bool = false) {
        self.id = id
        self.title = title
        self.targetAmount = targetAmount
        self.savedAmount = savedAmount
        self.dueDate = dueDate
        self.isComplete = isComplete
    }
}

public struct Ledger: Codable, Equatable {
    public var transactions: [Transaction]
    public var inventory: [InventoryItem]
    public var plans: [PlanItem]

    public init(transactions: [Transaction] = [], inventory: [InventoryItem] = [], plans: [PlanItem] = []) {
        self.transactions = transactions
        self.inventory = inventory
        self.plans = plans
    }

    public var balance: Double {
        transactions.reduce(0) { total, transaction in
            total + (transaction.kind == .expense ? -transaction.amount : transaction.amount)
        }
    }
    public var totalIncome: Double { transactions.filter { $0.kind == .income }.reduce(0) { $0 + $1.amount } }
    public var totalExpenses: Double { transactions.filter { $0.kind == .expense }.reduce(0) { $0 + $1.amount } }
    public var businessRevenue: Double { inventory.reduce(0) { $0 + $1.revenue } }
    public var businessProfit: Double { inventory.reduce(0) { $0 + $1.profit } }
}

public struct TransactionCommandParser {
    public init() {}

    public func parse(_ input: String) -> Transaction? {
        let parts = input.split(whereSeparator: \.isWhitespace).map(String.init)
        guard parts.count >= 2,
              let amount = parts.first(where: { Double($0.replacingOccurrences(of: ",", with: "")) != nil })
                .flatMap({ Double($0.replacingOccurrences(of: ",", with: "")) }), amount > 0 else { return nil }
        let incomeWords = ["income", "earned", "received", "credit", "sold", "sale"]
        let expenseWords = ["spent", "expense", "paid", "debit", "bought", "purchase"]
        let words = parts.map { $0.lowercased().trimmingCharacters(in: .punctuationCharacters) }
        let kind: TransactionKind
        if words.contains(where: incomeWords.contains) {
            kind = .income
        } else if words.contains(where: expenseWords.contains) {
            kind = .expense
        } else { return nil }
        let amountIndex = parts.firstIndex(where: { Double($0.replacingOccurrences(of: ",", with: "")) != nil }) ?? 0
        let commandWords = Set(incomeWords + expenseWords + ["i", "on", "at", "for", "from", "to", "the"])
        let title = parts.enumerated().filter { $0.offset != amountIndex }
            .map(\.element).filter { !commandWords.contains($0.lowercased().trimmingCharacters(in: .punctuationCharacters)) }
            .joined(separator: " ")
        return Transaction(kind: kind, amount: amount, title: title.isEmpty ? kind.label : title.capitalized)
    }
}

public protocol AssistantActionLayer {
    func draft(for input: String, in ledger: Ledger) -> AssistantResponse
}

public enum AssistantResponse: Equatable {
    case transactionDraft(Transaction)
    case balance(Double)
    case unsupported
}

public struct LocalAssistant: AssistantActionLayer {
    public init() {}
    public func draft(for input: String, in ledger: Ledger) -> AssistantResponse {
        let normalized = input.lowercased()
        if normalized.contains("balance") || normalized.contains("how much") { return .balance(ledger.balance) }
        if let transaction = TransactionCommandParser().parse(input) { return .transactionDraft(transaction) }
        return .unsupported
    }
}

public final class LedgerStore: ObservableObject {
    @Published public private(set) var ledger: Ledger
    private let fileURL: URL

    public init(fileURL: URL? = nil) {
        self.fileURL = fileURL ?? Self.defaultURL
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let data = try? Data(contentsOf: self.fileURL), let saved = try? decoder.decode(Ledger.self, from: data) {
            ledger = saved
        } else {
            ledger = Ledger()
        }
    }

    public func saveTransaction(_ transaction: Transaction) {
        ledger.transactions.insert(transaction, at: 0)
        persist()
    }
    public func addPocketMoney(_ amount: Double, source: String) {
        let cleanSource = source.trimmingCharacters(in: .whitespacesAndNewlines)
        guard amount > 0, amount.isFinite, !cleanSource.isEmpty else { return }
        saveTransaction(Transaction(kind: .income, amount: amount, title: cleanSource, category: "Pocket money"))
    }
    public func updateTransaction(_ transaction: Transaction) {
        guard let index = ledger.transactions.firstIndex(where: { $0.id == transaction.id }) else { return }
        ledger.transactions[index] = transaction
        persist()
    }
    public func deleteTransaction(_ transaction: Transaction) {
        ledger.transactions.removeAll { $0.id == transaction.id }
        persist()
    }
    public func addInventory(_ item: InventoryItem) {
        guard !item.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              item.quantity > 0, item.unitCost >= 0, item.unitCost.isFinite,
              item.unitPrice > 0, item.unitPrice.isFinite else { return }
        ledger.inventory.insert(item, at: 0)
        ledger.transactions.insert(Transaction(kind: .expense, amount: Double(item.quantity) * item.unitCost, title: "Stock · \(item.name)", category: "Business"), at: 0)
        persist()
    }
    public func recordSale(for item: InventoryItem, quantity: Int) {
        guard let index = ledger.inventory.firstIndex(where: { $0.id == item.id }), quantity > 0, quantity <= item.quantityOnHand else { return }
        ledger.inventory[index].sold += quantity
        ledger.transactions.insert(Transaction(kind: .income, amount: Double(quantity) * item.unitPrice, title: "Sale · \(item.name)", category: "Business"), at: 0)
        persist()
    }
    public func addPlan(_ plan: PlanItem) { ledger.plans.insert(plan, at: 0); persist() }
    public func updatePlan(_ plan: PlanItem) {
        guard let index = ledger.plans.firstIndex(where: { $0.id == plan.id }) else { return }
        ledger.plans[index] = plan
        persist()
    }
    public func deletePlan(_ plan: PlanItem) { ledger.plans.removeAll { $0.id == plan.id }; persist() }

    private func persist() {
        do {
            let folder = fileURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            try encoder.encode(ledger).write(to: fileURL, options: .atomic)
        } catch { NSLog("Unable to save budget data: %@", error.localizedDescription) }
    }
    private static var defaultURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("PersonalBudget", isDirectory: true).appendingPathComponent("ledger.json")
    }
}
