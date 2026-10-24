xkb_root := env_var_or_default("XKB_CONFIG_ROOT", "/usr/share/X11/xkb")
source := "layout/alczerty.toml"
layout := "alczerty"

# List available recipes.
default:
    just --list

# Preview the layout in the browser with live reload.
preview:
    kalamine watch {{source}}

# Build distributable layout files in dist/.
build:
    kalamine build {{source}}

# Remove generated files from dist/.
clean:
    rm -rf dist

# Build and install Linux XKB symbols (requires sudo).
install:
    @just build
    sudo install -m 0644 dist/{{layout}}.xkb_symbols "{{xkb_root}}/symbols/{{layout}}"
    @echo "Installed XKB layout {{layout}}."
    @echo "On X.Org, select it with: just use"

# Build and apply the layout in the current X.Org session.
use: build
    xkbcomp "dist/{{layout}}.xkb_keymap" "$DISPLAY"

# Remove installed Linux XKB symbols (requires sudo).
remove:
    @if test -e "{{xkb_root}}/symbols/{{layout}}"; then \
        sudo rm -f "{{xkb_root}}/symbols/{{layout}}" && \
        echo "Removed XKB layout {{layout}}."; \
    else \
        echo "XKB layout {{layout}} is not installed."; \
    fi
