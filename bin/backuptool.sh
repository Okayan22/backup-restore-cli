#!/bin/bash

set -euo pipefail

# SSDの名前(SSDの名前が違う場合は""の中の名前を変更してください)
SSD_NAME="PortableSSD"

#バックアップしたいフォルダー名を/と"の間に記述してください
SOURCES=(
    "$HOME/"
    "$HOME/"
)

MOUNT_POINT="/Volumes/$SSD_NAME"
TIMESTAMP="$(date +"%Y_%m_%d")"
TARGET_BASE="$MOUNT_POINT/Backup/$TIMESTAMP"

fail() {
    printf 'エラー: %s\n' "$*" >&2
    exit 1
}

# /Volumes に同名フォルダがあるだけの状態を誤認しないよう、diskutil で実際のマウントポイントを確認する。
[[ -d "$MOUNT_POINT" ]] || fail "外付けSSD '$SSD_NAME' が見つかりません。接続とマウントを確認してください。"
command -v diskutil >/dev/null 2>&1 || fail "diskutil が見つかりません。macOS 上で実行してください。"
command -v rsync >/dev/null 2>&1 || fail "rsync が見つかりません。"

VOLUME_INFO="$(diskutil info "$MOUNT_POINT" 2>/dev/null)" || fail "'$MOUNT_POINT' のボリューム情報を取得できません。"
printf '%s\n' "$VOLUME_INFO" | grep -Eq "^[[:space:]]*Mount Point:[[:space:]]*$MOUNT_POINT$" || \
    fail "'$MOUNT_POINT' はマウントされたボリュームではありません。"

mkdir -p "$TARGET_BASE"

printf '=== バックアップを開始します: %s ===\n' "$(date)"
printf '保存先: %s\n' "$TARGET_BASE"

for src in "${SOURCES[@]}"; do
    if [[ -e "$src" ]]; then
        printf '\nコピー中: %s ...\n' "$src"
        # 日付ごとのバックアップなので、既存データを削除する --delete は使わない。
        # 各バックアップ元の項目数に応じて、その項目専用の進捗バーを更新する。
        total_items="$(find "$src" -print | wc -l | tr -d ' ')"
        label="$(basename "$src")"
        rsync -a --progress --out-format='__BACKUP_DONE__%n' "$src" "$TARGET_BASE/" | /usr/bin/perl -e '
            $| = 1;
            ($total, $label) = splice(@ARGV, 0, 2);
            while (<STDIN>) {
                next unless /^__BACKUP_DONE__/;
                ++$done;
                $pct = int($done * 100 / $total);
                $pct = 100 if $pct > 100;
                $filled = int($pct * 24 / 100);
                $bar = "#" x $filled . " " x (24 - $filled);
                printf "\r%-14s : [%s] %3d%%", $label, $bar, $pct;
            }
        ' "$total_items" "$label"
        printf '\r%-14s : [########################] 100%%\n' "$label"
    else
        printf '警告: %s が存在しません。スキップします。\n' "$src" >&2
    fi
done

printf '\n=== バックアップが完了しました: %s ===\n' "$(date)"
diskutil eject "$MOUNT_POINT"
printf 'SSDを取り出しました。\n'
