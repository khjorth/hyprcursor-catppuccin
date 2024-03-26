#!/usr/bin/env bash
set -euo pipefail
shopt -s extglob
current_dir=$(pwd)
# create a temporary directory to clone the repository
# this will be used to check out the repository and execute
# the build process
tmpdir=$(mktemp -d)
cursor_path="$tmpdir"/cursors
echo -en "Building in temporary directory: $tmpdir\n"

# Sparsely check out to the repository
# specifically to the src/ directory where
# vector (svg) versions of the Catppuccin cursors
# are located
git clone --depth=1 --filter=blob:none --sparse https://github.com/catppuccin/cursors "$cursor_path"
cd "$cursor_path" || exit
git sparse-checkout init --cone
git sparse-checkout set src/
echo -en "Cloned repository at $tmpdir/cursors\n"

CURSORDIR="${1-"$cursor_path"}" # should generally be cursors/src but user may choose to cd themselves
VARIANT="${2:-"Mocha-Dark"}"
NAMED="${2:-hyprcursor}"
ANIMONE="${3:-"wait"}"
ANIMTWO="${4:-"progress"}"

if [ ! -d "$CURSORDIR" ]; then
	echo "Error: Directory '$CURSORDIR' does not exist."
	exit 1
fi

if [ -f "$CURSORDIR/manifest.hl" ]; then
	echo "Error: $CURSORDIR already has a manifest.hl file."
	exit 1
fi

palette=("Frappe" "Latte" "Macchiato" "Mocha")
color=("Blue" "Dark" "Flamingo" "Green" "Lavender" "Light" "Maroon" "Mauve" "Peach" "Pink" "Red" "Rosewater" "Sapphire" "Sky" "Teal" "Yellow")

result_array=() # initialize results array

for item in "${palette[@]}"; do
	for col in "${color[@]}"; do
		result="${item}-${col}"
		result_array+=("$result")
	done
done

# Check if the string is an element of the result array
if [[ "${result_array[@]}" =~ "${VARIANT}" ]]; then
	true

else
	echo "Invalid variant provided: $VARIANT"
	exit 1
fi

# if variant is not in the list, exit

# prepare directory, remove any extraneous files

echo -en "Step 1: Preparing directory\n"
cd "$CURSORDIR"/src/Catppuccin-"$VARIANT"-Cursors || exit
mkdir -p "${NAMED}" "$ANIMONE" "$ANIMTWO" || exit # if mkdir fails for any reason, exit early
mv -v "$ANIMONE"-* "$ANIMONE"
mv -v "$ANIMTWO"-* "$ANIMTWO"

# create a containing folder with name of icon
echo -en "Step 2: Creating folders\n"
rm *_24.svg
for file in *.svg; do
	file_contents="
    resize_algorithm = bilinear
    define_size = 64, $file
    "
	direct="${file%.svg}"
	mkdir -- "$direct"
	mv -- "$file" "$direct"
	echo "$file_contents" >"$direct"/meta.hl
done

function process_meta() {
	local ANIM="$1"
	local output=""
	for i in {1..12}; do
		output+="define_size = 64, $ANIM-$(printf "%02d" "$i").svg,500\n"
	done

	echo -e "resize_algorithm = bilinear\n$output" >"$ANIM"/meta.hl
}

echo -en "Step 3: Processing meta files\n"
process_meta "$ANIMONE"
process_meta "$ANIMTWO"

mv !("$NAMED") ./"$NAMED"
rm $NAMED/index.theme

# index.theme gen
echo "[Icon Theme]
Name=$NAMED
Comment=generated by hyprman
" >>index.theme

echo "name = $NAMED
description = let there be ants
version = 0.1
cursors_directory = $NAMED
" >>manifest.hl

hyprcursor-util --create .
echo -en "finished making cursor, copying to current directory"

cp -r ../theme_$NAMED $current_dir/$NAMED
