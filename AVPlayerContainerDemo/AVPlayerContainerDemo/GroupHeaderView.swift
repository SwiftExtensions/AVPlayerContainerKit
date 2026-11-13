//
//  GroupHeaderView.swift
//  AVPlayerContainerDemo
//
//  Created by Александр Алгашев on 28.10.2026.
//

import UIKit

/**
 Вид заголовка группы потоков вещания.

 Отображает заголовок группы и количество потоков в ней на подложке
 фиксированного цвета.
 */
final class GroupHeaderView: UITableViewHeaderFooterView {
    /**
     Идентификатор для повторного использования вида заголовка.
     */
    static let reuseIdentifier = "GroupHeaderView"

    /**
     Метка с заголовком группы и количеством потоков.
     */
    private let titleLabel = UILabel()

    /**
     Создаёт вид заголовка с идентификатором по умолчанию.
     */
    convenience init() {
        self.init(reuseIdentifier: Self.reuseIdentifier)
    }

    override init(reuseIdentifier: String?) {
        super.init(reuseIdentifier: reuseIdentifier)

        var background = UIBackgroundConfiguration.listPlainHeaderFooter()
        background.backgroundColor = .groupHeader
        self.backgroundConfiguration = background
        self.setupSubviews()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) не поддерживается")
    }

    /**
     Заполняет заголовок данными группы.

     Изменение содержимого выполняется плавным переходом.

     - Parameter group: Группа потоков вещания.
     */
    func configure(with group: Group) {
        let title = group.title ?? "Untitled"
        let text = "\(title) (\(group.streams.count))"
        guard self.titleLabel.text != text else { return }
        
        UIView.transition(
            with: self.titleLabel,
            duration: 0.25,
            options: [.transitionCrossDissolve, .beginFromCurrentState],
            animations: { self.titleLabel.text = text }
        )
    }
    /**
     Создаёт и настраивает представления вида заголовка.
     */
    private func setupSubviews() {
        // длинный заголовок обрезается в начале: количество потоков остаётся видимым
        self.titleLabel.lineBreakMode = .byTruncatingHead
        self.titleLabel.numberOfLines = 1
        self.titleLabel.translatesAutoresizingMaskIntoConstraints = false
        self.contentView.addSubview(self.titleLabel)

        let layoutMarginsGuide = self.contentView.layoutMarginsGuide
        NSLayoutConstraint.activate([
            self.titleLabel.leadingAnchor.constraint(equalTo: layoutMarginsGuide.leadingAnchor),
            self.titleLabel.trailingAnchor.constraint(equalTo: layoutMarginsGuide.trailingAnchor),
            self.titleLabel.topAnchor.constraint(equalTo: layoutMarginsGuide.topAnchor),
            self.titleLabel.bottomAnchor.constraint(equalTo: layoutMarginsGuide.bottomAnchor)
        ])
    }


}
