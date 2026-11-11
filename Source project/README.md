# Morrow Budget

A local-first personal budget and supplement business tracker for macOS. It combines a ledger, business inventory, savings plans, and a chat-style transaction entry surface. The local assistant is intentionally small and isolated behind `AssistantActionLayer` so another assistant can be connected later.

## Requirements

- macOS 14 or newer
- Swift 5.10 or newer
- Xcode is recommended for signing and standard macOS app development. The project also builds with the Swift command-line toolchain.

## Install or update the app

1. Open `Morrow-Budget-macOS.zip` and use the single `Morrow Budget.app` at the top level.
2. Drag that app into Applications. If macOS asks whether to replace an existing copy during an update, choose Replace.
3. Quit Morrow Budget before replacing it. Do not keep a second renamed copy; all copies use the same local ledger file.

The ZIP also contains a `Source project` folder with the Swift package, tests, and packaging script. It does not contain another app bundle in that folder.

## Run from source

```sh
swift run
```

Run the core tests with:

```sh
swift test
```

## Build a macOS app and ZIP

```sh
./scripts/package.sh
```

The script tests and builds the project, creates `release/Morrow Budget.app`, and writes `Morrow-Budget-macOS.zip` in the project root. The app is unsigned; macOS may require the user to approve opening it. Sign and notarize it with an Apple Developer identity before distributing it broadly.

## What’s included

- One account with a separate starting-balance entry plus manual income and expense entries, editing, deletion, search, and totals.
- A dedicated pocket money screen for recording allowance or personal funds as income, with a total and history.
- A chat-style input for balance questions and transaction drafts. Review or edit the draft before saving.
- Supplement inventory with purchase cost, available stock, unit sale price, recorded sales, revenue, and estimated profit. Adding stock deducts its purchase cost from the balance; recording a sale adds revenue and reduces stock.
- Planning targets with saved amounts, progress, completion, and flexible allocation notes.
- Liquid glass inspired materials and rounded surfaces, with conventional controls and labels for usability.

## Local data and accounting

The ledger is saved as JSON at `~/Library/Application Support/PersonalBudget/ledger.json`. It does not use a server or sync data elsewhere. Back up that file to preserve your records; deleting it resets the app to an empty ledger. New installs begin with a zero balance and no sample transactions.

The starting balance contributes to available balance but is excluded from income totals. Inventory purchases are recorded as expenses when stock is added. Sales are recorded as income. Product gross profit is shown as sales revenue minus the cost of units sold; balance reflects the actual purchase outflow and sale inflow. Savings targets are planning notes and do not change available balance. This is a personal tracking tool, not tax or accounting software.

Chat parsing is rule-based and works offline. It supports phrases such as “I spent 450 on groceries”, “income 2500 freelance”, and “what’s my balance?”. Transaction commands always require confirmation before changing the ledger. Use the standard transaction form when a chat phrase is not understood.

## Project layout

- `Sources/BudgetCore`: models, calculations, persistence, command parsing, assistant interface.
- `Sources/BudgetApp`: SwiftUI macOS interface.
- `Tests/BudgetCoreTests`: balance, parsing, and inventory calculation tests.
- `scripts/package.sh`: repeatable app bundle and ZIP creation.

