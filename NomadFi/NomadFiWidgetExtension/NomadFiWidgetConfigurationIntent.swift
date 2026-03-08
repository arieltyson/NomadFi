import AppIntents

struct NomadFiWidgetConfigurationIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "NomadFi Dashboard"
    static let description = IntentDescription(
        "Displays your global net worth and top accounts across jurisdictions."
    )
}
