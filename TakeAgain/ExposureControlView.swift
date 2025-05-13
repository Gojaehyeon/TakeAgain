//
//  ExposureControlView.swift
//  TakeAgain
//
//  Created by 고재현 on 5/13/25.
//

import SwiftUI

struct ExposureControlView: View {
    @Binding var exposureValue: Float
    let onExposureChanged: (Float) -> Void
    let position: CGPoint

    var body: some View {
        Image(systemName: "sun.max.fill")
            .foregroundColor(.yellow)
            .position(x: position.x, y: position.y + CGFloat(-exposureValue * 25))
    }
}
