//
//  QuietAppsPicker.swift
//  Snoozly
//
//  One app picker that Settings, Schedule and Tonight all use, so choosing apps
//  anywhere switches Quiet Apps on and keeps every screen in agreement.
//

import SwiftUI
import FamilyControls

private struct QuietAppsPickerModifier: ViewModifier {
    let plan: SleepPlan?
    @Binding var isPresented: Bool

    @State private var selection = FamilyActivitySelection()

    func body(content: Content) -> some View {
        content
            .familyActivityPicker(isPresented: $isPresented, selection: $selection)
            .onAppear(perform: loadSaved)
            .onChange(of: isPresented) { _, presented in
                if presented { loadSaved() }
            }
            .onChange(of: selection) { _, newValue in
                guard let plan else { return }
                ScreenTimeService.didChooseApps(newValue, for: plan)
            }
    }

    private func loadSaved() {
        guard let plan else { return }
        selection = ScreenTimeService.savedSelection(for: plan)
    }
}

extension View {
    func quietAppsPicker(for plan: SleepPlan?, isPresented: Binding<Bool>) -> some View {
        modifier(QuietAppsPickerModifier(plan: plan, isPresented: isPresented))
    }
}
