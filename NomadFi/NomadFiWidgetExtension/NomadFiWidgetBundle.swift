import SwiftUI
import WidgetKit

@main
struct NomadFiWidgetBundle: WidgetBundle {
    var body: some Widget {
        NomadFiDashboardWidget()
        NomadFiLockScreenWidget()
        AIIntakeControlWidget()
        DraftCaptureControlWidget()
    }
}
