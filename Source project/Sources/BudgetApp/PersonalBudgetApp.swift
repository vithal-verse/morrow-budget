import SwiftUI
import BudgetCore
typealias BudgetTransaction = BudgetCore.Transaction
enum MorrowPalette {
    static let navy = Color(red: 0.075, green: 0.22, blue: 0.365)
    static let teal = Color(red: 0.09, green: 0.682, blue: 0.596)
    static let income = Color(red: 0.082, green: 0.58, blue: 0.463)
    static let expense = Color(red: 0.886, green: 0.353, blue: 0.306)
    static let business = Color(red: 0.941, green: 0.592, blue: 0.169)
    static let goals = Color(red: 0.439, green: 0.365, blue: 0.792)
    static let page = Color(red: 0.953, green: 0.965, blue: 0.984)
}
@main
struct PersonalBudgetApp: App {
    @StateObject private var store = LedgerStore()
    var body: some Scene {
        WindowGroup {
            RootView().environmentObject(store).frame(minWidth: 1080, minHeight: 720)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1280, height: 820)
    }
}
private enum AppSection: String, CaseIterable, Identifiable {
    case overview = "Overview", transactions = "Transactions", pocketMoney = "Pocket money", business = "Supplement business", plans = "Savings & targets", assistant = "Chat entry"
    var id: String { rawValue }
    var symbol: String {
        switch self { case .overview: "square.grid.2x2.fill"; case .transactions: "arrow.left.arrow.right"; case .pocketMoney: "gift.fill"; case .business: "shippingbox.fill"; case .plans: "checklist"; case .assistant: "bubble.left.and.bubble.right.fill" }
    }
}
struct RootView: View {
    @EnvironmentObject private var store: LedgerStore
    @State private var selection: AppSection? = .overview
    @State private var activeSheet: RootSheet?
    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                Section("YOUR MONEY") {
                    ForEach(AppSection.allCases) { item in
                        Button { selection = item } label: {
                            Label(item.rawValue, systemImage: item.symbol)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(selection == item ? MorrowPalette.teal.opacity(0.14) : Color.clear)
                    }
                }
            }
            .listStyle(.sidebar)
            .tint(MorrowPalette.teal)
            .safeAreaInset(edge: .bottom) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("AVAILABLE BALANCE").font(.caption2.weight(.semibold)).tracking(1.1).foregroundStyle(.secondary)
                    Text(store.ledger.balance, format: .currency(code: "INR")).font(.title2.weight(.semibold)).contentTransition(.numericText())
                    Text("Starting balance + income − expenses").font(.caption2).foregroundStyle(.secondary)
                    HStack(spacing: 6) { Circle().fill(.green).frame(width: 7, height: 7); Text("Saved on this Mac").font(.caption).foregroundStyle(.secondary) }
                }
                .padding(16).frame(maxWidth: .infinity, alignment: .leading)
                .background(LinearGradient(colors: [MorrowPalette.navy, MorrowPalette.teal], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .foregroundStyle(.white)
                .padding(12)
            }
            .navigationTitle("Morrow")
            .toolbar { ToolbarItem(placement: .principal) { HStack(spacing: 8) { Image(systemName: "circle.hexagongrid.fill").symbolRenderingMode(.palette).foregroundStyle(MorrowPalette.teal, MorrowPalette.navy); Text("MORROW").font(.caption.weight(.bold)).tracking(2) } } }
        } detail: {
            Group {
                switch selection ?? .overview {
                case .overview: DashboardView(onSetStartingBalance: { activeSheet = .transaction(.openingBalance) })
                case .transactions: TransactionsView()
                case .pocketMoney: PocketMoneyView()
                case .business: BusinessView()
                case .plans: PlansView()
                case .assistant: AssistantView()
                }
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { activeSheet = .transaction(.expense) } label: { Label("Add transaction", systemImage: "plus") }
                        .buttonStyle(.borderedProminent).tint(MorrowPalette.teal)
                }
            }
        }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .transaction(let kind): TransactionEditor(initialKind: kind) { store.saveTransaction($0) }
            }
        }
    }
}
private enum RootSheet: Identifiable {
    case transaction(TransactionKind)
    var id: String {
        switch self { case .transaction(let kind): "transaction-\(kind.rawValue)" }
    }
}
struct PageShell<Content: View>: View {
    let title: String
    let subtitle: String
    var accent: Color = MorrowPalette.teal
    @ViewBuilder var content: Content
    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color(nsColor: .windowBackgroundColor)
            Circle().fill(accent.opacity(0.11)).frame(width: 430, height: 430).blur(radius: 95).offset(x: 140, y: -210)
            Circle().fill(MorrowPalette.goals.opacity(0.07)).frame(width: 320, height: 320).blur(radius: 85).offset(x: -520, y: 480)
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(title).font(.system(size: 30, weight: .semibold, design: .rounded))
                        Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
                    }
                    content
                }
                .padding(30).frame(maxWidth: 1100, alignment: .leading)
            }
        }
        .clipped()
    }
}
struct GlassCard<Content: View>: View {
    var tint: Color? = nil
    @ViewBuilder var content: Content
    var body: some View {
        content.padding(20).frame(maxWidth: .infinity, alignment: .leading)
            .background {
                ZStack {
                    RoundedRectangle(cornerRadius: 22, style: .continuous).fill(.regularMaterial)
                    if let tint { RoundedRectangle(cornerRadius: 22, style: .continuous).fill(tint.opacity(0.11).gradient) }
                }
            }
            .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(tint?.opacity(0.24) ?? Color.primary.opacity(0.07), lineWidth: 1))
            .shadow(color: (tint ?? .clear).opacity(0.09), radius: 20, y: 8)
    }
}
struct DashboardView: View {
    @EnvironmentObject private var store: LedgerStore
    let onSetStartingBalance: () -> Void
    var body: some View {
        PageShell(title: "Overview", subtitle: "Available money, recent entries, and your next actions.", accent: MorrowPalette.teal) {
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(LinearGradient(colors: [MorrowPalette.navy, Color(red: 0.08, green: 0.40, blue: 0.56), MorrowPalette.teal], startPoint: .topLeading, endPoint: .bottomTrailing))
                Circle().fill(.white.opacity(0.09)).frame(width: 300, height: 300).offset(x: 700, y: -82)
                Circle().stroke(.white.opacity(0.12), lineWidth: 26).frame(width: 250, height: 250).offset(x: 875, y: 54)
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 10) {
                        Label("AVAILABLE BALANCE", systemImage: "wallet.bifold.fill").font(.caption.weight(.semibold)).tracking(1.1).foregroundStyle(.white.opacity(0.84))
                        Text(store.ledger.balance, format: .currency(code: "INR")).font(.system(size: 39, weight: .semibold, design: .rounded)).foregroundStyle(.white).contentTransition(.numericText())
                        Text("Starting balance  +  income  −  expenses").font(.caption).foregroundStyle(.white.opacity(0.78))
                    }
                    Spacer()
                    if store.ledger.transactions.isEmpty {
                        Button(action: onSetStartingBalance) {
                            Label("Set starting balance", systemImage: "plus.circle.fill").fontWeight(.semibold)
                                .padding(.horizontal, 17).padding(.vertical, 12)
                                .background(.white.opacity(0.17), in: Capsule())
                                .overlay(Capsule().stroke(.white.opacity(0.32), lineWidth: 1))
                        }.buttonStyle(.plain).foregroundStyle(.white)
                    }
                }.padding(28)
            }
            .frame(maxWidth: .infinity, minHeight: 212, maxHeight: 212)
            .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
            .shadow(color: MorrowPalette.navy.opacity(0.22), radius: 24, y: 12)
            if store.ledger.transactions.isEmpty {
                GlassCard(tint: MorrowPalette.teal) {
                    HStack(alignment: .top, spacing: 14) {
                        Image(systemName: "1.circle.fill").font(.title2).foregroundStyle(.indigo)
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Start with the money you have today").font(.headline)
                            Text("Add a starting balance once. It updates available balance, but is kept separate from income earned.").font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            HStack(spacing: 16) {
                MetricCard(title: "Income recorded · all time", value: store.ledger.totalIncome, icon: "arrow.down.left", tint: MorrowPalette.income)
                MetricCard(title: "Expenses recorded · all time", value: store.ledger.totalExpenses, icon: "arrow.up.right", tint: MorrowPalette.expense)
            }
            HStack(alignment: .top, spacing: 16) {
                GlassCard(tint: MorrowPalette.teal) {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack { Text("Latest transactions").font(.headline); Spacer(); Text("All recorded entries").font(.caption).foregroundStyle(.secondary) }
                        ForEach(store.ledger.transactions.prefix(5)) { transaction in TransactionRow(transaction: transaction) }
                        if store.ledger.transactions.isEmpty {
                            ContentUnavailableView("No transactions yet", systemImage: "arrow.left.arrow.right", description: Text("Income and expenses you add will appear here."))
                        }
                    }
                }
                VStack(spacing: 16) {
                    GlassCard(tint: MorrowPalette.business) {
                        VStack(alignment: .leading, spacing: 12) {
                            Label("Supplement business", systemImage: "shippingbox.fill").font(.headline)
                            HStack { Text("Sales revenue"); Spacer(); MoneyText(value: store.ledger.businessRevenue) }
                            HStack { Text("Product profit to date"); Spacer(); MoneyText(value: store.ledger.businessProfit, tint: .green) }
                            Text("Revenue less the cost of units sold · \(store.ledger.inventory.count) products").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    GlassCard(tint: MorrowPalette.goals) {
                        VStack(alignment: .leading, spacing: 12) {
                            Label("Savings & targets", systemImage: "checklist").font(.headline)
                            ForEach(store.ledger.plans.prefix(3)) { plan in
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack { Text(plan.title).lineLimit(1); Spacer(); MoneyText(value: max(0, plan.targetAmount - plan.savedAmount)) }
                                    ProgressView(value: min(1, plan.savedAmount / max(plan.targetAmount, 1))).tint(.indigo)
                                }
                            }
                        }
                    }
                }.frame(width: 290)
            }
        }
    }
}
struct MetricCard: View {
    let title: String
    let value: Double
    let icon: String
    let tint: Color
    var large = false
    var showsCount = false
    var body: some View {
        GlassCard(tint: tint) {
            VStack(alignment: .leading, spacing: large ? 22 : 14) {
                Image(systemName: icon).font(.title3).foregroundStyle(tint).padding(9).background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.caption).foregroundStyle(.secondary).lineLimit(2).fixedSize(horizontal: false, vertical: true)
                    if showsCount {
                        Text(value, format: .number.precision(.fractionLength(0))).font(.system(size: large ? 29 : 21, weight: .semibold, design: .rounded)).contentTransition(.numericText())
                    } else {
                        Text(value, format: .currency(code: "INR")).font(.system(size: large ? 29 : 21, weight: .semibold, design: .rounded)).contentTransition(.numericText()).lineLimit(1).minimumScaleFactor(0.75)
                    }
                }
            }
        }
    }
}
struct MoneyText: View {
    let value: Double
    var tint: Color? = nil
    var body: some View { Text(value, format: .currency(code: "INR")).fontWeight(.semibold).foregroundStyle(tint ?? .primary) }
}
struct TransactionsView: View {
    @EnvironmentObject private var store: LedgerStore
    @State private var search = ""
    @State private var editing: BudgetTransaction?
    var filtered: [BudgetTransaction] { store.ledger.transactions.filter { search.isEmpty || $0.title.localizedCaseInsensitiveContains(search) || $0.category.localizedCaseInsensitiveContains(search) } }
    var body: some View {
        PageShell(title: "Transactions", subtitle: "A searchable ledger of your starting balance, income, and expenses.", accent: MorrowPalette.teal) {
            GlassCard(tint: MorrowPalette.teal) {
                VStack(spacing: 0) {
                    TextField("Search transactions", text: $search).textFieldStyle(.roundedBorder).padding(.bottom, 12)
                    ForEach(filtered) { transaction in
                        TransactionRow(transaction: transaction)
                            .contentShape(Rectangle()).contextMenu {
                                Button("Edit") { editing = transaction }
                                Button("Delete", role: .destructive) { store.deleteTransaction(transaction) }
                            }
                    }
                    if filtered.isEmpty { ContentUnavailableView("No transactions", systemImage: "tray", description: Text("Add a transaction to start your ledger.")) }
                }
            }
        }
        .sheet(item: $editing) { transaction in TransactionEditor(transaction: transaction) { store.updateTransaction($0) } }
    }
}
struct PocketMoneyView: View {
    @EnvironmentObject private var store: LedgerStore
    @State private var showingAdd = false
    private var entries: [BudgetTransaction] { store.ledger.transactions.filter { $0.category == "Pocket money" } }
    private var total: Double { entries.reduce(0) { $0 + $1.amount } }
    var body: some View {
        PageShell(title: "Pocket money", subtitle: "Add allowance or other personal spending money and keep a clear record.", accent: MorrowPalette.goals) {
            HStack(spacing: 16) {
                GlassCard(tint: MorrowPalette.goals) {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Pocket money received", systemImage: "gift.fill").font(.headline).foregroundStyle(MorrowPalette.goals)
                        Text(total, format: .currency(code: "INR")).font(.system(size: 30, weight: .semibold, design: .rounded))
                        Text("Included in your available balance and income total.").font(.caption).foregroundStyle(.secondary)
                    }
                }
                Button { showingAdd = true } label: {
                    Label("Add pocket money", systemImage: "plus.circle.fill").font(.headline).frame(maxWidth: .infinity, minHeight: 96)
                }
                .buttonStyle(.borderedProminent).tint(MorrowPalette.goals)
            }
            GlassCard(tint: MorrowPalette.teal) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack { Text("Pocket money history").font(.headline); Spacer(); Text("\(entries.count) entries").font(.caption).foregroundStyle(.secondary) }
                    ForEach(entries) { TransactionRow(transaction: $0) }
                    if entries.isEmpty {
                        ContentUnavailableView("No pocket money added", systemImage: "gift", description: Text("Choose Add pocket money to record your first amount."))
                    }
                }
            }
        }
        .sheet(isPresented: $showingAdd) { PocketMoneyEditor { amount, source in store.addPocketMoney(amount, source: source) } }
    }
}
struct PocketMoneyEditor: View {
    @Environment(\.dismiss) private var dismiss
    @State private var amount = ""
    @State private var source = "Pocket money"
    let onSave: (Double, String) -> Void
    var body: some View {
        Form {
            TextField("Amount (₹)", text: $amount)
            TextField("From / note", text: $source)
            Text("This amount is added to income and your available balance.").font(.caption).foregroundStyle(.secondary)
            HStack { Spacer(); Button("Cancel") { dismiss() }; Button("Add") { save() }.buttonStyle(.borderedProminent).disabled((Double(amount) ?? 0) <= 0 || source.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) }
        }
        .padding(24).frame(width: 400).background(.regularMaterial).navigationTitle("Add pocket money")
    }
    private func save() {
        guard let value = Double(amount), value > 0 else { return }
        onSave(value, source)
        dismiss()
    }
}
struct TransactionRow: View {
    let transaction: BudgetTransaction
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: transaction.kind == .income ? "arrow.down.left" : transaction.kind == .expense ? "arrow.up.right" : "wallet.bifold.fill")
                .font(.caption.weight(.bold)).foregroundStyle(transaction.kind == .income ? MorrowPalette.income : transaction.kind == .expense ? MorrowPalette.expense : MorrowPalette.teal)
                .frame(width: 34, height: 34).background((transaction.kind == .income ? MorrowPalette.income : transaction.kind == .expense ? MorrowPalette.expense : MorrowPalette.teal).opacity(0.11), in: Circle())
            VStack(alignment: .leading, spacing: 3) { Text(transaction.title).font(.subheadline.weight(.medium)); Text("\(transaction.category) · \(transaction.date.formatted(date: .abbreviated, time: .omitted))").font(.caption).foregroundStyle(.secondary) }
            Spacer()
            Text("\(transaction.kind == .expense ? "−" : transaction.kind == .income ? "+" : "")\(transaction.amount, format: .currency(code: "INR"))")
                .font(.subheadline.weight(.semibold)).foregroundStyle(transaction.kind == .income ? MorrowPalette.income : transaction.kind == .openingBalance ? MorrowPalette.teal : .primary)
        }.padding(.vertical, 10)
    }
}
struct TransactionEditor: View {
    @Environment(\.dismiss) private var dismiss
    @State private var kind: TransactionKind
    @State private var amount: String
    @State private var title: String
    @State private var category: String
    private let existing: BudgetTransaction?
    let onSave: (BudgetTransaction) -> Void
    init(transaction: BudgetTransaction? = nil, initialKind: TransactionKind = .expense, onSave: @escaping (BudgetTransaction) -> Void) {
        existing = transaction; self.onSave = onSave
        _kind = State(initialValue: transaction?.kind ?? initialKind)
        _amount = State(initialValue: transaction.map { String($0.amount) } ?? "")
        _title = State(initialValue: transaction?.title ?? (initialKind == .openingBalance ? "Opening balance" : ""))
        _category = State(initialValue: transaction?.category ?? (initialKind == .openingBalance ? "Starting balance" : "General"))
    }
    var body: some View {
        Form {
            Picker("Type", selection: $kind) { ForEach(TransactionKind.allCases) { Text($0.label).tag($0) } }.pickerStyle(.segmented)
            TextField("Amount (₹)", text: $amount).textFieldStyle(.roundedBorder)
            TextField("Description", text: $title).textFieldStyle(.roundedBorder)
            TextField("Category", text: $category).textFieldStyle(.roundedBorder)
            if kind == .openingBalance {
                Text("This is money already in your account. It changes available balance, not your income total.").font(.caption).foregroundStyle(.secondary)
            }
            HStack { Spacer(); Button("Cancel") { dismiss() }; Button("Save") { save() }.buttonStyle(.borderedProminent).disabled(Double(amount) == nil || title.isEmpty) }
        }
        .padding(24).frame(width: 420).background(.regularMaterial)
        .navigationTitle(existing == nil ? "New transaction" : "Edit transaction")
    }
    private func save() {
        guard let value = Double(amount), value > 0 else { return }
        onSave(BudgetTransaction(id: existing?.id ?? UUID(), kind: kind, amount: value, title: title, category: category.isEmpty ? "General" : category, date: existing?.date ?? .now))
        dismiss()
    }
}
struct BusinessView: View {
    @EnvironmentObject private var store: LedgerStore
    @State private var activeSheet: BusinessSheet?
    var body: some View {
        PageShell(title: "Supplement business", subtitle: "Track what you buy, how much stock remains, and the profit from products sold.", accent: MorrowPalette.business) {
            HStack(spacing: 14) {
                MetricCard(title: "Sales revenue · all time", value: store.ledger.businessRevenue, icon: "chart.line.uptrend.xyaxis", tint: MorrowPalette.income)
                MetricCard(title: "Product profit · all time", value: store.ledger.businessProfit, icon: "sparkles", tint: MorrowPalette.goals)
                MetricCard(title: "Products in inventory", value: Double(store.ledger.inventory.count), icon: "shippingbox", tint: MorrowPalette.business, showsCount: true)
            }
            GlassCard(tint: MorrowPalette.business) {
                VStack(spacing: 0) {
                    HStack { Text("Inventory").font(.headline); Spacer(); Button { activeSheet = .addStock } label: { Label("Add stock", systemImage: "plus") }.buttonStyle(.borderedProminent).tint(MorrowPalette.business) }.padding(.bottom, 12)
                    ForEach(store.ledger.inventory) { item in
                        HStack(spacing: 14) {
                            Image(systemName: "shippingbox.fill").foregroundStyle(MorrowPalette.business).frame(width: 36, height: 36).background(MorrowPalette.business.opacity(0.12), in: RoundedRectangle(cornerRadius: 11))
                            VStack(alignment: .leading, spacing: 3) {
                                Text(item.name).fontWeight(.medium)
                                Text("\(item.quantityOnHand) in stock · \(item.sold) sold · buy \(item.unitCost, format: .currency(code: "INR")) / sell \(item.unitPrice, format: .currency(code: "INR")) each").font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 3) { MoneyText(value: item.profit, tint: .green); Text("gross profit to date").font(.caption).foregroundStyle(.secondary) }
                            Button("Record sale") { activeSheet = .recordSale(item) }.disabled(item.quantityOnHand == 0)
                        }.padding(.vertical, 12)
                    }
                    if store.ledger.inventory.isEmpty { ContentUnavailableView("No stock yet", systemImage: "shippingbox", description: Text("Add a product purchase to begin.")) }
                }
            }
        }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .addStock: InventoryEditor { store.addInventory($0) }
            case .recordSale(let item): SaleEditor(item: item) { store.recordSale(for: item, quantity: $0) }
            }
        }
    }
}
private enum BusinessSheet: Identifiable {
    case addStock
    case recordSale(InventoryItem)
    var id: String {
        switch self { case .addStock: "add-stock"; case .recordSale(let item): "sale-\(item.id.uuidString)" }
    }
}
struct InventoryEditor: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var quantity = ""
    @State private var cost = ""
    @State private var price = ""
    let onSave: (InventoryItem) -> Void
    var body: some View {
        Form {
            TextField("Product name", text: $name).textFieldStyle(.roundedBorder)
            TextField("Units purchased", text: $quantity).textFieldStyle(.roundedBorder)
            TextField("Cost per unit (₹)", text: $cost).textFieldStyle(.roundedBorder)
            TextField("Selling price per unit (₹)", text: $price).textFieldStyle(.roundedBorder)
            Text("Purchase total is deducted from available balance. Gross profit uses units sold.").font(.caption).foregroundStyle(.secondary)
            HStack { Spacer(); Button("Cancel") { dismiss() }; Button("Add stock") { save() }.buttonStyle(.borderedProminent).disabled(name.isEmpty || Int(quantity) == nil || Double(cost) == nil || Double(price) == nil) }
        }.padding(24).frame(width: 430).background(.regularMaterial)
    }
    private func save() {
        guard let count = Int(quantity), let unitCost = Double(cost), let unitPrice = Double(price), count > 0 else { return }
        onSave(InventoryItem(name: name, quantity: count, unitCost: unitCost, unitPrice: unitPrice)); dismiss()
    }
}
struct SaleEditor: View {
    @Environment(\.dismiss) private var dismiss
    let item: InventoryItem
    let onSave: (Int) -> Void
    @State private var quantity = "1"
    var body: some View {
        Form {
            Text("\(item.name) · \(item.quantityOnHand) available").font(.headline)
            TextField("Units sold", text: $quantity).textFieldStyle(.roundedBorder)
            if let count = Int(quantity), count > 0 { Text("Sales revenue: \(Double(count) * item.unitPrice, format: .currency(code: "INR"))").foregroundStyle(.secondary) }
            HStack { Spacer(); Button("Cancel") { dismiss() }; Button("Record sale") { if let count = Int(quantity) { onSave(count); dismiss() } }.buttonStyle(.borderedProminent).disabled(Int(quantity) == nil || Int(quantity)! <= 0 || Int(quantity)! > item.quantityOnHand) }
        }.padding(24).frame(width: 390).background(.regularMaterial)
    }
}
struct PlansView: View {
    @EnvironmentObject private var store: LedgerStore
    @State private var activeSheet: PlanSheet?
    var body: some View {
        PageShell(title: "Savings & targets", subtitle: "Plan amounts to save or allocate. Targets are planning notes and do not change your available balance.", accent: MorrowPalette.goals) {
            HStack(spacing: 14) {
                MetricCard(title: "Remaining across targets", value: store.ledger.plans.reduce(0) { $0 + max(0, $1.targetAmount - $1.savedAmount) }, icon: "target", tint: MorrowPalette.goals)
                MetricCard(title: "Marked as saved", value: store.ledger.plans.reduce(0) { $0 + $1.savedAmount }, icon: "banknote", tint: MorrowPalette.income)
            }
            GlassCard(tint: MorrowPalette.goals) {
                VStack(spacing: 0) {
                    HStack { Text("Your list").font(.headline); Spacer(); Button { activeSheet = .new } label: { Label("New target", systemImage: "plus") }.buttonStyle(.borderedProminent) }.padding(.bottom, 12)
                    ForEach(store.ledger.plans) { plan in
                        VStack(alignment: .leading, spacing: 10) {
                            HStack { Button { var updated = plan; updated.isComplete.toggle(); store.updatePlan(updated) } label: { Image(systemName: plan.isComplete ? "checkmark.circle.fill" : "circle").font(.title3).foregroundStyle(plan.isComplete ? .green : .secondary) }.buttonStyle(.plain).accessibilityLabel(plan.isComplete ? "Mark incomplete" : "Mark complete")
                                Text(plan.title).fontWeight(.medium); Spacer(); Text("Target").font(.caption).foregroundStyle(.secondary); MoneyText(value: plan.targetAmount); Menu { Button("Edit saved amount") { activeSheet = .edit(plan) }; Button("Delete", role: .destructive) { store.deletePlan(plan) } } label: { Image(systemName: "ellipsis.circle") }.menuStyle(.borderlessButton) }
                            ProgressView(value: min(1, plan.savedAmount / max(plan.targetAmount, 1))).tint(.indigo)
                            HStack { Text("\(plan.savedAmount, format: .currency(code: "INR")) saved"); Spacer(); Text("\(max(0, plan.targetAmount - plan.savedAmount), format: .currency(code: "INR")) to go") }.font(.caption).foregroundStyle(.secondary)
                        }.padding(.vertical, 13)
                    }
                    if store.ledger.plans.isEmpty { ContentUnavailableView("No plans yet", systemImage: "checklist", description: Text("Add a savings target or amount to allocate.")) }
                }
            }
        }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .new: PlanEditor { store.addPlan($0) }
            case .edit(let plan): PlanEditor(plan: plan) { store.updatePlan($0) }
            }
        }
    }
}
private enum PlanSheet: Identifiable {
    case new
    case edit(PlanItem)
    var id: String {
        switch self { case .new: "new-plan"; case .edit(let plan): "edit-plan-\(plan.id.uuidString)" }
    }
}
struct PlanEditor: View {
    @Environment(\.dismiss) private var dismiss
    private let existing: PlanItem?
    @State private var title: String
    @State private var target: String
    @State private var saved: String
    let onSave: (PlanItem) -> Void
    init(plan: PlanItem? = nil, onSave: @escaping (PlanItem) -> Void) {
        existing = plan; self.onSave = onSave
        _title = State(initialValue: plan?.title ?? "")
        _target = State(initialValue: plan.map { String($0.targetAmount) } ?? "")
        _saved = State(initialValue: plan.map { String($0.savedAmount) } ?? "0")
    }
    var body: some View {
        Form {
            TextField("What are you working toward?", text: $title).textFieldStyle(.roundedBorder)
            TextField("Target amount", text: $target).textFieldStyle(.roundedBorder)
            TextField("Already saved", text: $saved).textFieldStyle(.roundedBorder)
            HStack { Spacer(); Button("Cancel") { dismiss() }; Button("Save target") { save() }.buttonStyle(.borderedProminent).disabled(title.isEmpty || Double(target) == nil) }
        }.padding(24).frame(width: 430).background(.regularMaterial)
    }
    private func save() {
        guard let amount = Double(target), amount > 0 else { return }
        onSave(PlanItem(id: existing?.id ?? UUID(), title: title, targetAmount: amount, savedAmount: Double(saved) ?? 0, isComplete: existing?.isComplete ?? false)); dismiss()
    }
}
struct AssistantView: View {
    @EnvironmentObject private var store: LedgerStore
    @State private var input = ""
    @State private var messages: [(String, Bool)] = [("Enter an amount and what it was for, such as “I spent 450 on groceries” or “I received 2500 from freelance”. Ask “what’s my balance?” to check your total.", false)]
    @State private var draft: BudgetTransaction?
    @State private var editingDraft = false
    private let assistant: any AssistantActionLayer = LocalAssistant()
    var body: some View {
        PageShell(title: "Chat entry", subtitle: "Type an income or expense, or ask for your current balance. Review every entry before it is saved.", accent: MorrowPalette.navy) {
            GlassCard(tint: MorrowPalette.teal) {
                VStack(spacing: 0) {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 14) {
                            ForEach(messages.indices, id: \.self) { index in
                                HStack { if messages[index].1 { Spacer() }; Text(messages[index].0).padding(12).background(messages[index].1 ? MorrowPalette.teal.opacity(0.17) : Color.primary.opacity(0.055), in: RoundedRectangle(cornerRadius: 15)); if !messages[index].1 { Spacer() } }
                            }
                            if let draft {
                                VStack(alignment: .leading, spacing: 12) {
                                    Label("Review transaction", systemImage: "doc.text.magnifyingglass").font(.subheadline.weight(.semibold))
                                    HStack { Text(draft.kind.label); Spacer(); MoneyText(value: draft.amount) }
                                    Text("Description: \(draft.title) · Category: \(draft.category)").font(.caption).foregroundStyle(.secondary)
                                    HStack { Button("Edit") { editingDraft = true }; Spacer(); Button("Discard") { self.draft = nil }; Button("Confirm & save") { store.saveTransaction(draft); messages.append(("Saved \(draft.title) to your ledger.", false)); self.draft = nil }.buttonStyle(.borderedProminent) }
                                }.padding(15).background(MorrowPalette.teal.opacity(0.10), in: RoundedRectangle(cornerRadius: 16))
                            }
                        }.padding(.vertical, 18)
                    }.frame(minHeight: 280)
                    HStack(spacing: 10) {
                        TextField("Example: spent 450 on groceries", text: $input).textFieldStyle(.plain).onSubmit(send)
                        Button(action: send) { Image(systemName: "arrow.up").fontWeight(.bold).frame(width: 34, height: 34) }.buttonStyle(.borderedProminent).clipShape(Circle()).disabled(input.trimmingCharacters(in: .whitespaces).isEmpty).accessibilityLabel("Send message")
                    }.padding(10).background(.thinMaterial, in: RoundedRectangle(cornerRadius: 17))
                    Text("Nothing is added until you confirm the draft.").font(.caption).foregroundStyle(.secondary).padding(.top, 9)
                }
            }
            GlassCard(tint: MorrowPalette.goals) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("You can say").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    HStack { SuggestionChip(text: "Spent 450 on groceries") { input = "spent 450 groceries" }; SuggestionChip(text: "Income 2,500 freelance") { input = "income 2500 freelance" }; SuggestionChip(text: "What’s my balance?") { input = "what’s my balance?" } }
                }
            }
        }
        .sheet(isPresented: $editingDraft) { if let draft { TransactionEditor(transaction: draft) { self.draft = $0 } } }
    }
    private func send() {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        messages.append((text, true)); input = ""
        switch assistant.draft(for: text, in: store.ledger) {
        case .transactionDraft(let transaction): draft = transaction
        case .balance(let amount): messages.append(("Your current balance is \(amount.formatted(.currency(code: "INR"))).", false))
        case .unsupported: messages.append(("I couldn’t turn that into a transaction or balance question. Try an amount with “income” or “spent”.", false))
        }
    }
}
struct SuggestionChip: View {
    let text: String
    let action: () -> Void
    var body: some View { Button(text, action: action).buttonStyle(.bordered).controlSize(.small) }
}
