import SwiftUI

struct Product: Identifiable, Hashable {
    let id = UUID()
    var name: String
    var price: Decimal
}

struct CartLine: Identifiable {
    let id = UUID()
    var product: Product
    var quantity: Int
    var lineTotal: Decimal { product.price * Decimal(quantity) }
}

struct Receipt: Identifiable {
    let id = UUID()
    let date = Date()
    let lines: [CartLine]
    let total: Decimal
}

@MainActor
final class POSStore: ObservableObject {
    @Published var products: [Product] = [
        Product(name: "Chips naturel", price: 1.49),
        Product(name: "Cola blikje", price: 1.25),
        Product(name: "Paprika chips", price: 1.49),
        Product(name: "Ice Tea", price: 1.35)
    ]
    @Published var cart: [CartLine] = []
    @Published var search = ""
    @Published var showingAddProduct = false
    @Published var latestReceipt: Receipt?

    var filteredProducts: [Product] {
        let term = search.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !term.isEmpty else { return products }
        return products.filter { $0.name.localizedCaseInsensitiveContains(term) }
    }

    var total: Decimal { cart.reduce(0) { $0 + $1.lineTotal } }

    func add(_ product: Product) {
        if let index = cart.firstIndex(where: { $0.product.id == product.id }) {
            cart[index].quantity += 1
        } else {
            cart.append(CartLine(product: product, quantity: 1))
        }
    }

    func changeQuantity(for line: CartLine, by amount: Int) {
        guard let index = cart.firstIndex(where: { $0.id == line.id }) else { return }
        cart[index].quantity += amount
        if cart[index].quantity <= 0 { cart.remove(at: index) }
    }

    func remove(_ line: CartLine) {
        cart.removeAll { $0.id == line.id }
    }

    func addProduct(name: String, priceText: String) -> String? {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalized = priceText.replacingOccurrences(of: ",", with: ".")
        guard !cleanName.isEmpty else { return "Vul een productnaam in." }
        guard let value = Decimal(string: normalized), value > 0 else {
            return "Vul een geldige prijs in, bijvoorbeeld 1,49."
        }
        products.append(Product(name: cleanName, price: value))
        return nil
    }

    func finishDemoSale() {
        guard !cart.isEmpty else { return }
        latestReceipt = Receipt(lines: cart, total: total)
        cart.removeAll()
    }
}

struct ContentView: View {
    @StateObject private var store = POSStore()
    @State private var showReceipt = false

    private let navy = Color(red: 0.08, green: 0.16, blue: 0.24)
    private let green = Color(red: 0.08, green: 0.48, blue: 0.29)

    var body: some View {
        NavigationSplitView {
            productPanel
                .navigationTitle("VEDO POS")
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            store.showingAddProduct = true
                        } label: {
                            Label("Product toevoegen", systemImage: "plus")
                        }
                    }
                }
        } detail: {
            cartPanel
        }
        .tint(green)
        .sheet(isPresented: $store.showingAddProduct) {
            AddProductView { name, price in
                return store.addProduct(name: name, priceText: price)
            }
            .presentationDetents([.medium])
        }
        .sheet(isPresented: $showReceipt) {
            if let receipt = store.latestReceipt {
                ReceiptView(receipt: receipt)
            }
        }
    }

    private var productPanel: some View {
        VStack(spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("VEDO").font(.system(size: 28, weight: .black, design: .rounded))
                    Text("VERKOOPREGISTER").font(.caption2.weight(.bold)).tracking(2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text("KASSA 01")
                    .font(.caption.weight(.bold))
                    .padding(.horizontal, 10).padding(.vertical, 7)
                    .background(green.opacity(0.12), in: Capsule())
            }
            .padding(.top, 8)

            TextField("Zoek product…", text: $store.search)
                .textFieldStyle(.roundedBorder)

            HStack {
                Text("PRODUCTEN").font(.caption.weight(.bold)).tracking(1.2)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(store.products.count) artikelen").font(.caption).foregroundStyle(.secondary)
            }

            ScrollView {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(store.filteredProducts) { product in
                        Button { store.add(product) } label: {
                            VStack(alignment: .leading, spacing: 10) {
                                Image(systemName: "shippingbox.fill")
                                    .font(.title2)
                                    .foregroundStyle(green)
                                Text(product.name)
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                Text(product.price, format: .currency(code: "EUR"))
                                    .font(.subheadline.weight(.bold))
                                    .foregroundStyle(navy)
                            }
                            .padding(14)
                            .frame(maxWidth: .infinity, minHeight: 112, alignment: .leading)
                            .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding()
        .background(Color(uiColor: .systemBackground))
    }

    private var cartPanel: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Winkelmandje").font(.largeTitle.bold())
                    Text("\(store.cart.reduce(0) { $0 + $1.quantity }) artikelen")
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Leegmaken", role: .destructive) { store.cart.removeAll() }
                    .disabled(store.cart.isEmpty)
            }
            .padding(24)

            Divider()

            if store.cart.isEmpty {
                ContentUnavailableView("Winkelmandje is leeg",
                    systemImage: "cart",
                    description: Text("Tik op een product om het toe te voegen."))
            } else {
                List {
                    ForEach(store.cart) { line in
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(line.product.name).font(.headline)
                                Text(line.product.price, format: .currency(code: "EUR"))
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            HStack(spacing: 10) {
                                Button { store.changeQuantity(for: line, by: -1) } label: {
                                    Image(systemName: "minus.circle")
                                }
                                Text("\(line.quantity)").monospacedDigit().frame(minWidth: 20)
                                Button { store.changeQuantity(for: line, by: 1) } label: {
                                    Image(systemName: "plus.circle")
                                }
                            }
                            .buttonStyle(.borderless)
                            Text(line.lineTotal, format: .currency(code: "EUR"))
                                .fontWeight(.semibold).frame(width: 82, alignment: .trailing)
                        }
                        .padding(.vertical, 5)
                    }
                    .onDelete { offsets in
                        for index in offsets {
                            if store.cart.indices.contains(index) {
                                store.remove(store.cart[index])
                            }
                        }
                    }
                }
                .listStyle(.plain)
            }

            Divider()
            VStack(spacing: 14) {
                HStack {
                    Text("TOTAAL").font(.caption.weight(.bold)).tracking(1.2)
                    Spacer()
                    Text(store.total, format: .currency(code: "EUR"))
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .monospacedDigit()
                }
                Button {
                    store.finishDemoSale()
                    showReceipt = store.latestReceipt != nil
                } label: {
                    Label("DEMO-AFREKENEN", systemImage: "creditcard.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity).padding(.vertical, 17)
                }
                .buttonStyle(.borderedProminent)
                .tint(green)
                .disabled(store.cart.isEmpty)
                Text("DEMO — er wordt nog geen echte betaling uitgevoerd.")
                    .font(.caption2).foregroundStyle(.secondary)
            }
            .padding(24)
        }
        .background(Color(uiColor: .systemBackground))
    }
}

struct AddProductView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var price = ""
    @State private var error: String?
    let onSave: (String, String) -> String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Nieuw product") {
                    TextField("Productnaam", text: $name)
                    TextField("Prijs (bijv. 1,49)", text: $price)
                        .keyboardType(.decimalPad)
                }
                if let error {
                    Text(error).foregroundStyle(.red)
                }
            }
            .navigationTitle("Product toevoegen")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuleren") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Opslaan") {
                        if let message = onSave(name, price) {
                            error = message
                        } else {
                            dismiss()
                        }
                    }
                    .fontWeight(.bold)
                }
            }
        }
    }
}

struct ReceiptView: View {
    @Environment(\.dismiss) private var dismiss
    let receipt: Receipt

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 48)).foregroundStyle(.green)
                Text("VEDO").font(.largeTitle.weight(.black))
                Text("Digitale kassabon").font(.title3.weight(.semibold))
                Text(receipt.date.formatted(date: .long, time: .shortened))
                    .font(.caption).foregroundStyle(.secondary)
                Divider()
                ForEach(receipt.lines) { line in
                    HStack {
                        Text("\(line.quantity) × \(line.product.name)")
                        Spacer()
                        Text(line.lineTotal, format: .currency(code: "EUR"))
                    }
                }
                Divider()
                HStack {
                    Text("TOTAAL").font(.headline)
                    Spacer()
                    Text(receipt.total, format: .currency(code: "EUR"))
                        .font(.title2.bold())
                }
                Spacer()
                Text("Prototypebon — geen betalingsbewijs.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            .padding(24)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Sluiten") { dismiss() }
                }
            }
        }
    }
}
