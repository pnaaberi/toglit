# Agent instructions — TOGLIT

- Read this file and README.md before changes; verify source custody and a clean Git baseline.
- Keep the tool limited to user-owned KDE presentation settings in SteamOS Desktop Mode.
- Do not add sudo, /etc, SDDM, boot, autologin, reboot or session-selection mutations.
- Preserve the user's first-launch backup; never delete or replace it silently.
- Treat installers, shortcut paths and shell input as safety-sensitive.
- Run the documented shell checks and disposable HOME/config fixtures; never use live KDE state for tests.
- Source CI and synthetic launcher tests do not establish Steam Deck/device acceptance.
- Push or publish only with explicit owner authorization. Never publish local state, private audit notes or unrelated commits.
- Update README/changelog for changed behavior, with exact source/check and rollback evidence kept privately.
