# MinecraftServerSetupAutomation
Linux bash scripts and python functions to automate download, install &amp; configure a minecraft (paper) server on Linux

## NOTICE:
  - running this script will auto-accept the minecraft EULA, hence running this script constitutes EULA acceptance

## Usage:
  - `./mkmcsrvr.sh [server_name] [port] [heap]`
      - `server_name` - omitted defaults to 'Hector'
      - `port` - omitted defaults to 25565. Give each world on a host its own port;
        two servers on 25565 will fight over the bind and the second to start fails
      - `heap` - JVM heap for the generated launch script, omitted defaults to `3G`.
        Several servers on one host share its RAM: budget each heap plus ~1G of JVM
        overhead against total memory
      - e.g. a second world alongside an existing one: `./mkmcsrvr.sh newworld 25566 2G`
  - once script completes, run with `./run_<server_Name>.sh` - i.e. `./run_Hector.sh`
      - each world launches into its own screen named `mc_<server_name>`, so stop a
        specific one with `screen -S mc_<server_name> -X stuff "stop\n"`
  - (recommended) once server starts up, stop it with server console command `stop`
  - run `./cfg_<server_name>_after1strun.sh` in order to change settings in yml configs for plugins generated on first run
  - when ready to run server, `./run_<server_name>.sh` as desired

## Configured in 'header' definitions section of bash script:
  - 'Vanilla version' of minecraft (`VANILLA_VERSION`, a Paper "version group")
      - default is `26.2` (resolves to the newest STABLE patch)
      - old numbering groups: `1.19`, `1.21`, etc.
      - new (2026+) calendar numbering groups: `26.1`, `26.2`, etc.
      - the script auto-picks the newest version in the group that has a STABLE build,
        so versions carrying only release-candidate / ALPHA builds (e.g. `26.2-rc-2`)
        are skipped rather than installing an unstable jar; if no version in the
        group has a STABLE build, the script errors out instead of guessing
  - ${HOME}/mc/ is the desired root path for a server install

## Requirements / assumptions of bash script:
  - `curl`, `wget`, `unzip`, and `python3` are installed
  - Java is installed, matching the target MC version:
    **Java 21** for MC 1.20.5&ndash;1.21.x, **Java 25** for MC 26.x
    (e.g. Debian: install Eclipse Temurin via the Adoptium apt repo)
  - ${HOME}/mc/mcpluginrepo/ will be manually populated with spigot / bukkit plugins
    (these can't be auto-downloaded; spigotmc.org is behind Cloudflare)
  - probably numerous linux package installations that aren't documented here
  
## Side effects:
  - aside from the numerous scripts and configs, `cfg_yaml_2ndLevel.py` python script used by one of the created bash scripts will be present
  
## Server version downloaded:
  - paper (aka paperclip), newest STABLE build resolved via the PaperMC Fill v3 API
    (`fill.papermc.io/v3`). The legacy v2 API stopped getting builds on 2025-12-31 and
    is shut down on 2026-07-01, so the script was migrated to v3.

## Plugins fetched by script:
  - EssentialsX (latest GitHub release; XMPP / GeoIP / AntiBuild / Discord modules removed)
  - Vault (latest GitHub release)
  - LuckPerms (latest ci.lucko.me build; non-Bukkit/Paper platform jars removed)
  
## LuckPerms command to add a user to a group:
  - `/lp user <user> group add <group>`
  
## Manually downloaded plugins (in ${HOME}/mc/mcpluginrepo/ by default):
  - [Thizzy'z Tree Feller](https://modrinth.com/plugin/thizzyz-tree-feller) (fell whole trees by chopping one log; supports 26.1.x, GPL-3.0)
      - replaces the old CrisTreeCapitator, which is no longer maintained for current versions
  - HorseTpWithMe (personal preference)
  
## Keeping chunks loaded while offline (no plugin):
  - the old KeepChunks plugin is unmaintained (caps at 1.21.1), so use the vanilla
    built-ins instead -- they are command-driven, persist across restarts, and won't
    break on the next MC version
  - `/forceload add <fromX> <fromZ> [<toX> <toZ>]` -- pins a chunk (or rectangular
    area) of block coords at a ticking level: random ticks (crop/tree growth), hoppers,
    redstone, and entities all keep running there while you're offline
      - `/forceload remove ...`, `/forceload remove all`, `/forceload query` to manage/audit
      - requires op / permission level 2 (or run from console)
      - stored in world data, so it survives restarts -- this is the direct KeepChunks replacement
  - `spawn-chunk-radius` (server.properties) -- keeps a `(2R+1)x(2R+1)` chunk square
    around world spawn permanently loaded & ticking; modern replacement for Paper's
    deprecated `keep-spawn-loaded` knobs. `0` disables; keep it modest (2-4) since the
    whole area ticks 24/7 regardless of player presence
  - EssentialsX has no chunk-keeping feature -- it's a command suite only

## Previously advocated plugins:
  - BetterRTP (obsoleted by EssentialsX tpr feature)
  - ChopTree (not updated for 1.19 API, so dropped in favor of TreeCapitator)
