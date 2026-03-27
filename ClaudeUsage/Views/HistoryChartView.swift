import SwiftUI
import Charts

struct HistoryChartView: View {
    @ObservedObject private var store = HistoryStore.shared

    enum TimeRange: String, CaseIterable {
        case day = "24h"
        case week = "7d"

        var lookback: TimeInterval {
            switch self {
            case .day:  return 24 * 3600
            case .week: return 7 * 24 * 3600
            }
        }
    }

    @State private var selectedRange: TimeRange = .day

    private var filteredSnapshots: [HistorySnapshot] {
        let cutoff = Date().addingTimeInterval(-selectedRange.lookback)
        return store.snapshots(since: cutoff)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center) {
                Text("History")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)

                Spacer()

                Picker("", selection: $selectedRange) {
                    ForEach(TimeRange.allCases, id: \.self) { range in
                        Text(range.rawValue).tag(range)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 80)
            }

            if filteredSnapshots.isEmpty {
                Text("No history yet — data appears after the first refresh")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .frame(height: 80)
            } else {
                Chart {
                    ForEach(filteredSnapshots) { snap in
                        LineMark(
                            x: .value("Time", snap.timestamp),
                            y: .value("Utilization", snap.sessionUtilization)
                        )
                        .foregroundStyle(by: .value("Limit", "5h"))
                        .interpolationMethod(.monotone)

                        LineMark(
                            x: .value("Time", snap.timestamp),
                            y: .value("Utilization", snap.weeklyUtilization)
                        )
                        .foregroundStyle(by: .value("Limit", "7d"))
                        .interpolationMethod(.monotone)
                    }
                }
                .chartForegroundStyleScale(["5h": Color.blue, "7d": Color.orange])
                .chartYScale(domain: 0...100)
                .chartYAxis {
                    AxisMarks(values: [0, 25, 50, 75, 100]) { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let val = value.as(Int.self) {
                                Text("\(val)%")
                                    .font(.system(size: 8))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                .chartLegend(position: .topTrailing, alignment: .topTrailing, spacing: 4)
                .frame(height: 100)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Constants.Colors.cardBackground)
        .cornerRadius(6)
    }
}
