#!/usr/bin/env ruby
# frozen_string_literal: true

# macos_add_widget_target.rb — добавляет в сгенерированный macos/Runner.xcodeproj
# таргет WidgetKit-расширения «CalenfiWidgets» (виджеты «сегодня» и мини-календарь).
#
# Папка macos/ в репозиторий не входит (её создаёт tools/setup_macos.sh через
# `flutter create`), поэтому таргет нельзя закоммитить — он собирается скриптом
# на каждой сборке. Исходники расширения лежат в macos_widget/CalenfiWidgets.
#
# Запускать из корня проекта, после setup_macos.sh: ruby tools/macos_add_widget_target.rb

require 'xcodeproj'
require 'fileutils'

PROJECT_PATH = 'macos/Runner.xcodeproj'
TARGET_NAME = 'CalenfiWidgets'
APP_BUNDLE_ID = 'ru.apsolutions.calenfi'
WIDGET_BUNDLE_ID = "#{APP_BUNDLE_ID}.widgets"
SOURCE_DIR = 'macos_widget/CalenfiWidgets'
DEST_DIR = File.join('macos', TARGET_NAME)
DEPLOYMENT_TARGET = '14.0' # интерактивные виджеты (Button + AppIntent)

abort "ОШИБКА: не найден #{PROJECT_PATH} — сначала tools/setup_macos.sh" unless Dir.exist?(PROJECT_PATH)
abort "ОШИБКА: не найден #{SOURCE_DIR}" unless Dir.exist?(SOURCE_DIR)

# Версия берётся из pubspec, чтобы .appex и .app не разъезжались по версиям —
# macOS отказывается регистрировать расширение с чужой версией бандла.
# Явная кодировка: под ssh локаль может быть POSIX, и Ruby иначе читает
# файл с русскими комментариями как US-ASCII и падает на регулярке.
pubspec = File.read('pubspec.yaml', encoding: 'UTF-8')
version_line = pubspec[/^version:\s*(\S+)/, 1] || '0.0.1+1'
marketing_version, build_number = version_line.split('+')
build_number ||= '1'

project = Xcodeproj::Project.open(PROJECT_PATH)
runner = project.targets.find { |t| t.name == 'Runner' }
abort 'ОШИБКА: в проекте нет таргета Runner' if runner.nil?

# 1. Исходники расширения кладём внутрь macos/, чтобы пути в проекте были
#    относительными и сборка не зависела от расположения репозитория. Копируем
#    всегда: при повторном запуске это обновляет код виджетов в проекте.
FileUtils.rm_rf(DEST_DIR)
FileUtils.mkdir_p(DEST_DIR)
FileUtils.cp(Dir[File.join(SOURCE_DIR, '*.swift')], DEST_DIR)
FileUtils.cp(File.join(SOURCE_DIR, 'Info.plist'), DEST_DIR)
FileUtils.cp(File.join(SOURCE_DIR, 'CalenfiWidgets.entitlements'), DEST_DIR)

# Настройки применяем и к уже существующему таргету: скрипт запускается на
# каждой сборке, и правки (например, entitlements) должны доезжать без ручной
# пересборки проекта.
apply_settings = lambda do |target|
  target.build_configurations.each do |config|
    s = config.build_settings
    s['PRODUCT_BUNDLE_IDENTIFIER'] = WIDGET_BUNDLE_ID
    s['PRODUCT_NAME'] = '$(TARGET_NAME)'
    s['INFOPLIST_FILE'] = "#{TARGET_NAME}/Info.plist"
    s['GENERATE_INFOPLIST_FILE'] = 'NO'
    s['MACOSX_DEPLOYMENT_TARGET'] = DEPLOYMENT_TARGET
    s['SWIFT_VERSION'] = '5.0'
    s['MARKETING_VERSION'] = marketing_version
    s['CURRENT_PROJECT_VERSION'] = build_number
    s['CODE_SIGN_ENTITLEMENTS'] = "#{TARGET_NAME}/CalenfiWidgets.entitlements"
    s['CODE_SIGN_STYLE'] = 'Manual'
    s['CODE_SIGN_IDENTITY'] = '-'
    s['CODE_SIGNING_REQUIRED'] = 'YES'
    s['CODE_SIGNING_ALLOWED'] = 'YES'
    s['DEVELOPMENT_TEAM'] = ''
    s['PROVISIONING_PROFILE_SPECIFIER'] = ''
    s['ENABLE_HARDENED_RUNTIME'] = 'NO'
    s['SKIP_INSTALL'] = 'YES'
    s['COMBINE_HIDPI_IMAGES'] = 'YES'
    s['ALWAYS_SEARCH_USER_PATHS'] = 'NO'
    s['SWIFT_EMIT_LOC_STRINGS'] = 'YES'
    s['LD_RUNPATH_SEARCH_PATHS'] = [
      '$(inherited)', '@executable_path/../Frameworks',
      '@executable_path/../../../../Frameworks'
    ]
  end
end

existing = project.targets.find { |t| t.name == TARGET_NAME }
if existing
  apply_settings.call(existing)
  project.save
  puts "==> Таргет #{TARGET_NAME} уже есть — обновил исходники и настройки."
  exit 0
end

# 2. Сам таргет расширения.
target = project.new_target(
  :app_extension, TARGET_NAME, :osx, DEPLOYMENT_TARGET, nil, :swift
)

group = project.main_group.new_group(TARGET_NAME, TARGET_NAME)
swift_refs = Dir[File.join(DEST_DIR, '*.swift')].sort.map do |path|
  group.new_reference(File.basename(path))
end
target.add_file_references(swift_refs)
group.new_reference('Info.plist')
group.new_reference('CalenfiWidgets.entitlements')

# 3. Настройки сборки. Ad-hoc подпись («-») — как у самого приложения: Apple
# Developer аккаунта нет, поэтому ни App Groups, ни provisioning profile.
apply_settings.call(target)

# 4. Встраивание в приложение: PlugIns + зависимость сборки.
runner.add_dependency(target)
embed_phase = runner.build_phases.find do |phase|
  phase.is_a?(Xcodeproj::Project::Object::PBXCopyFilesBuildPhase) &&
    phase.name == 'Embed Foundation Extensions'
end
embed_phase ||= runner.new_copy_files_build_phase('Embed Foundation Extensions')
embed_phase.symbol_dst_subfolder_spec = :plug_ins
embed_phase.dst_path = ''
build_file = embed_phase.add_file_reference(target.product_reference)
build_file.settings = { 'ATTRIBUTES' => ['RemoveHeadersOnCopy'] }

project.save
puts "==> Таргет #{TARGET_NAME} (#{WIDGET_BUNDLE_ID}, v#{marketing_version}+#{build_number}) добавлен."
