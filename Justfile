xkb_root := env_var_or_default("XKB_CONFIG_ROOT", "/usr/share/X11/xkb")
source := "layout/alczerty.toml"
layout := "alczerty"
# Allow an explicit interpreter; otherwise discover Python on PATH.
python := `if [ -n "${PYTHON:-}" ]; then printf '%s' "$PYTHON"; else command -v python3 || command -v python; fi`

# List available recipes.
default:
    just --list

# Preview the layout in the browser with live reload.
preview:
    @echo "Starting the browser preview for {{source}} with live reload."
    @echo "Press Ctrl+C to stop the preview."
    @kalamine watch {{source}}

# Build distributable layout files in dist/.
build:
    @echo "Building {{source}} into dist/..."
    @kalamine build {{source}}
    @echo "Build complete. Generated files are in dist/."

# Build and validate the generated layout files (requires xkbcomp).
check: build
    #!/usr/bin/env bash
    set -euo pipefail
    echo "Checking that all seven generated files exist and are nonempty..."
    for extension in xkb_keymap xkb_symbols keylayout ahk klc svg json; do
        if ! test -s "dist/{{layout}}.$extension"; then
            echo "Missing or empty file: dist/{{layout}}.$extension" >&2
            exit 1
        fi
    done
    echo "Checking JSON syntax..."
    "{{python}}" -m json.tool dist/{{layout}}.json > /dev/null
    echo "Checking SVG syntax..."
    "{{python}}" -c 'import xml.etree.ElementTree as ET; ET.parse("dist/{{layout}}.svg")'
    echo "Compiling the standalone XKB keymap to check its validity..."
    compiled_keymap=$(mktemp --suffix=.xkm)
    trap 'rm -f "$compiled_keymap"' EXIT
    xkbcomp -w 0 -xkm dist/{{layout}}.xkb_keymap "$compiled_keymap"
    echo "All layout checks passed."

# Validate and package all seven files in dist/alczerty.zip.
package: check
    #!/usr/bin/env bash
    set -euo pipefail
    echo "Packaging all seven generated files into dist/{{layout}}.zip..."
    cd dist
    "{{python}}" -m zipfile -c {{layout}}.zip {{layout}}.{xkb_keymap,xkb_symbols,keylayout,ahk,klc,svg,json}
    echo "Package ready: dist/{{layout}}.zip"

# Remove generated files from dist/.
clean:
    @echo "Removing dist/, including generated layout files and ZIP archives..."
    @rm -rf dist
    @echo "Generated files removed."

# Build and install Linux XKB symbols (requires sudo).
install:
    @just build
    @echo "Installing the symbols file to {{xkb_root}}/symbols/{{layout}} (requires sudo)..."
    @sudo install -m 0644 dist/{{layout}}.xkb_symbols "{{xkb_root}}/symbols/{{layout}}"
    @echo "Symbols installed. Activate the layout on X.Org with: setxkbmap {{layout}}"

# Build and apply the layout in the current X.Org session.
use: build
    @echo "Activating the standalone keymap in the current X.Org session..."
    @xkbcomp "dist/{{layout}}.xkb_keymap" "$DISPLAY"
    @echo "Layout activated with xkbcomp. Return to standard French AZERTY with: setxkbmap fr"

# Remove installed Linux XKB symbols (requires sudo).
remove:
    #!/usr/bin/env bash
    set -euo pipefail
    if test -e "{{xkb_root}}/symbols/{{layout}}"; then
        echo "Removing {{xkb_root}}/symbols/{{layout}} (requires sudo)..."
        sudo rm -f "{{xkb_root}}/symbols/{{layout}}"
        echo "Symbols file removed. The active layout has not changed."
    else
        echo "No symbols file to remove at {{xkb_root}}/symbols/{{layout}}."
    fi
