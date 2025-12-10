//
//  HTRsiDraw.swift
//  HTKLineView
//
//  Created by hublot on 2020/3/17.
//  Copyright © 2020 hublot. All rights reserved.
//

import UIKit

class HTRsiDraw: NSObject, HTKLineDrawProtocol {

    func minMaxRange(_ visibleModelArray: [HTKLineModel], _ configManager: HTKLineConfigManager) -> Range<CGFloat> {
        var maxValue = CGFloat.leastNormalMagnitude
        var minValue = CGFloat.greatestFiniteMagnitude

        for model in visibleModelArray {
            let valueList = model.rsiList.map { (item) -> CGFloat in
                return item.value
            }
            maxValue = max(maxValue, valueList.max() ?? 0)
            minValue = min(minValue, valueList.min() ?? 0)
        }
        return Range<CGFloat>.init(uncheckedBounds: (lower: minValue, upper: maxValue))
    }

    func drawCandle(_ model: HTKLineModel, _ index: Int, _ maxValue: CGFloat, _ minValue: CGFloat, _ baseY: CGFloat, _ height: CGFloat, _ context: CGContext, _ configManager: HTKLineConfigManager) {
    }

    func drawLine(_ model: HTKLineModel, _ lastModel: HTKLineModel, _ maxValue: CGFloat, _ minValue: CGFloat, _ baseY: CGFloat, _ height: CGFloat, _ index: Int, _ lastIndex: Int, _ context: CGContext, _ configManager: HTKLineConfigManager) {
        // Protect against temporary mismatches between `configManager.rsiList` and
        // the per‑candle `model.rsiList`/`lastModel.rsiList` (for example when RSI is
        // toggled on before the data payload has been updated). In that case we just
        // skip drawing instead of crashing with an index out of range.
        guard !configManager.rsiList.isEmpty,
              !model.rsiList.isEmpty,
              !lastModel.rsiList.isEmpty else {
            return
        }

        for itemModel in configManager.rsiList {
            let idx = itemModel.index
            guard idx >= 0,
                  idx < model.rsiList.count,
                  idx < lastModel.rsiList.count,
                  idx < configManager.targetColorList.count else {
                continue
            }
            let color = configManager.targetColorList[idx]
            drawLine(
                value: model.rsiList[idx].value,
                lastValue: lastModel.rsiList[idx].value,
                maxValue: maxValue,
                minValue: minValue,
                baseY: baseY,
                height: height,
                index: index,
                lastIndex: lastIndex,
                color: color,
                isBezier: false,
                context: context,
                configManager: configManager
            )
        }
    }

    func drawText(_ model: HTKLineModel, _ baseX: CGFloat, _ baseY: CGFloat, _ context: CGContext, _ configManager: HTKLineConfigManager) {
        var x = baseX
        let font = configManager.createFont(configManager.headerTextFontSize)
        guard !configManager.rsiList.isEmpty, !model.rsiList.isEmpty else {
            return
        }
        for itemModel in configManager.rsiList {
            let idx = itemModel.index
            guard idx >= 0,
                  idx < model.rsiList.count,
                  idx < configManager.targetColorList.count else {
                continue
            }
            let item = model.rsiList[idx]
            let title = String(format: "RSI(%@):%@", item.title, configManager.precision(item.value, -1))
            let color = configManager.targetColorList[idx]
            x += drawText(title: title, point: CGPoint.init(x: x, y: baseY), color: color, font: font, context: context, configManager: configManager)
            x += 5
        }
    }

    func drawValue(_ maxValue: CGFloat, _ minValue: CGFloat, _ baseX: CGFloat, _ baseY: CGFloat, _ height: CGFloat, _ context: CGContext, _ configManager: HTKLineConfigManager) {
        drawValue(maxValue, minValue, baseX, baseY, height, 0, -1, context, configManager)
    }


}
