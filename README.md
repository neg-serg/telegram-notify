# telegram-notify

The Telegram notification binaries of one NixOS host: a morning calendar
digest, a daily reminder with a confirm button, crash-loop and ZFS watchdogs, a
failed-unit/OOM/sshd alert scanner, an Alertmanager webhook bridge — and the
assistant bot that answers on the other side of the same chat.

The code is host-agnostic, the configuration is not. Every path, chat id and
secret location arrives through the environment, set by the systemd units of
the host that deploys it (`configuration.nix` territory, not this repository).
Nothing is substituted at build time, so any binary can be pointed at stubs and
driven in a test — which is exactly what the unit tests do.

## Binaries

| binary | what it does |
| --- | --- |
| `telegram-calendar-reminder` | today's `khal` events as one line per entry, delivered through a `telegram-send`-style wrapper that owns the proxy retry policy; delivery problems exit 0 so a mail-less host never fails the unit |
| `telegram-pill-reminder` | one message a day with an inline "Mark taken" button; silent when the panel already recorded the dose, and a dated marker file keeps a snapshot restore or a late boot from sending twice |
| `telegram-pill-bot` | the long-poll loop behind all of it: button presses become a panel state and calendar event update, `/status` renders a deterministic host snapshot, free text goes to a local llama-swap model, `/note…` talks to a zk notebook, `/herdr` drives a terminal-agent farm, `/screenshot` captures a window, `/do` runs an allow-listed action |
| `telegram-crashloop` | diffs `NRestarts` of every restart-enabled unit across both systemd managers and alerts at a threshold, at most once an hour per unit |
| `telegram-zfs-watch` | pool/vdev state, error counters, scrub results, sanoid snapshot freshness and space, and NVMe SMART — reported on transitions only |
| `telegram-alert-scanner` | newly failed units, OOM kills and sshd brute force, posted to a local Alertmanager in its wire format (which routes them on to Telegram) |
| `telegram-alert-bridge` | listens on `127.0.0.1:9094`, renders each Alertmanager webhook alert as one emoji-prefixed line |

## Design notes

- **No crates.** `[dependencies]` is empty. Each binary is its own crate root and
  shares the common helpers by including `src/lib.rs` through
  `#[path = "lib.rs"] mod shared;` — no library target, no duplicated code.
- **The token never reaches `argv`.** The Bot API is called through `curl`, and
  `/proc/<pid>/cmdline` is world-readable, so the URL carrying the bot token is
  handed to `curl -K -` on stdin instead of as an argument.
- **Watchdogs report transitions, not state.** A standing fault does not turn
  into a daily nag; the first run after a version bump only re-baselines, so a
  fixed false positive cannot produce a fake "recovered" message.
- **Secrets are files, not environment values.** The token and chat id are read
  from root-owned `0400` files (typically SOPS-decrypted under `/run/secrets`).
  The bridge re-reads them per request, so rotating a chat id needs no restart.

## Configuration

Each binary documents its own environment in the header of its source file —
`src/pill.rs`, `src/pill_bot.rs`, `src/zfs_watch.rs` and so on are the reference,
and the `PILL_*`, `BRIDGE_*`, `CRASHLOOP_*`, `ZFS_WATCH_*`, `KHAL_*` prefixes are
the grouping. Tests drive the same surface: `PILL_BOT_ONCE=1`,
`CRASHLOOP_NOW`, `ZFS_WATCH_NOW` and `TELEGRAM_REMINDER_TODAY` replace the clock
and the poll loop.

Outside the Bot API itself, the binaries shell out to what the host provides:
`curl`, `khal`, `zpool`, `nvme`, `systemctl`, and — for the assistant bot —
`hyprctl`/`grim`, `nb`/`zk`/`rg`, `runuser` and `herdr`.

## Assets

`assets/avatar.svg` is the bot's profile picture: a pure-vector phosphor CRT with
the labels outlined from a bitmap font, so it needs no font or image library. The
512/1024 rasters beside it are what BotFather's `/setuserpic` accepts.

## Build and test

```sh
nix build .#default     # all seven binaries
nix develop             # cargo, rustc, rustfmt, clippy
cargo test              # unit tests, next to the code they cover
cargo fmt --check
```

## License

MIT — see [LICENSE](LICENSE).
