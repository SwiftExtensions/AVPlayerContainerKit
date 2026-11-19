//
//  TimeoutPickerViewController.swift
//  AVPlayerContainerDemo
//
//  Created by Александр Алгашев on 13.11.2026.
//

import UIKit

/**
 Контроллер выбора времени ожидания.

 Отображает доступные значения времени ожидания. Выбранное значение
 передаётся владельцу замыканием — владелец сохраняет его в стандартных
 настройках пользователя.
 */
final class TimeoutPickerViewController: UITableViewController {
    /**
     Идентификатор ячейки значения.
     */
    private static let reuseIdentifier = "TimeoutCell"
    /**
     Доступные значения времени ожидания в секундах.
     */
    private let timeouts: [TimeInterval]
    /**
     Текст подвала секции.
     */
    private let footerTitle: String
    /**
     Текущее значение времени ожидания в секундах.
     */
    private let selectedTimeout: TimeInterval
    /**
     Сообщает владельцу выбранное значение времени ожидания.
     */
    private let onSelect: (TimeInterval) -> Void

    /**
     Создаёт контроллер выбора времени ожидания.

     - Parameter title: Заголовок экрана.
     - Parameter timeouts: Доступные значения времени ожидания в секундах.
     - Parameter footerTitle: Текст подвала секции с описанием настройки.
     - Parameter selectedTimeout: Текущее значение времени ожидания в секундах.
     - Parameter onSelect: Замыкание, вызываемое с выбранным значением.
     */
    init(
        title: String,
        timeouts: [TimeInterval],
        footerTitle: String,
        selectedTimeout: TimeInterval,
        onSelect: @escaping (TimeInterval) -> Void
    ) {
        self.timeouts = timeouts
        self.footerTitle = footerTitle
        self.selectedTimeout = selectedTimeout
        self.onSelect = onSelect
        super.init(style: .insetGrouped)
        self.title = title
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) не поддерживается")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        self.tableView.register(UITableViewCell.self, forCellReuseIdentifier: Self.reuseIdentifier)
    }

    // MARK: - Table view data source

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        self.timeouts.count
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        self.footerTitle
    }

    override func tableView(
        _ tableView: UITableView,
        cellForRowAt indexPath: IndexPath
    ) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(
            withIdentifier: Self.reuseIdentifier,
            for: indexPath
        )
        let timeout = self.timeouts[indexPath.row]
        var configuration = cell.defaultContentConfiguration()
        configuration.text = "\(Int(timeout)) с"
        cell.contentConfiguration = configuration
        cell.accessoryType = timeout == self.selectedTimeout ? .checkmark : .none

        return cell
    }

    // MARK: - Table view delegate

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        self.onSelect(self.timeouts[indexPath.row])
        self.navigationController?.popViewController(animated: true)
    }


}


