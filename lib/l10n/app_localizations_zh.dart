// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class L10nZh extends L10n {
  L10nZh([String locale = 'zh']) : super(locale);

  @override
  String get accAddAccount => '添加账户';

  @override
  String get accAppPassword => '应用专用密码';

  @override
  String get accAppPasswordHelper => '不是邮箱主密码 — 请创建应用专用密码';

  @override
  String get accAutoRefresh => '自动刷新';

  @override
  String get accCaldavPasswordHelper => '对于 CalDAV — 使用应用专用密码，而非邮箱主密码';

  @override
  String get accCancel => '取消';

  @override
  String get accChangePassword => '更改密码';

  @override
  String accCompleteSignIn(String name) {
    return '$name：请在打开的浏览器中完成登录…';
  }

  @override
  String get accConnect => '连接';

  @override
  String get accConnectAccount => '连接账户';

  @override
  String accConnected(String email) {
    return '已连接：$email';
  }

  @override
  String get accConnecting => '正在连接…';

  @override
  String get accDelete => '删除';

  @override
  String get accEmail => '电子邮箱';

  @override
  String accError(String error) {
    return '错误：$error';
  }

  @override
  String get accEwsUrlLabel => 'EWS URL（可选）';

  @override
  String accFailed(String error) {
    return '失败：$error';
  }

  @override
  String get accFillEmailPassword => '请填写电子邮箱和密码';

  @override
  String get accHidden => '已隐藏';

  @override
  String get accHost => '主机';

  @override
  String get accHour1 => '1 小时';

  @override
  String get accLoginIfDifferent => '登录名（如果不同）';

  @override
  String get accLoginPassword => '登录名和密码';

  @override
  String get accManual => '手动';

  @override
  String accMinutes(int count) {
    return '$count 分钟';
  }

  @override
  String get accNewPassword => '新密码';

  @override
  String get accNoCalendars => '无日历';

  @override
  String accOAuthNotConfiguredTitle(String name) {
    return '尚未配置 $name 登录';
  }

  @override
  String accOAuthNotConfiguredBody(String name) {
    return '此 Calenfi 版本不含 $name 的 OAuth 客户端，因此无法在浏览器中开始登录。请输入你自己的 OAuth 应用客户端（重定向 URI 为 http://localhost），它将保存在本设备的安全存储中。';
  }

  @override
  String get accOAuthClientId => '客户端 ID';

  @override
  String get accOAuthClientSecret => '客户端密钥';

  @override
  String get accSaveAndSignIn => '保存并登录';

  @override
  String get accPassword => '密码';

  @override
  String get accPasswordSaved => '密码已保存，正在同步…';

  @override
  String get accReconnect => '重新连接';

  @override
  String get accPort => '端口';

  @override
  String get accSave => '保存';

  @override
  String get accSectionCalendars => '日历';

  @override
  String get accSectionVideoMeetings => '视频会议';

  @override
  String get accSignInBrowser => '通过浏览器登录';

  @override
  String get accStatusAuthError => '授权错误';

  @override
  String get accStatusNeedsReconnect => '需要重新连接';

  @override
  String get accStatusOffline => '无网络';

  @override
  String get accStatusOk => '已连接';

  @override
  String get accStatusSyncError => '同步失败';

  @override
  String get accTitle => '账户';

  @override
  String get accVisibilityHint => '日历可见性 — 在设置 → 日历中';

  @override
  String get appTitle => 'Calenfi';

  @override
  String get calCancel => '取消';

  @override
  String get calCombineOff => '合并相同事件（关 — 各自单独显示）';

  @override
  String get calCombineOn => '合并相同事件（开）';

  @override
  String get calDay => '日';

  @override
  String get calDayShort => '日';

  @override
  String get calMonth => '月';

  @override
  String get calMonthShort => '月';

  @override
  String get calMoveModeHint => '移动模式：拖动事件。点按查看详情。';

  @override
  String get calNoTitle => '无标题';

  @override
  String get calNothingFound => '未找到任何内容';

  @override
  String calPendingCount(int count) {
    return '未上传到云端：$count';
  }

  @override
  String get calPinEvents => '固定事件';

  @override
  String calSearchFound(int count) {
    return '找到：$count';
  }

  @override
  String get calSearchHint => '搜索：标题、参与者、ID';

  @override
  String get calSettings => '设置';

  @override
  String get calShowCancelled => '显示已删除/已取消';

  @override
  String get calSortDate => '日期';

  @override
  String get calSortRelevance => '相关性';

  @override
  String get calSynced => '已同步';

  @override
  String get calToCloud => '上传到云端';

  @override
  String get calToday => '今天';

  @override
  String get calUnpinEvents => '取消固定事件（拖动以移动）';

  @override
  String get calViewInDev => '视图开发中';

  @override
  String get calWeek => '周';

  @override
  String get calWeekShort => '周';

  @override
  String get detAccept => '接受';

  @override
  String get detAllDay => '全天';

  @override
  String get detAttendeeCopied => '参与者已复制';

  @override
  String detAttendeesCount(int total, int accepted) {
    return '参与者：$total  ·  $accepted 人已接受';
  }

  @override
  String get detCancel => '取消';

  @override
  String get detCancelledDeleted => '已取消 / 已删除';

  @override
  String get detConfVideoCall => '视频会议';

  @override
  String get detCopied => '已复制';

  @override
  String get detCopy => '复制';

  @override
  String get detDecline => '拒绝';

  @override
  String get detDelete => '删除';

  @override
  String get detDeleteEventQ => '删除此事件？';

  @override
  String get detEdit => '编辑';

  @override
  String get detEditTitle => '编辑标题';

  @override
  String detFieldCopied(String label) {
    return '$label 已复制';
  }

  @override
  String get detId => 'ID';

  @override
  String detInMultipleCalendars(int count) {
    return '在多个日历中（$count）：';
  }

  @override
  String detJoin(String label) {
    return '加入 · $label';
  }

  @override
  String get detMeetingLinkCopied => '会议链接已复制';

  @override
  String get detOpenInCloud => '在云端打开';

  @override
  String get detOptional => '可选';

  @override
  String get detOrganizer => '组织者';

  @override
  String get detRecurringWhatDelete => '重复事件 — 要删除什么？';

  @override
  String get detRecurringWhatEdit => '重复事件——要修改什么？';

  @override
  String get detEditWholeSeries => '整个系列（所有重复项）';

  @override
  String get detResponseAccepted => '已接受';

  @override
  String get detResponseDeclined => '已拒绝';

  @override
  String get detResponseNeedsAction => '等待回复';

  @override
  String get detResponseOrganizer => '您是组织者';

  @override
  String get detResponseTentative => '待定';

  @override
  String get detSave => '保存';

  @override
  String get detTentative => '待定';

  @override
  String get detThisAndFollowing => '此事件及后续';

  @override
  String get detThisEventOnly => '仅此事件';

  @override
  String get detTitleChanged => '标题已更改';

  @override
  String get detUnknownCalendar => '未知日历';

  @override
  String get detWholeSeries => '整个系列';

  @override
  String get edAllDay => '全天';

  @override
  String get edAttendees => '参与者';

  @override
  String get edBusy => '忙碌';

  @override
  String get edCalendar => '日历';

  @override
  String get edCancel => '取消';

  @override
  String get edChoose => '选择…';

  @override
  String get edConference => '视频会议';

  @override
  String get edConnectAccount => '连接账户';

  @override
  String get edDaily => '每天';

  @override
  String get edDoNotRepeat => '不重复';

  @override
  String get edDone => '完成';

  @override
  String get edEditEvent => '编辑事件';

  @override
  String get edEnd => '结束';

  @override
  String get edEndAfter => '结束于';

  @override
  String get edEvery => '每';

  @override
  String edEveryNDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '每 $count 天',
    );
    return '$_temp0';
  }

  @override
  String edEveryNMonths(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '每 $count 个月',
    );
    return '$_temp0';
  }

  @override
  String edEveryNWeeks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '每 $count 周',
    );
    return '$_temp0';
  }

  @override
  String edEveryNYears(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '每 $count 年',
    );
    return '$_temp0';
  }

  @override
  String get edFree => '空闲';

  @override
  String get edFreqDay => '天';

  @override
  String get edFreqMonth => '月';

  @override
  String get edFreqWeek => '周';

  @override
  String get edFreqYear => '年';

  @override
  String get edFri => '周五';

  @override
  String get edFridayAcc => '星期五';

  @override
  String get edInviteeHint => '联系人姓名或电子邮件';

  @override
  String get edLocationHint => '地点';

  @override
  String get edMon => '周一';

  @override
  String get edMondayAcc => '星期一';

  @override
  String get edMonthly => '每月';

  @override
  String get edNewEvent => '新建事件';

  @override
  String get edNoEndDate => '无结束日期';

  @override
  String get edNone => '无';

  @override
  String get edNotesHint => '备注';

  @override
  String edOccurrences(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 次重复',
    );
    return '$_temp0';
  }

  @override
  String get edOccurrencesLabel => '次重复';

  @override
  String edOnDayOfMonth(int day) {
    return '$day日';
  }

  @override
  String get edOrdinal1 => '第1个';

  @override
  String get edOrdinal2 => '第2个';

  @override
  String get edOrdinal3 => '第3个';

  @override
  String get edOrdinal4 => '第4个';

  @override
  String get edOrdinalLast => '最后一个';

  @override
  String edOrdinalN(int number) {
    return '第$number个';
  }

  @override
  String get edRecurrenceTitle => '重复';

  @override
  String get edRepeat => '重复';

  @override
  String get edSat => '周六';

  @override
  String get edSaturdayAcc => '星期六';

  @override
  String get edSeriesInstance => '系列中的单个事件 — 规则适用于整个系列';

  @override
  String get edShowAs => '显示为';

  @override
  String get edStart => '开始';

  @override
  String get edSun => '周日';

  @override
  String get edSundayAcc => '星期日';

  @override
  String get edThu => '周四';

  @override
  String get edThursdayAcc => '星期四';

  @override
  String get edTitleHint => '标题';

  @override
  String get edTue => '周二';

  @override
  String get edTuesdayAcc => '星期二';

  @override
  String get edUnitDay => '天';

  @override
  String get edUnitMonth => '个月';

  @override
  String get edUnitWeek => '周';

  @override
  String get edUnitYear => '年';

  @override
  String get edUntil => '截止日期';

  @override
  String edUntilDate(String date) {
    return '至 $date';
  }

  @override
  String get edUntitled => '无标题';

  @override
  String get edVisDefault => '默认';

  @override
  String get edVisPrivate => '私密';

  @override
  String get edVisPublic => '公开';

  @override
  String get edVisibility => '可见性';

  @override
  String get edWed => '周三';

  @override
  String get edWednesdayAcc => '星期三';

  @override
  String get edWeekly => '每周';

  @override
  String get edYearly => '每年';

  @override
  String get setAbout => '关于';

  @override
  String get setAboutSubtitle => '本地优先的日历聚合器 · MVP';

  @override
  String get setAccounts => '账户';

  @override
  String get setAccountsAndConnections => '账户与连接';

  @override
  String setAccountsConnected(int count) {
    return '已连接 $count 个';
  }

  @override
  String get setCalendarNameHint => '日历名称';

  @override
  String get setCalendars => '日历';

  @override
  String get setCalendarsSubtitle => '在网格中显示哪些日历';

  @override
  String get setCancel => '取消';

  @override
  String setColorTitle(String name) {
    return '颜色：$name';
  }

  @override
  String get setCombine => '合并会议';

  @override
  String get setCombineSubtitle => '合并来自不同日历的相同事件。关闭后每个会议单独保留，可分别处理每个副本';

  @override
  String get setCommitDelay => '发送更改前的延迟';

  @override
  String get setCommitDelaySubtitle =>
      '移动/调整大小在同步到云端前会等待：虚线框 + 倒计时 + “立即应用”。0 表示立即。';

  @override
  String get setDelayImmediate => '立即';

  @override
  String setDelayMinutes(int count) {
    return '$count 分钟';
  }

  @override
  String get setEvents => '事件';

  @override
  String setFromSource(String name) {
    return '来自源：$name';
  }

  @override
  String get setLanguage => '语言';

  @override
  String get setLanguageSystem => '跟随系统';

  @override
  String get setMaps => '地图';

  @override
  String get setMapsSubtitle => '默认使用 Yandex 地图';

  @override
  String get setNoAccounts => '无账户';

  @override
  String get setNoCalendars => '无日历';

  @override
  String get setOpenPlacesIn => '在以下应用中打开地点';

  @override
  String get setReminderAtStart => '开始时';

  @override
  String get setReminderAtStartFull => '开始时刻';

  @override
  String setReminderHours(int count) {
    return '提前 $count 小时';
  }

  @override
  String setReminderMinutes(int count) {
    return '提前 $count 分钟';
  }

  @override
  String get setReminderNone => '无';

  @override
  String get setReminderNoneFull => '无提醒';

  @override
  String get setReminderSubtitle => '此日历事件的默认设置';

  @override
  String setReminderTitle(String name) {
    return '提醒：$name';
  }

  @override
  String get setRenameCalendar => '重命名日历';

  @override
  String get setReset => '重置';

  @override
  String get setResetColor => '重置为源颜色';

  @override
  String get setSave => '保存';

  @override
  String get setShowCancelled => '显示已删除/已取消';

  @override
  String get setShowCancelledSubtitle => '以删除线样式显示';

  @override
  String get setShowMonth => '显示月视图';

  @override
  String get setShowMonthSubtitle => '手机上月视图较拥挤，可以隐藏';

  @override
  String get setTitle => '设置';

  @override
  String get setView => '视图';

  @override
  String get uiCancel => '取消';

  @override
  String uiError(String error) {
    return '错误：$error';
  }

  @override
  String get uiMove => '移动';

  @override
  String uiMoveEventBody(String title, String range) {
    return '«$title»\n\n$range';
  }

  @override
  String get uiMoveEventTitle => '移动事件？';

  @override
  String get uiNoTitle => '无标题';

  @override
  String uiNotUpdated(String accounts) {
    return '未更新：$accounts';
  }

  @override
  String get uiReasonAuthError => '认证错误';

  @override
  String get uiReasonFailure => '故障';

  @override
  String get uiReasonNeedsReconnect => '重新连接';

  @override
  String get uiReasonOffline => '无网络';

  @override
  String get uiRetry => '重试';
}
