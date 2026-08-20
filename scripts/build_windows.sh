#!/usr/bin/env bash
set -euo pipefail

echo "==> Building Windows Wallps Package (.exe)..."
cd "$(dirname "$0")/../windows"

if [ ! -d "node_modules" ]; then
    echo "==> Installing Windows client dependencies..."
    npm install
fi

echo "==> Packaging Windows Installer & Portable Executable..."
npm run build:win

echo "==> Windows build artifacts available in build/windows/"
