import Testing
import Foundation
@testable import BudgetCore

@Test func balanceUsesIncomeAndExpenseAmounts() {
    let ledger = Ledger(transactions: [
        Transaction(kind: .income, amount: 1200, title: "Pay"),
        Transaction(kind: .expense, amount: 275, title: "Rent")
    ])

    #expect(ledger.balance == 925)
}

@Test func openingBalanceAffectsAvailableMoneyButIsNotCountedAsIncome() {
    let ledger = Ledger(transactions: [
        Transaction(kind: .openingBalance, amount: 1200, title: "Money already in account"),
        Transaction(kind: .income, amount: 300, title: "Freelance")
    ])

    #expect(ledger.balance == 1500)
    #expect(ledger.totalIncome == 300)
}

@Test func chatParsesIncomeAndExpenseAsUncommittedDrafts() throws {
    let parser = TransactionCommandParser()

    let income = try #require(parser.parse("income 2500 freelance"))
    let expense = try #require(parser.parse("spent 450 groceries"))

    #expect(income.kind == .income)
    #expect(income.amount == 2500)
    #expect(expense.kind == .expense)
    #expect(expense.amount == 450)
}

@Test func chatParsesNaturalLanguageTransactionPhrases() throws {
    let parser = TransactionCommandParser()

    let expense = try #require(parser.parse("I spent 450 on groceries"))
    let income = try #require(parser.parse("I received 2500 from freelance"))

    #expect(expense.kind == .expense)
    #expect(expense.title == "Groceries")
    #expect(income.kind == .income)
    #expect(income.title == "Freelance")
}

@Test func inventoryProfitUsesSalesRevenueLessPurchaseCost() {
    let item = InventoryItem(name: "Protein", quantity: 10, unitCost: 600, unitPrice: 950, sold: 3)

    #expect(item.revenue == 2850)
    #expect(item.costOfGoodsSold == 1800)
    #expect(item.profit == 1050)
    #expect(item.quantityOnHand == 7)
}

@Test func ledgerRestoresTransactionsFromLocalJSON() throws {
    let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent("morrow-\(UUID().uuidString).json")
    defer { try? FileManager.default.removeItem(at: fileURL) }
    let original = LedgerStore(fileURL: fileURL)
    original.saveTransaction(Transaction(kind: .income, amount: 850, title: "Freelance", date: Date(timeIntervalSince1970: 1_700_000_000)))

    let restored = LedgerStore(fileURL: fileURL)

    #expect(restored.ledger.transactions.count == 1)
    #expect(restored.ledger.balance == 850)
}

@Test func pocketMoneyIsSavedAsIncomeAndCanBeRestored() throws {
    let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent("morrow-pocket-\(UUID().uuidString).json")
    defer { try? FileManager.default.removeItem(at: fileURL) }
    let store = LedgerStore(fileURL: fileURL)

    store.addPocketMoney(500, source: "Weekly allowance")
    let restored = LedgerStore(fileURL: fileURL)

    #expect(restored.ledger.balance == 500)
    #expect(restored.ledger.totalIncome == 500)
    #expect(restored.ledger.transactions.first?.category == "Pocket money")
    #expect(restored.ledger.transactions.first?.title == "Weekly allowance")
}

@Test func supplementPurchaseAndSalePersistStockBalanceRevenueAndProfit() throws {
    let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent("morrow-stock-\(UUID().uuidString).json")
    defer { try? FileManager.default.removeItem(at: fileURL) }
    let store = LedgerStore(fileURL: fileURL)

    let protein = InventoryItem(name: "Protein", quantity: 4, unitCost: 100, unitPrice: 180)
    store.addInventory(protein)
    store.recordSale(for: protein, quantity: 2)
    let restored = LedgerStore(fileURL: fileURL)

    #expect(restored.ledger.inventory.first?.quantityOnHand == 2)
    #expect(restored.ledger.businessRevenue == 360)
    #expect(restored.ledger.businessProfit == 160)
    #expect(restored.ledger.balance == -40)
}


