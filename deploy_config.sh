#!/bin/bash

# dotfiles シンプルデプロイスクリプト
# 使用法: ./deploy_config.sh [install|update|uninstall|list] [--force]

set -e

# 基本設定
DOTFILES_DIR="$HOME/dotfiles"
BACKUP_DIR="$DOTFILES_DIR/backup"
LOG_DIR="$DOTFILES_DIR/logs"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_FILE="$LOG_DIR/deploy_$TIMESTAMP.log"

# 必要なディレクトリの作成
mkdir -p "$BACKUP_DIR"
mkdir -p "$LOG_DIR"

# カラー設定
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# デフォルト設定
MODE="help"
FORCE=false

# dotfiles設定（ここを必要に応じて編集）
FILES=(
  "vimrc:.vimrc"
  "tmux.conf:.tmux.conf"
)

DEPENDENCIES=(
  "git"
  "zsh"
  "vim"
  "tmux"
  "neovim"
)


# ヘルプ表示
show_help() {
  echo -e "${BLUE}dotfiles シンプルデプロイツール${NC}"
  echo
  echo "使用法: $0 [コマンド] [オプション]"
  echo
  echo -e "${GREEN}コマンド:${NC}"
  echo "  install    設定ファイルをシンボリックリンクでデプロイ (デフォルト)"
  echo "  update     既存の設定を更新"
  echo "  uninstall  デプロイした設定を削除"
  echo "  list       デプロイ可能な設定ファイル一覧"
  echo
  echo -e "${GREEN}オプション:${NC}"
  echo "  --force, -f    確認なしで実行"
  echo "  --help, -h     このヘルプを表示"
  echo
  echo -e "${GREEN}例:${NC}"
  echo "  $0 install"
  echo "  $0 update --force"
}

# ログ関数
log() {
  local level="$1"
  local message="$2"
  local color=""
  
  case "$level" in
    "INFO") color="$BLUE" ;;
    "SUCCESS") color="$GREEN" ;;
    "WARNING") color="$YELLOW" ;;
    "ERROR") color="$RED" ;;
  esac
  
  # ログファイルに記録
  echo "[$level] $(date '+%Y-%m-%d %H:%M:%S') - $message" >> "$LOG_FILE"
  
  # 標準出力にも表示
  echo -e "${color}[$level]${NC} $message"
}

# バックアップ関数
backup_file() {
  local file="$1"
  
  if [ -e "$file" ] && [ ! -L "$file" ]; then
    local backup_file="$BACKUP_DIR/$(basename "$file").backup.$TIMESTAMP"
    log "INFO" "$file をバックアップ: $backup_file"
    mv "$file" "$backup_file"
    return 0
  fi
  
  return 1
}

# シンボリックリンク作成
create_symlink() {
  local src="$1"
  local dest="$2"
  
  if [ ! -e "$src" ]; then
    log "ERROR" "ソースファイルが存在しません: $src"
    return 1
  fi
  
  # リンク先ディレクトリがなければ作成
  local dest_dir=$(dirname "$dest")
  if [ ! -d "$dest_dir" ]; then
    log "INFO" "ディレクトリを作成: $dest_dir"
    mkdir -p "$dest_dir"
  fi
  
  # 既存ファイルのバックアップ
  if backup_file "$dest"; then
    log "SUCCESS" "既存ファイルをバックアップしました: $dest"
  fi
  
  # 既存のシンボリックリンクがあれば削除
  if [ -L "$dest" ]; then
    log "INFO" "既存のシンボリックリンクを削除: $dest"
    rm "$dest"
  fi
  
  log "INFO" "シンボリックリンク作成: $src → $dest"
  ln -sf "$src" "$dest"
  
  if [ $? -eq 0 ]; then
    log "SUCCESS" "リンク作成成功: $dest"
    return 0
  else
    log "ERROR" "リンク作成失敗: $dest"
    return 1
  fi
}

# zshrcにカスタム設定を追加
add_zsh_custom() {
  local ZSHRC="$HOME/.zshrc"
  local CUSTOM_FILE="$DOTFILES_DIR/zsh/zshrc.custom"
  local CUSTOM_LINE="[ -f \"$CUSTOM_FILE\" ] && source \"$CUSTOM_FILE\""
  
  if [ ! -f "$ZSHRC" ]; then
    log "INFO" ".zshrcが存在しないので作成します"
    touch "$ZSHRC"
  fi
  
  if grep -Fq "$CUSTOM_FILE" "$ZSHRC"; then
    log "INFO" ".zshrcには既にカスタム設定の読み込み行が存在します"
  else
    log "INFO" ".zshrcにカスタム設定の読み込み行を追加します"
    echo -e "\n# Load custom zsh config\n$CUSTOM_LINE" >> "$ZSHRC"
    log "SUCCESS" ".zshrcを更新しました"
  fi
}

# インストール
do_install() {
  log "INFO" "インストールを開始します..."
  
  # バックアップディレクトリ作成
  mkdir -p "$BACKUP_DIR"
  
  # 各設定ファイルをデプロイ
  for entry in "${FILES[@]}"; do
    IFS=':' read -r src dest <<< "$entry"
    src="$DOTFILES_DIR/${src#.}"  # .vimrc → vimrc に変換
    
    if [[ "$dest" != /* ]]; then
      dest="$HOME/$dest"  # 相対パスを絶対パスに
    fi
    
    create_symlink "$src" "$dest"
  done
  
  # zshrc設定
  add_zsh_custom
  
  log "SUCCESS" "インストール完了！"
}

# アンインストール
do_uninstall() {
  log "INFO" "アンインストールを開始します..."
  
  # 確認
  if [ "$FORCE" = false ]; then
    read -p "本当にdotfilesをアンインストールしますか？ [y/N] " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
      log "INFO" "アンインストールを中止しました"
      exit 0
    fi
  fi
  
  # 各シンボリックリンクを削除
  for entry in "${FILES[@]}"; do
    IFS=':' read -r src dest <<< "$entry"
    
    if [[ "$dest" != /* ]]; then
      dest="$HOME/$dest"
    fi
    
    if [ -L "$dest" ]; then
      log "INFO" "シンボリックリンクを削除: $dest"
      rm "$dest"
      
      # 最新のバックアップを探す
      local latest_backup=$(find "$BACKUP_DIR" -name "$(basename "$dest").backup.*" | sort -r | head -n1)
      
      if [ -n "$latest_backup" ]; then
        log "INFO" "バックアップから復元: $latest_backup → $dest"
        mv "$latest_backup" "$dest"
        log "SUCCESS" "ファイルを復元しました: $dest"
      fi
    else
      log "INFO" "シンボリックリンクが見つかりません: $dest"
    fi
  done
  
  # zshrc設定を削除
  if [ -f "$HOME/.zshrc" ]; then
    log "INFO" ".zshrcからカスタム設定の読み込み行を削除します"
    sed -i '/Load custom zsh config/d' "$HOME/.zshrc"
    sed -i "\|$DOTFILES_DIR/zsh/zshrc.custom|d" "$HOME/.zshrc"
  fi
  
  log "SUCCESS" "アンインストール完了！"
}

# 更新
do_update() {
  log "INFO" "設定を更新します..."
  
  # Gitリポジトリの場合はpullする
  if [ -d "$DOTFILES_DIR/.git" ]; then
    log "INFO" "Gitリポジトリを更新します"
    (cd "$DOTFILES_DIR" && git pull)
    if [ $? -eq 0 ]; then
      log "SUCCESS" "Gitリポジトリを更新しました"
    else
      log "ERROR" "Gitリポジトリの更新に失敗しました"
    fi
  fi
  
  # 既存のシンボリックリンクを更新
  do_install
  
  log "SUCCESS" "更新完了！"
}

# 利用可能な設定ファイル一覧
do_list() {
  echo -e "利用可能な設定ファイル:"
  
  echo -e "${BLUE}ソースファイル${NC} -> ${GREEN}リンク先${NC} [${YELLOW}状態${NC}]"
  echo "-------------------------------------------------------"
  
  for entry in "${FILES[@]}"; do
    IFS=':' read -r src dest <<< "$entry"
    src="$DOTFILES_DIR/${src#.}"
    
    if [[ "$dest" != /* ]]; then
      dest="$HOME/$dest"
    fi
    
    status=""
    if [ -e "$src" ]; then
      if [ -L "$dest" ] && [ "$(readlink -f "$dest")" = "$src" ]; then
        status="${GREEN}リンク済${NC}"
      elif [ -e "$dest" ] && [ ! -L "$dest" ]; then
        status="${YELLOW}既存ファイルあり${NC}"
      elif [ ! -e "$dest" ]; then
        status="${BLUE}未設定${NC}"
      else
        status="${RED}不明${NC}"
      fi
    else
      status="${RED}ソースなし${NC}"
    fi
    
    printf "%-40s -> %-30s [%s]\n" "$src" "$dest" "$status"
  done
}

# 依存関係チェック
check_dependencies() {
  log "INFO" "依存関係をチェックします..."
  
  local missing_deps=()
  
  for cmd in "${DEPENDENCIES[@]}"; do
    if ! command -v $cmd >/dev/null 2>&1; then
      log "WARNING" "$cmd がインストールされていません"
      missing_deps+=("$cmd")
    else
      log "INFO" "$cmd: インストール済み ($(command -v $cmd))"
    fi
  done
  
  # 不足している依存関係がある場合
  if [ ${#missing_deps[@]} -gt 0 ]; then
    log "WARNING" "以下の依存関係が満たされていません: ${missing_deps[*]}"
    if [ "$FORCE" = false ]; then
      read -p "依存関係が不足していますが、続行しますか？ [y/N] " confirm
      if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        log "INFO" "インストールを中止しました"
        exit 1
      fi
    fi
    log "INFO" "依存関係の不足を無視して続行します"
  fi
}

# 引数解析
while [[ $# -gt 0 ]]; do
  case "$1" in
    install|update|uninstall|list)
      MODE="$1"
      shift
      ;;
    --force|-f)
      FORCE=true
      shift
      ;;
    --help|-h)
      show_help
      exit 0
      ;;
    *)
      echo "不明なオプション: $1"
      show_help
      exit 1
      ;;
  esac
done

# バックアップディレクトリ作成
mkdir -p "$BACKUP_DIR"

# メイン処理
case "$MODE" in
  install)
    check_dependencies
    do_install
    log "INFO" "ログは $LOG_FILE に保存されました"
    ;;
  update)
    do_update
    log "INFO" "ログは $LOG_FILE に保存されました"
    ;;
  uninstall)
    do_uninstall
    log "INFO" "ログは $LOG_FILE に保存されました"
    ;;
  list)
    do_list
    ;;
  help)
    show_help
    ;;
esac

exit 0
