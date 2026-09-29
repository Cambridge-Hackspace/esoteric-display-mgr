#!/bin/sh
#
# Build a release of the Esoteric Display Manager and put it in place.
#
#   deploy/build.sh [ref]
#
# `ref` is the branch or tag to build, and defaults to main. The same script
# is meant to work wherever the app is deployed; what differs between
# platforms is worked out below rather than kept in per-platform copies.
#
# Everything lives under one directory, EDM_HOME:
#
#   src/       a checkout of the repository
#   bin/       the release that is run
#   bin.prev/  the release that bin/ replaced, kept in case it has to go back
#   uploads/   media uploaded through the app
#   db/        the database (not touched by this script)
#
# Settings, from the environment:
#
#   EDM_HOME   where all of that goes. Defaults to the directory holding the
#              src/ checkout this script is in.
#   EDM_REPO   where to clone from, the first time.
#
# Run it as the account that owns EDM_HOME. It does not restart the service:
# do that once it has finished.

set -eu

EDM_REPO="${EDM_REPO:-https://github.com/Cambridge-Hackspace/esoteric-display-mgr}"
REF="${1:-main}"
APP=esoteric_display_mgr

say() { printf '==> %s\n' "$*"; }
die() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

# ------------------------------------------------------------------- where
if [ -z "${EDM_HOME:-}" ]; then
  here="$(cd -- "$(dirname -- "$0")" && pwd)"
  checkout="$(dirname -- "$here")"
  [ "$(basename -- "$checkout")" = "src" ] ||
    die "EDM_HOME is not set, and this script is not inside a src/ checkout to infer it from"
  EDM_HOME="$(dirname -- "$checkout")"
fi
[ -d "$EDM_HOME" ] || die "EDM_HOME does not exist: $EDM_HOME"

SRC="$EDM_HOME/src"
UPLOADS="$EDM_HOME/uploads"

# -------------------------------------------------------------------- tools
for tool in git mix npm; do
  command -v "$tool" >/dev/null 2>&1 || die "$tool is not installed"
done

# The tailwind and vix packages ship ready-made binaries for Linux and macOS
# and for nothing else. Elsewhere the system has to provide them: a
# tailwindcss on the PATH, which config/config.exs picks up by itself, and
# libvips, which vix has to be told to build against.
case "$(uname -s)" in
Linux | Darwin) ;;
*)
  command -v tailwindcss >/dev/null 2>&1 ||
    die "no tailwindcss on the PATH, and none is published for $(uname -s) (npm install -g @tailwindcss/cli)"
  : "${VIX_COMPILATION_MODE:=PLATFORM_PROVIDED_LIBVIPS}"
  export VIX_COMPILATION_MODE
  ;;
esac

export MIX_ENV=prod

# ------------------------------------------------------------------- source
if [ ! -d "$SRC/.git" ]; then
  say "cloning $EDM_REPO"
  git clone "$EDM_REPO" "$SRC"
fi

cd "$SRC"

# Changes made here by hand are how a deployment drifts away from the
# repository until nobody can rebuild it. Refuse to build on top of them.
if [ -n "$(git status --porcelain --untracked-files=no)" ]; then
  git status --short --untracked-files=no >&2
  die "$SRC has uncommitted changes. Settings belong in the environment, not in the source; commit these upstream or discard them"
fi

say "fetching $REF"
git fetch --tags origin
git checkout --quiet "$REF"
# A branch moves, a tag does not; only a branch has anything to catch up to.
if git show-ref --verify --quiet "refs/remotes/origin/$REF"; then
  git merge --ff-only "origin/$REF"
fi
say "building $(git describe --always --dirty)"

# -------------------------------------------------------------------- build
# Always reinstalled, never "if missing". Hex and rebar are compiled for the
# Erlang they were installed under, and a copy left over from before an
# upgrade fails to load with an error that says nothing about why.
mix local.hex --force
mix local.rebar --force
mix deps.get --only prod

(cd assets && npm ci)

mix compile
mix assets.deploy
mix release --overwrite

BUILT="$SRC/_build/prod/rel/$APP"
[ -x "$BUILT/bin/$APP" ] || die "the build finished but there is no release at $BUILT"

# ------------------------------------------------------------------ install
say "installing into $EDM_HOME/bin"
rm -rf "$EDM_HOME/bin.new"
cp -R "$BUILT" "$EDM_HOME/bin.new"

# Uploaded media is written under the app's priv directory, which is inside
# the release and so is replaced along with it. Keep the files outside and
# link them in, or every deployment would throw away what people uploaded.
mkdir -p "$UPLOADS"
for old in "$EDM_HOME"/bin/lib/"$APP"-*/priv/static/uploads; do
  # A directory that is not yet a link is a release from before this script:
  # rescue what is in it.
  if [ -d "$old" ] && [ ! -L "$old" ]; then
    say "moving existing uploads out of the old release"
    find "$old" -mindepth 1 -maxdepth 1 ! -name .keep -exec mv -n {} "$UPLOADS"/ \;
  fi
done
for new in "$EDM_HOME"/bin.new/lib/"$APP"-*/priv/static/uploads; do
  rm -rf "$new"
  ln -s "$UPLOADS" "$new"
done

rm -rf "$EDM_HOME/bin.prev"
if [ -d "$EDM_HOME/bin" ]; then
  mv "$EDM_HOME/bin" "$EDM_HOME/bin.prev"
fi
mv "$EDM_HOME/bin.new" "$EDM_HOME/bin"

say "done. Restart the service to run it; the previous release is in $EDM_HOME/bin.prev"
