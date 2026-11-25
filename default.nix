# telegram-notify — the Telegram notification binaries of one NixOS host.
#
# Packaging only. What each binary does and which environment variables it
# reads are documented in README.md and in the header of its `src/` file.
{
  lib,
  rustPlatform,
}:

rustPlatform.buildRustPackage {
  pname = "telegram-notify";
  version = (lib.importTOML ./Cargo.toml).package.version;

  # Keep the build output, the flake, the docs and the BotFather assets out of
  # the store copy; none of them is an input of the build.
  src = lib.fileset.toSource {
    root = ./.;
    fileset = lib.fileset.unions [
      ./Cargo.toml
      ./Cargo.lock
      ./src
    ];
  };

  cargoLock.lockFile = ./Cargo.lock;

  meta = {
    description = "Telegram notifications for a NixOS host: calendar digest, reminders, watchdogs and an assistant bot";
    homepage = "https://github.com/neg-serg/telegram-notify";
    license = lib.licenses.mit;
    mainProgram = "telegram-calendar-reminder";
    platforms = lib.platforms.unix;
  };
}
