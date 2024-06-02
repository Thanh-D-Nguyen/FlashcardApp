//
//  FlashcardPreset.swift
//  FlashcardApp
//
//  Created by タイン・グエン on 2024/06/02.
//

import UIKit

public struct FlashCardPreset: SegmentedControlPresettable {
    
    public var segmentStyle: SegmentStylable
    public var segmentItemStyle: SegmentItemStylable
    public var segmentSelectedItemStyle: SegmentSelectedItemStylable
    
    public init(backgroundColor: UIColor = .white,
                selectedBackgroundColor: UIColor = .yellow,
                textColor: UIColor = .darkGray,
                tintColor: UIColor = .darkGray,
                selectedTextColor: UIColor = .black,
                selectedTintColor: UIColor = .black,
                cornerRadius: CGFloat) {
        segmentStyle = SegmentStyle()
        segmentItemStyle = SegmentItemStyle(backgroundColor: backgroundColor, textColor: textColor, tintColor: tintColor, selectedTextColor: selectedTextColor, selectedTintColor: selectedTintColor)
        segmentSelectedItemStyle = SegmentSelectedItemStyle(backgroundColor: selectedBackgroundColor, cornerRadius: cornerRadius, borderWidth: 0.0, borderColor: nil, size: .max, offset: -1.0, shadow: nil)
    }
    
}
