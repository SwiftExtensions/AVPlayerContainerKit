//
//  UnknownPlaybackError.swift
//  AVPlayerContainerDemo
//
//  Created by Александр Алгашев on 12.11.2026.
//

import Foundation

/**
 Ошибка воспроизведения без системной причины.
 */
struct UnknownPlaybackError: Error {
    /**
     Создаёт ошибку воспроизведения без системной причины.
     */
    init() {}


}

// MARK: - LocalizedError

extension UnknownPlaybackError: LocalizedError {
    var errorDescription: String? {
        "Неизвестная ошибка воспроизведения."
    }


}


