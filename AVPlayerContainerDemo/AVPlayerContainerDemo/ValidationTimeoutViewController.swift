//
//  ValidationTimeoutViewController.swift
//  AVPlayerContainerDemo
//
//  Created by Александр Алгашев on 13.11.2026.
//

import UIKit

/**
 Контроллер выбора времени проверки потока.

 Отображает доступные значения времени ожидания проверки. Выбранное
 значение применяется к следующим проверкам и сохраняется в стандартных
 настройках пользователя.
 */
final class ValidationTimeoutViewController: UITableViewController {
    /**
     Сервис плейлиста.
     */
    private let playlistService: PlaylistService
    /**
     Идентификатор ячейки значения.
     */
    private static let reuseIdentifier = "TimeoutCell"
    /**
     Доступные значения времени проверки потока в секундах.
     */
    private static let timeouts: [TimeInterval] = [3, 5, 10, 15, 30]

    /**
     Создаёт контроллер выбора времени проверки потока.

     - Parameter service: Сервис плейлиста.
     */
    init(service: PlaylistService) {
        self.playlistService = service
        super.init(style: .insetGrouped)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) не поддерживается")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        self.title = "Время проверки"
        self.tableView.register(UITableViewCell.self, forCellReuseIdentifier: Self.reuseIdentifier)
    }

    // MARK: - Table view data source

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        Self.timeouts.count
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        "Максимальное время ожидания проверки одного потока. Применяется к следующим проверкам."
    }

    override func tableView(
        _ tableView: UITableView,
        cellForRowAt indexPath: IndexPath
    ) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(
            withIdentifier: Self.reuseIdentifier,
            for: indexPath
        )
        let timeout = Self.timeouts[indexPath.row]
        var configuration = cell.defaultContentConfiguration()
        configuration.text = "\(Int(timeout)) с"
        cell.contentConfiguration = configuration
        cell.accessoryType = timeout == self.playlistService.validationTimeout ? .checkmark : .none

        return cell
    }

    // MARK: - Table view delegate

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        self.playlistService.setValidationTimeout(Self.timeouts[indexPath.row])
        self.navigationController?.popViewController(animated: true)
    }


}


