//
//  ChannelOverlayView.swift
//  AVPlayerContainerDemo
//
//  Created by Александр Алгашев on 13.11.2026.
//

import UIKit

/**
 Оверлей переключения канала поверх плеера.

 По центру плеера показывает логотип канала, под ним — название.
 Через короткое время представление уменьшается и исчезает. Повторный
 показ сбрасывает таймер исчезновения.
 */
final class ChannelOverlayView: UIView {
    /**
     Время показа оверлея до начала исчезновения.
     */
    private static let displayDuration: TimeInterval = 2.5

    /**
     Вертикальный стек с логотипом и названием канала.
     */
    private let stackView = UIStackView()
    /**
     Представление с логотипом канала.
     */
    private let logoImageView = UIImageView()
    /**
     Метка с названием канала.
     */
    private let titleLabel = UILabel()
    
    /**
     Задача отложенного исчезновения.

     Отменяется при повторном показе, чтобы новый канал оставался
     на экране положенное время.
     */
    private var hideTask: Task<Void, Never>?
    /**
     Адрес потока, для которого показан оверлей.

     Защищает от применения логотипа, загруженного для уже
     переключённого канала.
     */
    private var streamURL: URL?

    init() {
        super.init(frame: .zero)

        self.isUserInteractionEnabled = false
        self.setupSubviews()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) не поддерживается")
    }

    /**
     Показывает оверлей с названием канала.

     Логотип задаётся отдельно методом `setLogo(_:for:)` — он может
     загружаться по сети. Через `displayDuration` секунд оверлей
     уменьшается и исчезает.

     - Parameter stream: Поток вещания, переключённый на воспроизведение.
     */
    func show(stream: Stream) {
        self.streamURL = stream.url
        self.titleLabel.text = stream.title
        self.logoImageView.image = nil
        self.logoImageView.isHidden = true
        self.hideTask?.cancel()

        self.isHidden = false
        self.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
        self.alpha = 0.0
        UIView.animate(
            withDuration: 0.25,
            delay: 0.0,
            options: [.curveEaseOut, .beginFromCurrentState]
        ) {
            self.transform = .identity
            self.alpha = 1.0
        }
        self.scheduleHiding()
    }
    /**
     Отображает логотип канала, если оверлей всё ещё показывает его поток.

     - Parameter image: Загруженный логотип канала.
     - Parameter url: Адрес потока, для которого загружался логотип.
     */
    func setLogo(_ image: UIImage, for url: URL) {
        guard self.streamURL == url else { return }
        self.logoImageView.image = image
        self.logoImageView.isHidden = false
    }
    /**
     Создаёт и настраивает представления оверлея.
     */
    private func setupSubviews() {
        self.logoImageView.contentMode = .scaleAspectFit
        self.logoImageView.isHidden = true

        self.titleLabel.font = .preferredFont(forTextStyle: .title2)
        self.titleLabel.textColor = .white
        self.titleLabel.textAlignment = .center
        self.titleLabel.numberOfLines = 2
        self.titleLabel.shadowColor = UIColor.black.withAlphaComponent(0.6)
        self.titleLabel.shadowOffset = CGSize(width: 0.0, height: 1.0)

        self.stackView.axis = .vertical
        self.stackView.alignment = .center
        self.stackView.spacing = 12.0
        self.stackView.translatesAutoresizingMaskIntoConstraints = false
        self.stackView.addArrangedSubview(self.logoImageView)
        self.stackView.addArrangedSubview(self.titleLabel)
        self.addSubview(self.stackView)
        NSLayoutConstraint.activate([
            self.logoImageView.widthAnchor.constraint(lessThanOrEqualToConstant: 96.0),
            self.logoImageView.heightAnchor.constraint(lessThanOrEqualToConstant: 96.0),
            self.stackView.leadingAnchor.constraint(equalTo: self.leadingAnchor),
            self.stackView.trailingAnchor.constraint(equalTo: self.trailingAnchor),
            self.stackView.topAnchor.constraint(equalTo: self.topAnchor),
            self.stackView.bottomAnchor.constraint(equalTo: self.bottomAnchor)
        ])
    }
    /**
     Планирует исчезновение оверлея через `displayDuration` секунд.
     */
    private func scheduleHiding() {
        self.hideTask = Task { @MainActor [weak self] in
            let nanoseconds = UInt64(Self.displayDuration * 1_000_000_000)
            try? await Task.sleep(nanoseconds: nanoseconds)
            guard !Task.isCancelled else { return }
            self?.hide()
        }
    }
    /**
     Уменьшает и скрывает оверлей плавным переходом.
     */
    private func hide() {
        UIView.animate(
            withDuration: 0.4,
            delay: 0.0,
            options: [.curveEaseIn, .beginFromCurrentState]
        ) {
            self.transform = CGAffineTransform(scaleX: 0.5, y: 0.5)
            self.alpha = 0.0
        } completion: { _ in
            self.isHidden = true
        }
    }


}
