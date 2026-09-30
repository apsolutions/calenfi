import 'package:flutter/widgets.dart';

/// Класс ширины окна — одна шкала на всё приложение вместо россыпи «< 600».
///
///   • [compact] — телефон и внешний экран складного телефона, а также половина
///     внутреннего экрана в режиме разделения;
///   • [medium] — внутренний экран складного телефона (Galaxy Z Fold 7 даёт
///     750 точек в книжной и 832 в альбомной ориентации) и небольшие планшеты.
///     Сетке недели здесь просторно, а десктопной верхней панели тесно;
///   • [expanded] — десктоп и большие планшеты.
enum WindowClass { compact, medium, expanded }

/// Нижняя граница [WindowClass.medium].
const double kMediumMinWidth = 600;

/// Нижняя граница [WindowClass.expanded]: десктопная верхняя панель с полем
/// поиска в строке занимает около 780 точек без самого поля.
const double kExpandedMinWidth = 900;

WindowClass windowClassForWidth(double width) {
  if (width < kMediumMinWidth) return WindowClass.compact;
  if (width < kExpandedMinWidth) return WindowClass.medium;
  return WindowClass.expanded;
}

WindowClass windowClassOf(BuildContext context) =>
    windowClassForWidth(MediaQuery.sizeOf(context).width);
