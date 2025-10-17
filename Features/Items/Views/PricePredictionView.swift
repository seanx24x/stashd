//
//  PricePredictionView.swift
//  stashd
//
//  Created by Sean Lynch on 10/17/25.
//


//
//  PricePredictionView.swift
//  stashd
//
//  Created by Sean Lynch
//

import SwiftUI
import Charts

struct PricePredictionView: View {
    let item: CollectionItem
    
    @State private var prediction: PricePredictionService.PricePrediction?
    @State private var isLoading = false
    @State private var error: String?
    
    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.xLarge) {
                if isLoading {
                    loadingView
                } else if let prediction = prediction {
                    predictionContent(prediction)
                } else if let error = error {
                    errorView(error)
                } else {
                    placeholderView
                }
            }
            .padding(Spacing.large)
        }
        .navigationTitle("Price Prediction")
        .navigationBarTitleDisplayMode(.large)
        .task {
            await loadPrediction()
        }
    }
    
    // MARK: - Prediction Content
    
    @ViewBuilder
    private func predictionContent(_ prediction: PricePredictionService.PricePrediction) -> some View {
        // Current Value Card
        currentValueCard(prediction)
        
        // Trend Indicator
        trendCard(prediction.trend)
        
        // Price Chart
        priceChart(prediction)
        
        // Predictions Table
        predictionsTable(prediction)
        
        // AI Reasoning
        reasoningCard(prediction)
        
        // Confidence Score
        confidenceCard(prediction.confidence)
    }
    
    // MARK: - Current Value Card
    
    private func currentValueCard(_ prediction: PricePredictionService.PricePrediction) -> some View {
        VStack(spacing: Spacing.medium) {
            Text("Current Estimated Value")
                .font(.labelLarge)
                .foregroundStyle(.textSecondary)
            
            Text(formatCurrency(prediction.currentValue))
                .font(.system(size: 48, weight: .bold))
                .foregroundStyle(Color.stashdPrimary)
        }
        .frame(maxWidth: .infinity)
        .padding(Spacing.large)
        .background(Color.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.large))
    }
    
    // MARK: - Trend Card
    
    private func trendCard(_ trend: PricePredictionService.PriceTrend) -> some View {
        HStack(spacing: Spacing.medium) {
            Image(systemName: trend.icon)
                .font(.title2)
                .foregroundStyle(trendColor(trend))
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Market Trend")
                    .font(.labelMedium)
                    .foregroundStyle(.textSecondary)
                
                Text(trendDescription(trend))
                    .font(.bodyLarge.weight(.semibold))
                    .foregroundStyle(.textPrimary)
            }
            
            Spacer()
        }
        .padding(Spacing.medium)
        .background(Color.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.large))
    }
    
    // MARK: - Price Chart
    
    private func priceChart(_ prediction: PricePredictionService.PricePrediction) -> some View {
        VStack(alignment: .leading, spacing: Spacing.medium) {
            Text("Value Over Time")
                .font(.headlineSmall.weight(.semibold))
                .foregroundStyle(.textPrimary)
            
            Chart {
                // Current value point
                PointMark(
                    x: .value("Time", "Now"),
                    y: .value("Price", Double(truncating: prediction.currentValue as NSDecimalNumber))
                )
                .foregroundStyle(Color.stashdPrimary)
                .symbolSize(100)
                
                // Prediction points
                ForEach(Array(prediction.predictions.keys.sorted(by: { $0.months < $1.months })), id: \.self) { period in
                    if let predicted = prediction.predictions[period] {
                        LineMark(
                            x: .value("Time", period.rawValue),
                            y: .value("Price", Double(truncating: predicted.value as NSDecimalNumber))
                        )
                        .foregroundStyle(Color.stashdPrimary)
                        .lineStyle(StrokeStyle(lineWidth: 3))
                        
                        PointMark(
                            x: .value("Time", period.rawValue),
                            y: .value("Price", Double(truncating: predicted.value as NSDecimalNumber))
                        )
                        .foregroundStyle(Color.stashdPrimary)
                        .symbolSize(80)
                        
                        // Confidence range area
                        AreaMark(
                            x: .value("Time", period.rawValue),
                            yStart: .value("Low", Double(truncating: predicted.lowEstimate as NSDecimalNumber)),
                            yEnd: .value("High", Double(truncating: predicted.highEstimate as NSDecimalNumber))
                        )
                        .foregroundStyle(Color.stashdPrimary.opacity(0.2))
                    }
                }
            }
            .frame(height: 250)
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisValueLabel {
                        if let price = value.as(Double.self) {
                            Text(formatCurrency(Decimal(price)))
                                .font(.caption)
                        }
                    }
                }
            }
            .chartXAxis {
                AxisMarks { value in
                    AxisValueLabel {
                        if let label = value.as(String.self) {
                            Text(label)
                                .font(.caption)
                        }
                    }
                }
            }
        }
        .padding(Spacing.medium)
        .background(Color.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.large))
    }
    
    // MARK: - Predictions Table
    
    private func predictionsTable(_ prediction: PricePredictionService.PricePrediction) -> some View {
        VStack(alignment: .leading, spacing: Spacing.medium) {
            Text("Future Value Predictions")
                .font(.headlineSmall.weight(.semibold))
                .foregroundStyle(.textPrimary)
            
            VStack(spacing: Spacing.small) {
                ForEach(Array(prediction.predictions.keys.sorted(by: { $0.months < $1.months })), id: \.self) { period in
                    if let predicted = prediction.predictions[period] {
                        predictionRow(
                            period: period.rawValue,
                            predicted: predicted
                        )
                    }
                }
            }
        }
        .padding(Spacing.medium)
        .background(Color.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.large))
    }
    
    private func predictionRow(period: String, predicted: PricePredictionService.PredictedValue) -> some View {
        VStack(spacing: Spacing.xSmall) {
            HStack {
                Text(period)
                    .font(.bodyMedium.weight(.semibold))
                    .foregroundStyle(.textPrimary)
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text(formatCurrency(predicted.value))
                        .font(.bodyLarge.weight(.bold))
                        .foregroundStyle(Color.stashdPrimary)
                    
                    Text(formatPercentage(predicted.percentageChange))
                        .font(.labelSmall)
                        .foregroundStyle(predicted.percentageChange >= 0 ? .green : .red)
                }
            }
            
            // Range indicator
            HStack(spacing: 4) {
                Text("Range:")
                    .font(.labelSmall)
                    .foregroundStyle(.textTertiary)
                
                Text("\(formatCurrency(predicted.lowEstimate)) - \(formatCurrency(predicted.highEstimate))")
                    .font(.labelSmall)
                    .foregroundStyle(.textSecondary)
                
                Spacer()
            }
        }
        .padding(Spacing.small)
        .background(Color.backgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
    }
    
    // MARK: - Reasoning Card
    
    private func reasoningCard(_ prediction: PricePredictionService.PricePrediction) -> some View {
        VStack(alignment: .leading, spacing: Spacing.medium) {
            HStack(spacing: Spacing.small) {
                Image(systemName: "brain.head.profile")
                    .foregroundStyle(Color.stashdPrimary)
                
                Text("AI Analysis")
                    .font(.headlineSmall.weight(.semibold))
                    .foregroundStyle(.textPrimary)
            }
            
            Text(prediction.reasoning)
                .font(.bodyMedium)
                .foregroundStyle(.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Spacing.medium)
        .background(Color.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.large))
    }
    
    // MARK: - Confidence Card
    
    private func confidenceCard(_ confidence: Int) -> some View {
        VStack(spacing: Spacing.medium) {
            HStack {
                Text("Prediction Confidence")
                    .font(.bodyLarge.weight(.semibold))
                    .foregroundStyle(.textPrimary)
                
                Spacer()
                
                Text("\(confidence)%")
                    .font(.headlineMedium.weight(.bold))
                    .foregroundStyle(confidenceColor(confidence))
            }
            
            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.backgroundSecondary)
                        .frame(height: 8)
                    
                    Rectangle()
                        .fill(confidenceColor(confidence))
                        .frame(width: geometry.size.width * CGFloat(confidence) / 100, height: 8)
                }
            }
            .frame(height: 8)
            .clipShape(Capsule())
            
            Text(confidenceDescription(confidence))
                .font(.labelSmall)
                .foregroundStyle(.textSecondary)
        }
        .padding(Spacing.medium)
        .background(Color.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.large))
    }
    
    // MARK: - Loading View
    
    private var loadingView: some View {
        VStack(spacing: Spacing.large) {
            ProgressView()
                .scaleEffect(1.5)
            
            Text("Analyzing market trends...")
                .font(.bodyLarge)
                .foregroundStyle(.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 100)
    }
    
    // MARK: - Error View
    
    private func errorView(_ error: String) -> some View {
        VStack(spacing: Spacing.medium) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundStyle(.red)
            
            Text("Prediction Failed")
                .font(.headlineMedium)
                .foregroundStyle(.textPrimary)
            
            Text(error)
                .font(.bodyMedium)
                .foregroundStyle(.textSecondary)
                .multilineTextAlignment(.center)
            
            Button {
                Task {
                    await loadPrediction()
                }
            } label: {
                Text("Try Again")
                    .font(.bodyMedium.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, Spacing.large)
                    .padding(.vertical, Spacing.medium)
                    .background(Color.stashdPrimary)
                    .clipShape(Capsule())
            }
        }
        .padding(Spacing.large)
    }
    
    // MARK: - Placeholder View
    
    private var placeholderView: some View {
        VStack(spacing: Spacing.medium) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 64))
                .foregroundStyle(Color.stashdPrimary)
            
            Text("Generate Price Prediction")
                .font(.headlineMedium)
                .foregroundStyle(.textPrimary)
            
            Text("Analyze market trends and predict future values")
                .font(.bodyMedium)
                .foregroundStyle(.textSecondary)
                .multilineTextAlignment(.center)
            
            Button {
                Task {
                    await loadPrediction()
                }
            } label: {
                Text("Generate Prediction")
                    .font(.bodyMedium.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, Spacing.large)
                    .padding(.vertical, Spacing.medium)
                    .background(Color.stashdPrimary)
                    .clipShape(Capsule())
            }
        }
        .padding(Spacing.large)
        .padding(.top, 100)
    }
    
    // MARK: - Actions
    
    private func loadPrediction() async {
        isLoading = true
        error = nil
        
        do {
            let result = try await PricePredictionService.shared.predictFutureValue(for: item)
            await MainActor.run {
                prediction = result
                isLoading = false
                HapticManager.shared.success()
            }
        } catch {
            await MainActor.run {
                self.error = error.localizedDescription
                isLoading = false
                HapticManager.shared.error()
            }
            print("❌ Prediction error: \(error)")
        }
    }
    
    // MARK: - Helper Methods
    
    private func formatCurrency(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 0
        return formatter.string(from: value as NSDecimalNumber) ?? "$\(value)"
    }
    
    private func formatPercentage(_ value: Double) -> String {
        let sign = value >= 0 ? "+" : ""
        return "\(sign)\(String(format: "%.1f", value))%"
    }
    
    private func trendColor(_ trend: PricePredictionService.PriceTrend) -> Color {
        switch trend {
        case .increasing: return .green
        case .decreasing: return .red
        case .stable: return .gray
        case .volatile: return .orange
        }
    }
    
    private func trendDescription(_ trend: PricePredictionService.PriceTrend) -> String {
        switch trend {
        case .increasing: return "Appreciating"
        case .decreasing: return "Depreciating"
        case .stable: return "Stable"
        case .volatile: return "Volatile Market"
        }
    }
    
    private func confidenceColor(_ confidence: Int) -> Color {
        if confidence >= 80 {
            return .green
        } else if confidence >= 60 {
            return .orange
        } else {
            return .red
        }
    }
    
    private func confidenceDescription(_ confidence: Int) -> String {
        if confidence >= 80 {
            return "High confidence - Strong historical data"
        } else if confidence >= 60 {
            return "Moderate confidence - Limited data available"
        } else {
            return "Low confidence - Insufficient market data"
        }
    }
}
