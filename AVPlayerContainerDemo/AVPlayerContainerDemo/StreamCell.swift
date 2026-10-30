//
//  StreamCell.swift
//  AVPlayerContainerDemo
//
//  Created by Александр Алгашев on 21.10.2026.
//

import UIKit

/**
 Ячейка таблицы с информацией о потока вещания.

 Отображает состояние потока в отдельном блоке фиксированной ширины:
 эмодзи результата, индикатор проверки или пустоту. Переключение состояний
 выполняется плавным переходом. Рядом показывается название канала.
 */
final class StreamCell: UITableViewCell {
    /**
     Идентификатор для повторного использования ячейки.
     */
    static let reuseIdentifier = "StreamCell"

    /**
     Блок состояния фиксированной ширины.

     Содержит эмодзи и индикатор проверки, переключаемые плавным переходом.
     */
    private let statusView = UIView()
    /**
     Метка с эмодзи состояния потока.
     */
    private let emojiLabel = UILabel()
    /**
     Индикатор проверки потока.
     */
    private let activityIndicator = UIActivityIndicatorView(style: .medium)
    /**
     Метка с названием канала.
     */
    private let titleLabel = UILabel()
    /**
     Представление с логотипом канала.

     Изображение задаётся владельцем — контроллером плейлиста,
     который загружает его по адресу из атрибута `tvg-logo`.
     */
    private let logoImageView = UIImageView()
    /**
     Стек с содержимым ячейки: название канала и блок состояния.
     */
    private let stackView = UIStackView()
    /**
     Флаг первой настройки после создания или переиспользования.

     Пока флаг установлен, содержимое задаётся без анимации.
     */
    private var needsInitialConfiguration = true

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        // фон прозрачный только в обычном состоянии, при выделении — системная подсветка
        self.configurationUpdateHandler = { cell, state in
            var background = UIBackgroundConfiguration.listPlainCell().updated(for: state)
            background.backgroundColor = #colorLiteral(red: 0.6396284814, green: 0.8267727494, blue: 0.4965181588, alpha: 1)
            if !state.isSelected && !state.isHighlighted {
                background.backgroundColor = .clear
            }
            cell.backgroundConfiguration = background
        }
        self.setupSubviews()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) не поддерживается")
    }

    override func prepareForReuse() {
        super.prepareForReuse()

        // сброс содержимого без анимации перед переиспользованием
        self.needsInitialConfiguration = true
        self.emojiLabel.text = nil
        self.emojiLabel.isHidden = true
        self.activityIndicator.stopAnimating()
        self.logoImageView.image = nil
        self.logoImageView.isHidden = true
    }

    /**
     Отображает логотип канала.

     - Parameter image: Логотип канала. `nil` скрывает логотип.
     */
    func setLogo(_ image: UIImage?) {
        self.logoImageView.image = image
        self.logoImageView.isHidden = image == nil
    }

    /**
     Заполняет ячейку данными потока.

     При первой настройке после создания или переиспользования содержимое
     задаётся без анимации. При последующих вызовах переключение состояния
     выполняется плавным переходом. Логотип канала задаётся отдельно
     методом `setLogo`.

     - Parameter stream: Поток вещания.
     */
    func configure(with stream: Stream) {
        let animated = !self.needsInitialConfiguration
        self.needsInitialConfiguration = false

        self.titleLabel.text = stream.title
        self.updateStatus(stream.status, animated: animated)
    }

    /**
     Создаёт и настраивает представления ячейки.
     */
    private func setupSubviews() {
        self.emojiLabel.isHidden = true
        self.emojiLabel.translatesAutoresizingMaskIntoConstraints = false

        self.titleLabel.numberOfLines = 1

        self.logoImageView.contentMode = .scaleAspectFit
        self.logoImageView.isHidden = true
        self.logoImageView.translatesAutoresizingMaskIntoConstraints = false

        self.activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        self.statusView.translatesAutoresizingMaskIntoConstraints = false
        self.statusView.addSubview(self.emojiLabel)
        self.statusView.addSubview(self.activityIndicator)
        NSLayoutConstraint.activate([
            self.statusView.widthAnchor.constraint(equalToConstant: 28.0),
            self.statusView.heightAnchor.constraint(equalToConstant: 28.0),
            self.emojiLabel.centerXAnchor.constraint(equalTo: self.statusView.centerXAnchor),
            self.emojiLabel.centerYAnchor.constraint(equalTo: self.statusView.centerYAnchor),
            self.activityIndicator.centerXAnchor.constraint(equalTo: self.statusView.centerXAnchor),
            self.activityIndicator.centerYAnchor.constraint(equalTo: self.statusView.centerYAnchor)
        ])

        self.stackView.axis = .horizontal
        self.stackView.alignment = .center
        self.stackView.spacing = 8
        self.stackView.translatesAutoresizingMaskIntoConstraints = false
        self.stackView.addArrangedSubview(self.logoImageView)
        self.stackView.addArrangedSubview(self.titleLabel)
        self.stackView.addArrangedSubview(self.statusView)
        NSLayoutConstraint.activate([
            self.logoImageView.widthAnchor.constraint(equalToConstant: 28.0),
            self.logoImageView.heightAnchor.constraint(equalToConstant: 28.0)
        ])

        self.contentView.addSubview(self.stackView)
        let layoutMarginsGuide = self.contentView.layoutMarginsGuide
        NSLayoutConstraint.activate([
            self.stackView.leadingAnchor.constraint(equalTo: layoutMarginsGuide.leadingAnchor),
            self.stackView.trailingAnchor.constraint(equalTo: layoutMarginsGuide.trailingAnchor),
            self.stackView.topAnchor.constraint(equalTo: layoutMarginsGuide.topAnchor),
            self.stackView.bottomAnchor.constraint(equalTo: layoutMarginsGuide.bottomAnchor)
        ])
    }

    /**
     Обновляет отображение состояния потока.

     Состояние показывается в блоке состояния: эмодзи результата, индикатор
     проверки или пустота. Переключение выполняется плавным переходом.
     Название канала с ошибкой отображается бледным шрифтом.

     - Parameter status: Состояние потока.
     - Parameter animated: Флаг, показывающий, нужно ли анимировать изменение.
     */
    private func updateStatus(_ status: Stream.Status, animated: Bool) {
        var isProcessing = false
        if case .processing = status {
            isProcessing = true
        }
        // название канала с ошибкой отображается бледным шрифтом
        var isFailed = false
        if case .failed = status {
            isFailed = true
        }
        let emoji = status.emoji

        let applyChanges = {
            self.emojiLabel.text = emoji
            self.emojiLabel.isHidden = emoji == nil
            self.titleLabel.textColor = isFailed ? .secondaryLabel : .label
            if isProcessing {
                self.activityIndicator.startAnimating()
            } else {
                self.activityIndicator.stopAnimating()
            }
        }
        guard animated else {
            applyChanges()
            return
        }

        // плавное переключение: эмодзи, индикатор или пустота
        UIView.transition(
            with: self.statusView,
            duration: 0.25,
            options: [.transitionCrossDissolve, .beginFromCurrentState, .allowUserInteraction],
            animations: applyChanges
        )
    }


}
