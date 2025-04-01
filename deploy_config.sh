#!/bin/bash

set -eu

DOTFILES="$HOME/dotfiles"
BACKUP="$DOTFILES/backup"
FILES=(.vimrc .tmux.conf)

mkdir -p "$BACKUP"

for file in "${FILES[@]}"; do
  src="$DOTFILES/${file#.}"       # .vimrc → vimrc
  dest="$HOME/$file"

  if [ ! -e "$src" ]; then
    echo "⚠️  $src が見つかりません。スキップします。"
    continue
  fi

  if [ -e "$dest" ] && [ ! -L "$dest" ]; then
    ts=$(date +%Y%m%d_%H%M%S)
    mv "$dest" "$BACKUP/${file}.backup.$ts"
    echo "📦 $file をバックアップしました。"
  fi

  ln -svf "$src" "$dest"
done

echo "✅ リンクとバックアップが完了しました。"


# === zshrc にカスタム設定の読み込みを追加 ===
ZSHRC="$HOME/.zshrc"
CUSTOM_LINE='[ -f "$HOME/dotfiles/zsh/zshrc.custom" ] && source "$HOME/dotfiles/zsh/zshrc.custom"'

if grep -Fxq "$CUSTOM_LINE" "$ZSHRC"; then
  echo "✅ .zshrc には既にカスタム設定の読み込み行が存在します。"
else
  echo -e "\n# Load custom zsh config\n$CUSTOM_LINE" >> "$ZSHRC"
  echo "➕ .zshrc にカスタム設定の読み込み行を追加しました。"
fi

echo "✅ すべての処理が完了しました。"
