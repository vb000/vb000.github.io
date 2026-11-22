#!/usr/bin/env bash
# Public Stage 0 bootstrap for private vb000/dotfiles.
set -euo pipefail
repo="vb000/dotfiles"
destination="${DOTFILES_DIR:-$HOME/dotfiles}"
ssh_url="git@github.com:vb000/dotfiles.git"
note() { printf '==> %s\n' "$*"; }
die() { printf 'Error: %s\n' "$*" >&2; exit 1; }
has() { command -v "$1" >/dev/null 2>&1; }

case "$(uname -s)" in
  Darwin)
    if ! xcode-select -p >/dev/null 2>&1; then
      note "Install Apple Command Line Tools first."
      xcode-select --install || true
      die "Complete the CLT installation and rerun this script."
    fi
    if ! has brew; then
      has curl || die "curl is required for Homebrew."
      note "Installing Homebrew using its official installer."
      /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    fi
    for p in /opt/homebrew/bin/brew /usr/local/bin/brew; do
      if [[ -x "$p" ]]; then eval "$("$p" shellenv)"; break; fi
    done
    has brew || die "Homebrew is not on PATH."
    has git || brew install git
    has gh || brew install gh
    ;;
  Linux)
    missing=()
    has git || missing+=(git)
    has curl || missing+=(curl)
    if (("${#missing[@]}")); then
      if [[ "$EUID" -eq 0 ]]; then privilege=()
      elif has sudo; then privilege=(sudo)
      else die "Install missing prerequisites manually (no sudo): ${missing[*]}"
      fi
      if has apt-get; then
        note "Installing ${missing[*]} using apt-get."
        "${privilege[@]}" apt-get update
        "${privilege[@]}" apt-get install -y "${missing[@]}"
      elif has dnf; then
        note "Installing ${missing[*]} using dnf."
        "${privilege[@]}" dnf install -y "${missing[@]}"
      elif has apk; then
        note "Installing ${missing[*]} using apk."
        "${privilege[@]}" apk add "${missing[@]}"
      else
        die "Unsupported package manager; install ${missing[*]} manually."
      fi
    fi
    # gh is optional on Linux; existing SSH authentication is sufficient.
    ;;
  *) die "Only macOS and Linux are supported." ;;
esac

has git || die "Git is required."
has curl || die "curl is required for the mise installer."
if [[ -e "$destination" && ! -d "$destination/.git" ]]; then
  die "Destination exists but is not a Git checkout: $destination"
fi
if [[ -d "$destination/.git" ]]; then
  origin="$(git -C "$destination" remote get-url origin || true)"
  case "$origin" in
    "$ssh_url"|"https://github.com/vb000/dotfiles.git"|"https://github.com/vb000/dotfiles")
      note "Reusing checkout: $destination (no automatic pull)."
      ;;
    *) die "Unexpected Git remote: $origin" ;;
  esac
else
  note "Cloning private $repo into $destination"
  if has gh && gh auth status -h github.com >/dev/null 2>&1; then
    gh repo clone "$repo" "$destination"
  elif GIT_SSH_COMMAND="ssh -o BatchMode=yes" git clone "$ssh_url" "$destination"; then
    :
  elif has gh; then
    note "GitHub authentication is needed for your private repository."
    gh auth login -h github.com -p https -w
    gh repo clone "$repo" "$destination"
  else
    die "SSH authentication failed. Configure an SSH key, or install gh and run 'gh auth login'."
  fi
fi

[[ -f "$destination/setup.sh" ]] || die "Missing $destination/setup.sh"
note "Running dotfiles setup from $destination"
bash "$destination/setup.sh"
note "Done. Open a new terminal to load configuration."
