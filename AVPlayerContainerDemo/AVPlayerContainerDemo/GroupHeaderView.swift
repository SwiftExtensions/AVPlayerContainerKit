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
     Создаёт вид заголовка с идентификатором по умолчанию.
     */
    convenience init() {
        self.init(reuseIdentifier: Self.reuseIdentifier)
    }

    override init(reuseIdentifier: String?) {
        super.init(reuseIdentifier: reuseIdentifier)

        var background = UIBackgroundConfiguration.listPlainHeaderFooter()
        background.backgroundColor = #colorLiteral(red: 0.4666666687, green: 0.7647058964, blue: 0.2666666806, alpha: 1)
        self.backgroundConfiguration = background
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) не поддерживается")
    }

    /**
     Заполняет заголовок данными группы.
     - Parameter group: Группа потоков вещания.
     */
    func configure(with group: Group) {
        let title = group.title ?? "Untitled"
        self.textLabel?.text = "\(title) (\(group.streams.count))"
    }


}
