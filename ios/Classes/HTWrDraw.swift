//
//  HTWrDraw.swift
//  HTKLineView
//
//  Created by hublot on 2020/3/17.
//  Copyright © 2020 hublot. All rights reserved.
//

import UIKit

class HTWrDraw: NSObject, HTKLineDrawProtocol {

    func minMaxRange(_ visibleModelArray: [HTKLineModel], _ configManager: HTKLineConfigManager) -> Range<CGFloat> {
        var maxValue = CGFloat.leastNormalMagnitude
        var minValue = CGFloat.greatestFiniteMagnitude

        for model in visibleModelArray {
            let valueList = model.wrList.map { (item) -> CGFloat in
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
        // Protect against temporary mismatches between `configManager.wrList` and
        // the per‑candle `model.wrList`/`lastModel.wrList` (for example when WR is
        // toggled on before the data payload has been updated). In that case we just
        // skip drawing instead of crashing with an index out of range.
        guard !configManager.wrList.isEmpty,
              !model.wrList.isEmpty,
              !lastModel.wrList.isEmpty else {
            return
        }

        for itemModel in configManager.wrList {
            let idx = itemModel.index
            guard idx >= 0,
                  idx < model.wrList.count,
                  idx < lastModel.wrList.count,
                  idx < configManager.targetColorList.count else {
                continue
            }
            let color = configManager.targetColorList[idx]
            drawLine(
                value: model.wrList[idx].value,
                lastValue: lastModel.wrList[idx].value,
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
        guard !configManager.wrList.isEmpty, !model.wrList.isEmpty else {
            return
        }
        for itemModel in configManager.wrList {
            let idx = itemModel.index
            guard idx >= 0,
                  idx < model.wrList.count,
                  idx < configManager.targetColorList.count else {
                continue
            }
            let item = model.wrList[idx]
            let title = String(format: "WR(%@):%@", item.title, configManager.precision(item.value, -1))
            let color = configManager.targetColorList[idx]
            x += drawText(title: title, point: CGPoint.init(x: x, y: baseY), color: color, font: font, context: context, configManager: configManager)
            x += 5
        }
    }

    func drawValue(_ maxValue: CGFloat, _ minValue: CGFloat, _ baseX: CGFloat, _ baseY: CGFloat, _ height: CGFloat, _ context: CGContext, _ configManager: HTKLineConfigManager) {
        drawValue(maxValue, minValue, baseX, baseY, height, 0, -1, context, configManager)
    }


}
