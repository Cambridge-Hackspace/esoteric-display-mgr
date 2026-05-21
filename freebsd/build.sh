#!/usr/local/bin/bash

PRJ_DIR=/usr/local/edm
PATCH_DIR="${PROJ_DIR}/patches"

if [ ! -d "${PRJ_DIR}/src" ]; then
  git clone https://github.com/Cambridge-Hackspace/esoteric-display-mgr src
  cd "${PRJ_DIR}/src/assets"
  npm i tailwindcss
  cd "${PRJ_DIR}/src"
  if [ -d "${PATCH_DIR}" ]; then
    for patch in $(ls "${PATCH_DIR}"); do git apply "${PATCH_DIR}/$patch"; done
  fi
  mix deps.get --only prod
else
  cd "${PRJ_DIR}/src"
  rm -rf _build
  mix phx.digest.clean --all
  git pull
fi

mix compile && mix assets.deploy && mix release
rm -rf "${PRJ_DIR}/bin"
cp -r "${PRJ_DIR}/src/_build/prod/rel/esoteric_display_mgr" "${PRJ_DIR}/bin"

printf 'done\n'
