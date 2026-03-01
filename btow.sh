#!/usr/bin/env bash

set -euo pipefail

BASE_DIR="$HOME/.btow-profiles"
PROFILES_DIR="$BASE_DIR/profiles"
CURRENT_FILE="$BASE_DIR/current"
TARGET="$HOME"
DRY_RUN=false
mkdir -p "$PROFILES_DIR"

function log() {
    echo "[btow] $1"
}

function ensure_dependencies() {
    for cmd in fzf rsync; do
        command -v "$cmd" >/dev/null 2>&1 || {
            echo "Missing dependency: $cmd"
            exit 1
        }
    done
}

function browse_dirs() {
    local CURRENT_DIR="$HOME"
    local SELECTED=()
    while true; do
        CHOICE=$( 
            (
                echo ".. (go up)"
                echo "[SELECT THIS]"
                find "$CURRENT_DIR" -mindepth 1 -maxdepth 1 -type d 2>/dev/null \
                    | sed "s|$CURRENT_DIR/||"
                echo "[DONE]"
            ) | fzf --prompt="$CURRENT_DIR > "
        )
        if [[ "$CHOICE" == "[DONE]" ]]; then break
        elif [[ "$CHOICE" == ".. (go up)" ]]; then
            CURRENT_DIR=$(dirname "$CURRENT_DIR")
        elif [[ "$CHOICE" == "[SELECT THIS]" ]]; then
            REL="${CURRENT_DIR#$HOME/}"
            SELECTED+=("$REL")
            echo "Added: $REL" >&2
        elif [[ -n "$CHOICE" ]]; then
            CURRENT_DIR="$CURRENT_DIR/$CHOICE"
        fi
    done
    printf "%s\0" "${SELECTED[@]}"
}

function create_profile() {
    NAME="$1"
    PROFILE_PATH="$PROFILES_DIR/$NAME"
    mkdir -p "$PROFILE_PATH"
    browse_dirs | while IFS= read -r -d '' dir; do
        rsync -av --delete "$HOME/$dir/" "$PROFILE_PATH/$dir/"
    done
    log "Profile '$NAME' created."
}

# ---------------- Load (symlink) ----------------
function load_profile() {
    NAME="$1"
    PROFILE_PATH="$PROFILES_DIR/$NAME"

    [ ! -d "$PROFILE_PATH" ] && { echo "Profile not found."; exit 1; }

    # Eğer önceki yüklü profil varsa kaldır
    if [ -f "$CURRENT_FILE" ]; then
        PREV=$(cat "$CURRENT_FILE")
        PREV_PATH="$PROFILES_DIR/$PREV"
        if [ -d "$PREV_PATH" ]; then
            for item in "$PREV_PATH"/*; do
                TARGET_ITEM="$TARGET/$(basename "$item")"
                [ -L "$TARGET_ITEM" ] && rm -f "$TARGET_ITEM"
            done
        fi
    fi

    # Hedefte çakışma varsa sor
    for item in "$PROFILE_PATH"/*; do
        TARGET_ITEM="$TARGET/$(basename "$item")"
        if [ -e "$TARGET_ITEM" ] && [ ! -L "$TARGET_ITEM" ]; then
            read -rp "'$TARGET_ITEM' exists. Remove? (y/n) " RESP
            [[ "$RESP" =~ ^[Yy]$ ]] && rm -rf "$TARGET_ITEM" || continue
        fi
        ln -s "$item" "$TARGET_ITEM"
        echo "Linked $item -> $TARGET_ITEM"
    done

    echo "$NAME" > "$CURRENT_FILE"
    log "Profile '$NAME' loaded (symlinks)."
}

# ---------------- Install (cp -r) ----------------
function install_profile() {
    NAME="$1"
    PROFILE_PATH="$PROFILES_DIR/$NAME"

    [ ! -d "$PROFILE_PATH" ] && { echo "Profile not found."; exit 1; }

    log "Installing profile '$NAME' to $TARGET ..."
    for item in "$PROFILE_PATH"/*; do
        TARGET_ITEM="$TARGET/$(basename "$item")"

        # Eğer symlink ise sorma, direkt sil
        if [ -L "$TARGET_ITEM" ]; then
            echo "Target is symlink, removing $TARGET_ITEM"
            rm -rf "$TARGET_ITEM"
        elif [ -e "$TARGET_ITEM" ]; then
            # Normal dosya veya klasör ise kullanıcıya sor
            read -rp "'$TARGET_ITEM' exists. Remove? (y/n) " RESP
            if [[ "$RESP" =~ ^[Yy]$ ]]; then
                rm -rf "$TARGET_ITEM"
                echo "Removed $TARGET_ITEM"
            else
                echo "Skipping $TARGET_ITEM"
                continue
            fi
        fi

        # Kopyala
        cp -r "$item" "$TARGET_ITEM"
        echo "Copied $item -> $TARGET_ITEM"
    done
    log "Profile '$NAME' installed (cp -r)."
}

# ---------------- Remove ----------------
function remove_profile() {
    NAME="$1"
    PROFILE_PATH="$PROFILES_DIR/$NAME"

    [ ! -d "$PROFILE_PATH" ] && { echo "Profile '$NAME' not found."; return 1; }

    # Yüklü profilse önce install et
    if [ -f "$CURRENT_FILE" ] && [ "$(cat "$CURRENT_FILE")" = "$NAME" ]; then
        echo "Profile '$NAME' currently loaded. Installing before removal..."
        install_profile "$NAME"
        rm -f "$CURRENT_FILE"
    fi

    rm -rf "$PROFILE_PATH"
    echo "Profile '$NAME' removed."
}

# ---------------- List ----------------
function list_profiles() {
    ls "$PROFILES_DIR"
}

# ---------------- Bundling ----------------

function export_profile() {
    NAME="$1"
    PROFILE_PATH="$PROFILES_DIR/$NAME"
    
    TMP=$(mktemp -d)
    trap 'rm -rf "$TMP"' EXIT

    # Dotfile’ları tar + zstd ile sıkıştır
    tar -C "$PROFILE_PATH" -cf - . | zstd -19 -o "$TMP/files.tar.zst"

    # Hash oluştur
    sha256sum "$TMP/files.tar.zst" > "$TMP/files.sha256"

    # Hepsini kapsül
    tar -C "$TMP" -cf "$NAME.btow" files.tar.zst files.sha256

    echo "Profile '$NAME' exported as $NAME.btow"
}

function import_profile() {
    BUNDLE="$1"

    [ ! -f "$BUNDLE" ] && { echo "Bundle not found."; exit 1; }

    TMP=$(mktemp -d)
    trap 'rm -rf "$TMP"' EXIT

    # Bundle aç
    tar -xf "$BUNDLE" -C "$TMP" || { echo "Invalid bundle."; exit 1; }

    # Hash doğrula
    (cd "$TMP" && sha256sum -c files.sha256) || {
        echo "Hash verification failed!"
        exit 1
    }

    # Profile adı oluştur (dosya adı kullan)
    NAME=$(basename "$BUNDLE" .btow)
    PROFILE_PATH="$PROFILES_DIR/$NAME"
    mkdir -p "$PROFILE_PATH"

    # Zstd aç
    zstd -d "$TMP/files.tar.zst" -o "$TMP/files.tar"

    # Extract
    tar -xf "$TMP/files.tar" -C "$PROFILE_PATH"

    echo "Profile '$NAME' imported successfully."
}

# ---------------- CLI ----------------
function usage() {
    echo "Usage: btow [--dry-run] {create|load|update|install|remove|list} profile"
    exit 1
}

ensure_dependencies

OPTIONS=
LONGOPTIONS=dry-run,help

PARSED=$(getopt --options=$OPTIONS --longoptions=$LONGOPTIONS --name "$0" -- "$@") || usage
eval set -- "$PARSED"

while true; do
    case "$1" in
        --dry-run) DRY_RUN=true; shift ;;
        --help) usage ;;
        --) shift; break ;;
        *) usage ;;
    esac
done

CMD="${1:-}"
PROFILE="${2:-}"

[ -z "$CMD" ] && usage

case "$CMD" in
    create) create_profile "$PROFILE" ;;
    load) load_profile "$PROFILE" ;;
    update) update_profile "$PROFILE" ;;
    install) install_profile "$PROFILE" ;;
    remove) remove_profile "$PROFILE" ;;
    export) export_profile "$PROFILE" ;;
    import) import_profile "$PROFILE" ;;
    list) list_profiles ;;
    *) usage ;;
esac