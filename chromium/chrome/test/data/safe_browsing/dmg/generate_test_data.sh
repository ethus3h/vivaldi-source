#!/bin/sh

# Copyright 2015 The Chromium Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

THIS_DIR=$(dirname "$0")

OUT_DIR="$1"

if [[ ! "$1" ]]; then
  echo "Usage: $(basename "$0") [output_dir]"
  exit 1
fi

if [[ -e "$1" && ! -d "$1" ]]; then
  echo "Output directory \`$1' exists but is not a directory."
  exit 1
fi
if [[ ! -d "$1" ]]; then
  mkdir -p "$1"
fi

generate_test_data() {
  # HFS Raw Images #############################################################

  MAKE_HFS="${THIS_DIR}/make_hfs.sh"
  "${MAKE_HFS}" HFS+ 1024 "${OUT_DIR}/hfs_plus.img"
  "${MAKE_HFS}" hfsx $((8 * 1024)) "${OUT_DIR}/hfsx_case_sensitive.img"

  # DMG Files ##################################################################

  DMG_SOURCE=$(mktemp -d -t dmg_generate_test_data.XXXXXX)
  echo "This is a test DMG file. It has been generated from " \
      "chrome/test/data/safe_browsing/dmg/generate_test_data.sh" \
          > "${DMG_SOURCE}/README.txt"
  dd if=/dev/urandom of="${DMG_SOURCE}/random" bs=512 count=4

  DMG_TEMPLATE_FORMAT="UDRO"
  DMG_FORMATS="UDRW UDCO UDZO UDBZ UFBI UDTO UDSP"
  DMG_LAYOUTS="SPUD GPTSPUD NONE"

  # First create uncompressed template DMGs in the three partition layouts.
  for layout in ${DMG_LAYOUTS}; do
    DMG_NAME="dmg_${DMG_TEMPLATE_FORMAT}_${layout}"
    hdiutil create -srcfolder "${DMG_SOURCE}" \
      -format "${DMG_TEMPLATE_FORMAT}" -layout "${layout}" \
      -volname "${DMG_NAME}" \
      -ov "${OUT_DIR}/${DMG_NAME}"
  done

  # Convert each template into the different compression format.
  for format in ${DMG_FORMATS}; do
    for layout in ${DMG_LAYOUTS}; do
      TEMPLATE_NAME="dmg_${DMG_TEMPLATE_FORMAT}_${layout}.dmg"
      DMG_NAME="dmg_${format}_${layout}"
      hdiutil convert "${OUT_DIR}/${TEMPLATE_NAME}" \
        -format "${format}" -o "${OUT_DIR}/${DMG_NAME}"
    done
  done

  rm -rf "${DMG_SOURCE}"

  # DMG With Mach-O ############################################################

  mkdir "${DMG_SOURCE}"

  FAKE_APP="${DMG_SOURCE}/Foo.app/Contents/MacOS/"
  mkdir -p "${FAKE_APP}"
  cp "${THIS_DIR}/../mach_o/executablefat" "${FAKE_APP}"
  touch "${FAKE_APP}/../Info.plist"

  mkdir "${DMG_SOURCE}/.hidden"
  cp "${THIS_DIR}/../mach_o/lib64.dylib" "${DMG_SOURCE}/.hidden/"

  hdiutil create -srcfolder "${DMG_SOURCE}" \
    -format UDZO -layout SPUD -volname "Mach-O in DMG" -ov \
    "${OUT_DIR}/mach_o_in_dmg"

  rm -rf "${DMG_SOURCE}"
}

# Silence any log output.
generate_test_data &> /dev/null
