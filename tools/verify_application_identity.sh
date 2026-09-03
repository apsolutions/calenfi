#!/usr/bin/env bash
set -Eeuo pipefail

readonly canonical_id='ru.apsolutions.calenfi'
readonly canonical_org='ru.apsolutions'
readonly canonical_repository='https://github.com/apsolutions/calenfi'

require_fixed_text() {
  local file="$1"
  local text="$2"
  grep -Fq -- "$text" "$file" || {
    printf 'Missing canonical application identity in %s: %s\n' "$file" "$text" >&2
    return 1
  }
}

require_fixed_text android/app/build.gradle.kts "namespace = \"$canonical_id\""
require_fixed_text android/app/build.gradle.kts "applicationId = \"$canonical_id\""
require_fixed_text lib/data/local/db/database_location.dart \
  "const String kApplicationId = '$canonical_id';"
require_fixed_text linux/CMakeLists.txt "set(APPLICATION_ID \"$canonical_id\")"
require_fixed_text windows/runner/main.cpp \
  "SetCurrentProcessExplicitAppUserModelID(L\"$canonical_id\")"
require_fixed_text windows/runner/Runner.rc 'VALUE "CompanyName", "apsolutions"'
require_fixed_text tools/setup_macos.sh "ORG=\"$canonical_org\""
require_fixed_text tools/setup_macos.sh "BUNDLE_ID=\"$canonical_id\""
require_fixed_text tools/install_desktop.sh "$canonical_id.desktop"
require_fixed_text README.md "$canonical_repository"

while IFS= read -r source; do
  require_fixed_text "$source" "package $canonical_id"
done < <(find android/app/src -type f -name '*.kt' -print | sort)

# Keep retired personal/vendor identities out of every tracked text file. The
# character-class notation intentionally prevents this guard from matching its
# own source while still matching a literal dot in repository content.
if git grep -n -I -E 'io[.]github[.]karpovilia|money[.]click[0-9]' -- .; then
  printf 'Retired application identity found in tracked files.\n' >&2
  exit 1
fi

printf 'Application identity verified: %s\n' "$canonical_id"
