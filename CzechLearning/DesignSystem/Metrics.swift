//
//  Metrics.swift
//  CzechVocab / DesignSystem
//
//  Отступы, радиусы и высоты с макетов холста.
//  Во вьюхах не должно быть числовых литералов размеров — только эти токены.
//

import SwiftUI

// MARK: - Отступы

enum AppSpacing {
    /// Горизонтальные поля всех экранов.
    static let screenInset: CGFloat = 16
    /// Паддинг крупной карточки — «Сегодня», карточка слова в сессии.
    static let cardPadding: CGFloat = 20
    /// Паддинг плитки, группы списка, графика.
    static let cardPaddingCompact: CGFloat = 16
    /// Горизонтальный отступ строки списка.
    static let rowInset: CGFloat = 16
    /// Инсет разделителя, когда в строке нет иконки.
    static let separatorInset: CGFloat = 16
    /// Инсет разделителя, когда слева стоит иконка 30 pt.
    static let separatorInsetWithIcon: CGFloat = 58

    /// Между смысловыми блоками экрана.
    static let section: CGFloat = 26
    /// Между карточками внутри блока.
    static let stack: CGFloat = 12
    /// Между кнопками оценки и чипами.
    static let tight: CGFloat = 8

    /// Верхний отступ контента. Статус-бар не рисуем — система кладёт свой поверх.
    static let safeTop: CGFloat = 59
    /// Нижний отступ под кнопками сессии.
    static let safeBottom: CGFloat = 40
}

// MARK: - Радиусы

enum AppRadius {
    /// Чипы части речи, сегменты, подложки иконок.
    static let chip: CGFloat = 9
    /// Поле поиска.
    static let field: CGFloat = 11
    /// Кнопки, варианты ответа, кнопки оценки.
    static let button: CGFloat = 15
    /// Плитки, группы списка, график.
    static let card: CGFloat = 16
    /// Карточка «Сегодня», детальная карточка слова.
    static let cardLarge: CGFloat = 18
    /// Карточка в сессии.
    static let hero: CGFloat = 22
}

// MARK: - Высоты

enum AppSize {
    /// Строка настроек и каталога.
    static let listRow: CGFloat = 46
    /// Главная кнопка на карточке «Сегодня».
    static let buttonPrimary: CGFloat = 50
    /// «Показать ответ», «Дальше», «Готово».
    static let buttonSession: CGFloat = 54
    /// Кнопка оценки: интервал сверху, подпись снизу.
    static let gradeButton: CGFloat = 62
    /// Вариант ответа в режиме выбора.
    static let optionRow: CGFloat = 62
    /// Плитка в режиме «Пары».
    static let matchTile: CGFloat = 68
    /// Таб-бар: 49 + зона домашнего индикатора.
    static let tabBar: CGFloat = 83

    /// Прогресс-бар сессии.
    static let progressBar: CGFloat = 6
    /// Иконка в строке списка.
    static let rowIcon: CGFloat = 30
    /// Круглая кнопка озвучки рядом со словом.
    static let speakButton: CGFloat = 40
    /// Крупная кнопка прослушивания в режиме аудирования.
    static let listenButton: CGFloat = 116
    /// Кнопка закрытия сессии.
    static let closeButton: CGFloat = 32

    /// Нижняя граница области касания для любого интерактивного элемента.
    static let minTouchTarget: CGFloat = 44
}

// MARK: - Размеры глифов

/// Размеры SF Symbols. Шкала `AppFont` задаёт текст, а глиф без подписи
/// ею не описывается — но и числовым литералом во вьюхе быть не должен.
enum AppSymbol {
    /// Иконка в callout примечания.
    static let note: CGFloat = 18
    /// Глиф пустого состояния в круге 64 pt.
    static let emptyState: CGFloat = 28
    /// Глиф плейсхолдера картинки.
    static let placeholder: CGFloat = 36
    /// Глиф в крупной кнопке прослушивания.
    static let listen: CGFloat = 44
    /// Крупный итоговый глиф: «Сессия завершена», «На сегодня всё».
    static let hero: CGFloat = 48
}

// MARK: - Хелперы

extension View {

    /// Размер SF Symbol без подписи. Масштабируется вместе с Dynamic Type.
    func appSymbol(_ size: CGFloat, relativeTo textStyle: Font.TextStyle = .body) -> some View {
        modifier(AppSymbolModifier(size: size, textStyle: textStyle))
    }
    /// Гарантирует минимальную область касания 44 × 44 pt,
    /// не меняя видимый размер элемента.
    func minimumTouchTarget() -> some View {
        frame(minWidth: AppSize.minTouchTarget, minHeight: AppSize.minTouchTarget)
            .contentShape(Rectangle())
    }

    /// Стандартная карточка: заливка `surface` и скруглённые углы.
    func cardSurface(radius: CGFloat = AppRadius.card) -> some View {
        background(AppColor.surface, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
    }
}

private struct AppSymbolModifier: ViewModifier {

    @ScaledMetric private var scaledSize: CGFloat

    init(size: CGFloat, textStyle: Font.TextStyle) {
        _scaledSize = ScaledMetric(wrappedValue: size, relativeTo: textStyle)
    }

    func body(content: Content) -> some View {
        content.font(.system(size: scaledSize))
    }
}
