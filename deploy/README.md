# Deploying

One script builds the app on any platform, and one file holds everything that
differs between deployments. Nothing in the source should need editing on a
server; if something does, that is a missing setting, and it belongs in
`config/runtime.exs`.

## Layout

Everything lives under one directory, `EDM_HOME` (`/usr/local/edm` on the
hackspace server), owned by the account the app runs as:

| Path | What it is |
|---|---|
| `src/` | a checkout of this repository |
| `bin/` | the release that is run |
| `bin.prev/` | the release before it, kept in case it has to go back |
| `uploads/` | media uploaded through the app |
| `db/` | the SQLite database |

## What the machine needs

- Erlang/OTP 27 or newer and Elixir 1.18 or newer
- Node.js and npm
- git, and a C compiler for the native dependencies

Linux and macOS need nothing more. Anywhere else, two things that are
otherwise downloaded ready-made have to come from the system:

- **tailwindcss** on the `PATH`: `npm install -g @tailwindcss/cli`
- **libvips**: on FreeBSD, `pkg install vips`

## Building

As the account that owns `EDM_HOME`:

```sh
src/deploy/build.sh            # builds main
src/deploy/build.sh v0.2.0     # or a tag, or another branch
```

The first time, there is no `src/` to run it from. Fetch the script by itself
and tell it where to work:

```sh
EDM_HOME=/usr/local/edm sh build.sh
```

It refuses to build if `src/` has uncommitted changes. It swaps the new
release into `bin/` but does not restart anything; do that once it finishes.

## Settings

Copy `edm.env.sample`, fill it in, and keep it owned by root and mode 600: it
holds the secret key.

| Setting | Default | |
|---|---|---|
| `DATABASE_PATH` | required | the SQLite database |
| `SECRET_KEY_BASE` | required | `mix phx.gen.secret` |
| `PORT` | `4000` | port to listen on |
| `PHX_BIND` | `::` | address to listen on |
| `PHX_HOST` | `example.com` | public host name |
| `PHX_URL_PORT` | `443` | public port |
| `PHX_URL_SCHEME` | `https` | public scheme |
| `PHX_SSL_EXCLUDE_HOSTS` | `localhost,127.0.0.1` | hosts not redirected to https |

## Running it as a service on FreeBSD

```sh
install -m 755 src/deploy/freebsd/rc.d/edm /usr/local/etc/rc.d/edm
install -m 600 src/deploy/edm.env.sample /usr/local/etc/edm.env   # then edit it
sysrc edm_enable=YES
service edm start
```

It logs to `/var/log/edm.log`. After a build, `service edm restart`.

## Going back

```sh
service edm stop
mv bin bin.bad && mv bin.prev bin
service edm start
```

Uploads and the database are outside `bin/`, so they are not affected.
