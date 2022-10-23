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
  - 'Vanilla version' of minecraft (1.17.1 at time of writing README)
  - ${HOME}/mc/ is the desired root path for a server install

## Assumptions of bash script:
  - ${HOME}/mc/mcpluginreop/ will be manually populated with spigot / bukkit plugins
  - BetterRTP will be manually downloaded before running
  - python3 is installed 
  - java dependencies of minecraft installed
  - probably numerous linux package installations that aren't documented here
  
## Side effects:
  - aside from the numerous scripts and configs, `cfg_yaml_2ndLevel.py` python script used by one of the created bash scripts will be present
  
## Server version downloaded:
  - paper (aka paperclip), last successful jenkins artifact

## Plugins fetched by script:
  - EssentialsX
  - LuckPerms
  
## Manually downloaded plugins (in ${HOME}/mc/mcpluginrepo/ by default):
  - Tree Capitator (personal preference)
  - HorseTpWithMe (personal preference)
  
## Previously advocated plugins:
  - BetterRTP (obsoleted by EssentialsX tpr feature)
  - ChopTree (not updated for 1.19 API, so dropped in favor of TreeCapitator)
