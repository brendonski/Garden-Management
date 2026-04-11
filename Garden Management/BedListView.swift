//
//  BedListView.swift
//  Garden Management
//
//  Created by Brendon Kelly on 6/4/2026.
//

import SwiftUI
import SwiftData

struct BedListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Bed.name) private var beds: [Bed]
    @State private var showingAddBed = false
    @State private var newBedName = ""
    
    var body: some View {
        NavigationViewWrapper {
            List {
                ForEach(beds) { bed in
                    NavigationLink {
                        BedDetailView(bed: bed)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(bed.displayName)
                                .font(.headline)
                            HStack(spacing: 8) {
                                Text("\(bed.rows.count) \(bed.rows.count == 1 ? "row" : "rows")")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text("•")
                                    .foregroundStyle(.secondary)
                                Text("\(bed.plants.count) \(bed.plants.count == 1 ? "plant" : "plants")")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                .onDelete(perform: deleteBeds)
            }
#if os(macOS)
            .navigationSplitViewColumnWidth(min: 180, ideal: 200)
#endif
            .navigationTitle("Garden Beds")
            .toolbar {
                ToolbarItem {
                    Button(action: { showingAddBed = true }) {
                        Label("Add Bed", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddBed) {
                AddBedSheet(isPresented: $showingAddBed)
            }
            .overlay {
                if beds.isEmpty {
                    ContentUnavailableView(
                        "No Beds Yet",
                        systemImage: "square.grid.3x3",
                        description: Text("Add your first bed to get started")
                    )
                }
            }
        }
    }
    
    private func deleteBeds(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(beds[index])
            }
        }
    }
}

fileprivate struct NavigationViewWrapper<Content: View>: View {
    let content: () -> Content
    
    var body: some View {
#if os(macOS)
        NavigationSplitView {
            content()
        } detail: {
            Text("Select a bed")
                .foregroundStyle(.secondary)
        }
#else
        NavigationStack {
            content()
        }
#endif
    }
}

struct AddBedSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Binding var isPresented: Bool
    @State private var bedName = ""
    @State private var positionCount = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Bed Name", text: $bedName)
#if os(iOS)
                        .textInputAutocapitalization(.words)
#endif
                    
                    TextField("Number of positions per row", text: $positionCount)
#if os(iOS)
                        .keyboardType(.numberPad)
#endif
                } header: {
                    Text("Bed Details")
                } footer: {
                    Text("Number of positions in each row of this bed")
                }
            }
            .navigationTitle("Add Bed")
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        addBed()
                    }
                    .disabled(!isValid)
                }
            }
        }
#if os(macOS)
        .frame(minWidth: 400, minHeight: 250)
#endif
    }
    
    private var isValid: Bool {
        !bedName.trimmingCharacters(in: .whitespaces).isEmpty &&
        Int(positionCount) != nil &&
        Int(positionCount)! > 0
    }
    
    private func addBed() {
        guard let count = Int(positionCount) else { return }
        
        withAnimation {
            let bed = Bed(name: bedName.trimmingCharacters(in: .whitespaces), positionCount: count)
            modelContext.insert(bed)
            isPresented = false
        }
    }
}

#Preview("Bed List") {
    BedListView()
        .modelContainer(for: Bed.self, inMemory: true)
}

#Preview("Add Bed Sheet") {
    AddBedSheet(isPresented: .constant(true))
        .modelContainer(for: Bed.self, inMemory: true)
}
