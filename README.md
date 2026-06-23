# MinecraftServerSetupAutomation
Linux bash scripts and python functions to automate download, install &amp; configure a minecraft (paper) server on Linux

## NOTICE:
  - running this script will auto-accept the minecraft EULA, hence running this script constitutes EULA acceptance

## Usage:
  - `./mkmcsrvr.sh [server_name]` - if server_name is omitted 'Hector' will be default
  - once script completes, run with `./run_<server_Name>.sh` - i.e. `./run_Hector.sh`
  - (recommended) once server starts up, stop it with server console command `stop`
  - run `./cfg_<server_name>_after1strun.sh` in order to change settings in yml configs for plugins generated on first run
  - when ready to run server, `./run_<server_name>.sh` as desired

## Configured in 'header' definitions section of bash script:
  - 'Vanilla version' of minecraft (`VANILLA_VERSION`, a Paper "version group")
      - default is `26.1` (resolves to the newest STABLE patch, e.g. 26.1.2)
      - old numbering groups: `1.19`, `1.21`, etc.
      - new (2026+) calendar numbering groups: `26.1`, `26.2`, etc.
      - the script auto-picks the newest version in the group that has a STABLE build,
        so groups that only have release-candidate builds (e.g. `26.2` as of mid-2026)
        are skipped with an error rather than installing an unstable jar
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
  - Tree Capitator (personal preference)
  - HorseTpWithMe (personal preference)
  
## Previously advocated plugins:
  - BetterRTP (obsoleted by EssentialsX tpr feature)
  - ChopTree (not updated for 1.19 API, so dropped in favor of TreeCapitator)
