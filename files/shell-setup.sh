#!/usr/bin/env bash
# Public entry point. The private dotfiles repo remains the source of truth.
set -euo pipefail

repo="vb000/dotfiles"
destination="${DOTFILES_DIR:-$HOME/dotfiles}"
ssh_url="git@github.com:vb000/dotfiles.git"

if ! command -v git >/dev/null 2>&1; then
  echo "Git is required. On macOS, install Xcode Command Line Tools: xcode-select --install" >&2
  exit 1
fi

if [[ -e "$destination" && ! -d "$destination/.git" ]]; then
  echo "Destination already exists but is not a Git checkout: $destination" >&2
  exit 1
fi

if [[ -d "$destination/.git" ]]; then
  origin="$(git -C "$destination" remote get-url origin || true)"
  case "$origin" in
    "$ssh_url"|"https://github.com/vb000/dotfiles.git"|"https://github.com/vb000/dotfiles")
      echo "Reusing existing checkout: $destination (not automatically pulling changes)"
      ;;
    *)
      echo "Unexpected checkout origin: $origin" >&2
      exit 1
      ;;
  esac
else
  echo "Cloning private $repo into $destination"
  if command -v gh >/dev/null 2>&1 && gh auth status -h github.com >/dev/null 2>&1; then
    gh repo clone "$repo" "$destination"
  elif ! git clone "$ssh_url" "$destination"; then
    echo "Cannot clone private repo. Configure GitHub SSH authentication, or install gh and run 'gh auth login'." >&2
    exit 1
  fi
fi

echo "Running $destination/setup.sh"
bash "$destination/setup.sh"
echo "Done. Open a new terminal to load the configuration."
