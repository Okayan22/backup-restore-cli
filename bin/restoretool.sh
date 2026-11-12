#!/bin/bash

set -euo pipefail

# SSD名が異なる場合は、ここを新しいMacのボリューム名に変更してください。
SSD_NAME="${SSD_NAME:-PortableSSD}"
MOUNT_POINT="/Volumes/$SSD_NAME"
BACKUP_ROOT="$MOUNT_POINT/Backup"

fail() {
    printf 'エラー: %s\n' "$*" >&2
    exit 1
}

[[ -d "$MOUNT_POINT" ]] || fail "SSD '$SSD_NAME' が見つかりません。接続とマウントを確認してください。"
command -v diskutil >/dev/null 2>&1 || fail "macOS 上で実行してください。"
command -v rsync >/dev/null 2>&1 || fail "rsync が見つかりません。"
VOLUME_INFO="$(diskutil info "$MOUNT_POINT" 2>/dev/null)" || fail "SSDの情報を取得できません。"
printf '%s\n' "$VOLUME_INFO" | grep -Eq "^[[:space:]]*Mount Point:[[:space:]]*$MOUNT_POINT$" || \
    fail "'$MOUNT_POINT' はマウントされたボリュームではありません。"

latest=""
for path in "$BACKUP_ROOT"/20??_??_??; do
    [[ -d "$path" ]] || continue
    date_name="${path##*/}"
    [[ "$date_name" > "$latest" ]] && latest="$date_name"
done
[[ -n "$latest" ]] || fail "'$BACKUP_ROOT' に日付別バックアップがありません。"

printf '最新のバックアップ: %s\n' "$latest"
printf '別の日付を使う場合は日付を入力してください（例: 2026_10_26）。Enterで最新を選択: '
IFS= read -r selected
selected="${selected:-$latest}"
SNAPSHOT="$BACKUP_ROOT/$selected"
[[ -d "$SNAPSHOT" ]] || fail "バックアップ '$selected' が見つかりません。"

SOURCES=(Documents dotfiles my_dir .zshrc .zprofile mybin .ssh)
found=0
printf '\n復元対象:\n'
for name in "${SOURCES[@]}"; do
    if [[ -e "$SNAPSHOT/$name" ]]; then
        printf '  %s\n' "$name"
        found=1
    fi
done
[[ "$found" -eq 1 ]] || fail "選択したバックアップに復元できるデータがありません。"

printf '\n復元先: %s\n' "$HOME"
printf '同じ名前のファイルはバックアップの内容で上書きされます。復元を続けるには RESTORE と入力してください: '
IFS= read -r answer
[[ "$answer" == "RESTORE" ]] || { printf '復元を中止しました。\n'; exit 0; }

for name in "${SOURCES[@]}"; do
    source="$SNAPSHOT/$name"
    [[ -e "$source" ]] || continue
    printf '\n復元中: %s\n' "$name"
    rsync -av --progress "$source" "$HOME/"
done

printf '\n復元が完了しました。ターミナルを開き直すとシェル設定が反映されます。\n'
diskutil eject "$MOUNT_POINT"
printf 'SSDを取り出しました。\n'
