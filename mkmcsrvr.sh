#!/bin/bash

# REQUIRES: installation of corresponding Java for the target MC version --
#   MC 1.20.5 - 1.21.x need Java 21; MC 26.x needs Java 25 -- plus
#   curl, wget, unzip, python3


MC_WORLD_NAME=${1:-Hector}
# Listen port. Give each world on a host its own port -- two servers on the default
# 25565 will fight over the bind and the second one to start will fail. 25566, 25567,
# ... are the conventional choices for additional instances.
MC_PORT=${2:-25565}
# JVM heap for the generated launch script. Sized per world, since several servers
# sharing a host also share its RAM; total heap plus ~1G JVM overhead each must fit.
MC_HEAP=${3:-3G}
# World difficulty: peaceful, easy, normal or hard. Case-insensitive here; it is
# lowercased below because server.properties expects the lowercase spelling.
MC_DIFFICULTY=${4:-normal}
MC_DIFFICULTY=$(echo "${MC_DIFFICULTY}" | tr '[:upper:]' '[:lower:]')
# fail before downloading ~65MB of jars: an unrecognised value would otherwise be
# written straight into server.properties and silently ignored by the server
case "${MC_DIFFICULTY}" in
  peaceful|easy|normal|hard) ;;
  *)
    echo "ERROR: difficulty must be peaceful, easy, normal or hard (got '${MC_DIFFICULTY}')" >&2
    exit 1
    ;;
esac
# VANILLA_VERSION is a Paper "version group" key (see https://fill.papermc.io/v3/projects/paper).
# The script auto-selects the newest version within the group that has a STABLE build.
#   - Old numbering groups look like "1.19", "1.21"
#   - New (2026+) calendar numbering groups look like "26.1", "26.2"
VANILLA_VERSION="26.2"
MC_DIR="${HOME}/mc/${MC_WORLD_NAME}"
PLUGIN_DIR="${MC_DIR}/plugins"
LOCAL_PLUGIN_REPO="${HOME}/mc/mcpluginrepo"
# Minecraft usernames (space-separated) to seed into the LuckPerms vip / staff groups
# at build time. UUIDs come from the Mojang API, so no first login is required.
# Online-mode only: in offline mode the server derives a different (v3 name-hash) UUID.
# Either list may be left empty. staff inherits vip, which inherits default, so a name
# only needs to appear in the highest list that applies.
MC_VIP_USERS="RobotButtonTooth"
MC_STAFF_USERS=""
# PaperMC migrated to the Fill v3 API: the legacy api.papermc.io/v2 stopped getting
# builds on 2025-12-31 and is shut down on 2026-07-01. Fill v3 requires a
# non-generic User-Agent that includes a contact URL or email.
PAPER_API_URL_ROOT="https://fill.papermc.io/v3/projects/paper"
PAPER_API_USER_AGENT="MinecraftServerSetupAutomation/2.0 (+https://github.com/lcdnbl/MinecraftServerSetupAutomation)"

# create directory and download latest paper server
mkdir -p ${MC_DIR}
#   Resolve newest STABLE build in the version group, plus its embedded download URL.
#   (In Fill v3 builds are returned newest-first and the download URL is embedded.)
read -r LATEST_SUBVERSION PAPER_BUILD_URL PAPER_JAR_NAME < <(
  python3 - "$PAPER_API_URL_ROOT" "$VANILLA_VERSION" "$PAPER_API_USER_AGENT" <<'PY'
import json, sys, urllib.request

root, group, ua = sys.argv[1], sys.argv[2], sys.argv[3]

def get(url):
    req = urllib.request.Request(url, headers={"User-Agent": ua, "Accept": "application/json"})
    with urllib.request.urlopen(req) as r:
        return json.load(r)

versions = get(root)["versions"].get(group)
if not versions:
    sys.exit("No Paper versions found for group {}".format(group))

for ver in versions:  # newest first
    builds = get("{}/versions/{}/builds".format(root, ver))
    stable = [b for b in builds if b.get("channel") == "STABLE"]
    if stable:
        dl = stable[0]["downloads"]["server:default"]  # builds newest-first
        print(ver, dl["url"], dl["name"])
        break
else:
    sys.exit("No STABLE Paper build found in group {}".format(group))
PY
)

if [ -z "$PAPER_BUILD_URL" ]; then
  echo "ERROR: could not resolve a Paper download from the Fill v3 API" >&2
  exit 1
fi
echo "Downloading Paper ${PAPER_JAR_NAME} (MC ${LATEST_SUBVERSION}) ..."
#   Perform actual download (Fill data host also expects the identifying User-Agent)
wget --header="User-Agent: ${PAPER_API_USER_AGENT}" "$PAPER_BUILD_URL" -O ${MC_DIR}/paperclip.jar

# create plugins directory
mkdir ${PLUGIN_DIR}

# Plugin:  Protocollib
# not currently configured

# Plugin:  EssentialsX  (download every release asset, then prune unwanted modules)
# NB: parse the asset URLs with python3 rather than `grep browser_download_url | cut`;
#     the GitHub API may return minified (single-line) JSON, in which case the
#     grep|cut pipeline silently grabs the wrong field (the release's api "url").
curl -s https://api.github.com/repos/EssentialsX/Essentials/releases/latest \
  | python3 -c "import sys, json; [print(a['browser_download_url']) for a in json.load(sys.stdin)['assets']]" \
  | wget -i - -P ${PLUGIN_DIR}

# Discord* also removes DiscordLink; Geo* removes GeoIP
rm -f ${PLUGIN_DIR}/EssentialsXXMPP*.jar
rm -f ${PLUGIN_DIR}/EssentialsXGeo*.jar
rm -f ${PLUGIN_DIR}/EssentialsXAntiBuild*.jar
rm -f ${PLUGIN_DIR}/EssentialsXDiscord*.jar

# Plugin:  Vault  (same robust JSON parsing as EssentialsX)
curl -s https://api.github.com/repos/MilkBowl/Vault/releases/latest \
  | python3 -c "import sys, json; [print(a['browser_download_url']) for a in json.load(sys.stdin)['assets']]" \
  | wget -i - -P ${PLUGIN_DIR} # was: https://www.spigotmc.org/resources/vault.34315/

# Because spigotmc.org downloads are protected by Cloudflare, etc. the following wgets won't work,
# we will instead need to manually download the spigot plugins, rsync them into LOCAL_PLUGIN_REPO
cp ${LOCAL_PLUGIN_REPO}/* ${PLUGIN_DIR}/
# Plugin:  HorseTpWithMe
#wget https://www.spigotmc.org/resources/horsetpwithme.8186/download?version=342775 -O ${PLUGIN_DIR}/HorseTpWithMe.jar
# Plugin:  ChopTree
#wget https://www.spigotmc.org/resources/choptree2.67585/download?version=282300 -O ${PLUGIN_DIR}/ChopTree2.jar

# Plugin:  luck perms
wget https://ci.lucko.me/job/LuckPerms/lastSuccessfulBuild/artifact/*zip*/archive.zip -O ${PLUGIN_DIR}/luckperms.zip
unzip -j ${PLUGIN_DIR}/luckperms.zip -d ${PLUGIN_DIR}
rm ${PLUGIN_DIR}/luckperms.zip
# Keep only the modern Bukkit/Paper build; delete every other platform jar.
# (Blocklisting individual platforms is fragile -- upstream keeps adding them,
#  e.g. Forge / NeoForge / Hytale -- so whitelist the one jar we want instead.
#  The [0-9] guard keeps LuckPerms-Bukkit-<ver>.jar while dropping the
#  separate LuckPerms-Bukkit-Legacy-<ver>.jar.)
find ${PLUGIN_DIR} -maxdepth 1 -name 'LuckPerms-*.jar' ! -name 'LuckPerms-Bukkit-[0-9]*.jar' -delete

# create folder structure for LuckPerms files using YAML for storage
LUCKPERMS_DIR=${PLUGIN_DIR}/LuckPerms
LP_YAMLSTR_GRPS_DIR=${LUCKPERMS_DIR}/yaml-storage/groups
mkdir -p ${LP_YAMLSTR_GRPS_DIR}

# create LuckPerms default group permissions
/bin/cat <<EOM > ${LP_YAMLSTR_GRPS_DIR}/default.yml
name: default
permissions:
- essentials.back
- essentials.back.ondeath
- essentials.delhome
- essentials.enderchest
- essentials.home
- essentials.sethome
- essentials.sethome.multiple
- essentials.spawn
- essentials.tp
- essentials.tp.others
- essentials.tpa
- essentials.tpacancel
- essentials.tpaccept
- essentials.tpahere
- essentials.tpdeny
- essentials.tpr
- essentials.warp
- essentials.workbench
EOM

# create LuckPerms vip group permissions
/bin/cat <<EOM > ${LP_YAMLSTR_GRPS_DIR}/vip.yml
name: vip
parents:
- default
permissions:
- essentials.setwarp
- essentials.jump
- essentials.sethome.multiple.vip
EOM

# create LuckPerms staff group permissions
# Deliberately minimal: it inherits vip (and default through it) and adds only the
# home tier, mirroring how vip extends default. Add moderation nodes here as needed
# rather than assuming any -- Essentials' staff home limit is the only thing that
# breaks without this group existing.
/bin/cat <<EOM > ${LP_YAMLSTR_GRPS_DIR}/staff.yml
name: staff
parents:
- vip
permissions:
- essentials.sethome.multiple.staff
EOM

# seed group membership without needing a first login: LuckPerms keys its user files
# by UUID, and the Mojang API resolves username -> UUID on demand.
LP_YAMLSTR_USRS_DIR=${LUCKPERMS_DIR}/yaml-storage/users
mkdir -p ${LP_YAMLSTR_USRS_DIR}

# Collect the groups each name was listed in before writing anything, so a user who
# appears in more than one list gets a single file carrying every group rather than
# one list's file silently overwriting the other's.
declare -A LP_USER_GROUPS
for MCUSER in ${MC_VIP_USERS}; do
  LP_USER_GROUPS[${MCUSER}]="${LP_USER_GROUPS[${MCUSER}]} vip"
done
for MCUSER in ${MC_STAFF_USERS}; do
  LP_USER_GROUPS[${MCUSER}]="${LP_USER_GROUPS[${MCUSER}]} staff"
done

for MCUSER in "${!LP_USER_GROUPS[@]}"; do
  RAWID=$(curl -s --max-time 15 \
    "https://api.mojang.com/users/profiles/minecraft/${MCUSER}" \
    | python3 -c "import sys, json; print(json.load(sys.stdin)['id'])" 2>/dev/null)

  # a failed lookup (outage, typo, renamed account) shouldn't abort an otherwise
  # good build -- warn and move on, leaving the user to be added post-login
  if [ -z "${RAWID}" ]; then
    echo "WARNING: could not resolve UUID for ${MCUSER}; skipping group seed" >&2
    continue
  fi

  # LuckPerms expects the dashed 8-4-4-4-12 form; the API returns it undashed
  UUID=$(echo "${RAWID}" | sed -E 's/(.{8})(.{4})(.{4})(.{4})(.{12})/\1-\2-\3-\4-\5/')

  {
    echo "uuid: ${UUID}"
    echo "name: ${MCUSER}"
    echo "primary-group: default"
    echo "parents:"
    echo "- default"
    for LPGROUP in ${LP_USER_GROUPS[${MCUSER}]}; do
      echo "- ${LPGROUP}"
    done
  } > ${LP_YAMLSTR_USRS_DIR}/${UUID}.yml
  echo "seeded ${MCUSER} (${UUID}) into:${LP_USER_GROUPS[${MCUSER}]}"
done

# create launch script
/bin/cat <<EOM > ./run_${MC_WORLD_NAME}.sh
#!/bin/bash
# if not already running in screen, start screen first
# the screen is named per-world so that several servers on one host stay separately
# addressable, e.g. screen -S mc_${MC_WORLD_NAME} -X stuff "stop\\n"
if [ -z "\$STY" ]; then exec screen -dm -S mc_${MC_WORLD_NAME} /bin/bash "\$0"; fi
cd ${MC_DIR}
java -Xmx${MC_HEAP} -Xms${MC_HEAP} -jar paperclip.jar nogui
EOM
chmod +x run_${MC_WORLD_NAME}.sh

# create config script for after first server run
/bin/cat <<EOM > ./cfg_${MC_WORLD_NAME}_after1strun.sh
#!/bin/bash
python3 cfg_yaml_2ndLevel.py -i ${PLUGIN_DIR}/Essentials/config.yml -d essx
sed -i 's/storage-method:.*$/storage-method: yaml/' ${LUCKPERMS_DIR}/config.yml
echo 'min-range: 1500.0' >> ${PLUGIN_DIR}/Essentials/tpr.yml
echo 'max-range: 18020.0' >> ${PLUGIN_DIR}/Essentials/tpr.yml
echo 'center:' >> ${PLUGIN_DIR}/Essentials/tpr.yml
echo '  world: world' >> ${PLUGIN_DIR}/Essentials/tpr.yml
echo '  x: 0.0' >> ${PLUGIN_DIR}/Essentials/tpr.yml
echo '  y: 0.0' >> ${PLUGIN_DIR}/Essentials/tpr.yml
echo '  z: 80.0' >> ${PLUGIN_DIR}/Essentials/tpr.yml
EOM
chmod ugo+x cfg_${MC_WORLD_NAME}_after1strun.sh

# create python function needed by above config script
/bin/cat <<EOM > ./cfg_yaml_2ndLevel.py
#!/usr/bin/python3

import sys, getopt, fileinput, re

YAML_VAL_REGEX_PTRN = r":.*$"   # match colon to end of line
YAML_VAL_RPLCMNT_PTRN = ": {}"   # (restore) colon -space- new value

# dictionary for -d <dict_name> = essx
yaml_dicts = dict()
essx_parent_node_vals = dict()
essx_parent_node_vals['sethome-multiple:'] = {'default:':6, 'vip:':85, 'staff':200}
yaml_dicts['essx'] = essx_parent_node_vals

# better rtp plugin was obsoleted by EssentialsX addition of tpr, but dict remains for example
brtp_prnt_nd_vals = dict()
brtp_prnt_nd_vals['Default:'] = {'MaxRadius:':29000, 'MinRadius:':400}
yaml_dicts['brtp'] = brtp_prnt_nd_vals

def isNodeDictMatchAndSetVal(line, nodedict, ptrn, rplcptrn):
    for nodekey in nodedict:
        if nodekey in line:
            print( re.sub(ptrn, rplcptrn.format(nodedict[nodekey]), line), end="" )
            return True
    return False

def isEndOfParentNodeSect(line):
    if not line or line.isspace(): # TODO: add check for non comment line with indentation equal to or less than parent
        return True
    return False

def findParentKeyMatch(line, pkdict):
    for pkey in pkdict:
        if pkey in line:
            return pkey
    return ''

def parseMainArgs(argv):
    # parse command line args
    YamlFilePath = ''
    YamlDictName = ''
    CORRECT_USAGE_MSG = 'cfg_yaml_2ndLevel.py -i <YamlFilePath> -d <DictName>'
    try:
        opts, args = getopt.getopt(argv, "hi:d:") #h for help, -i <infile>, -d <dict name>
    except getopt.GetoptError:
        print(CORRECT_USAGE_MSG)
        sys.exit(2)
    for opt, arg in opts:
        if opt == '-h':
            print(CORRECT_USAGE_MSG)
            sys.exit()
        elif opt in ("-i"):
            YamlFilePath = arg
        elif opt in ("-d"):
            if arg in yaml_dicts:
                YamlDictName = arg
            else:
                print("unrecognized dictionary name {}".format(arg))
                print("valid dictionary names: {}".format(yaml_dicts.keys()))
                sys.exit()
    print("Processing file {} with {} dictionary".format(YamlFilePath, YamlDictName))
    return (YamlFilePath, YamlDictName)
    

def main(argv):
    YamlFilePath, YamlDictName = parseMainArgs(argv)
    
    foundparentsection = ''
    with fileinput.input(YamlFilePath, inplace=True) as f:
        for line in f:
            if foundparentsection != '':
                if not isNodeDictMatchAndSetVal(line, yaml_dicts[YamlDictName][foundparentsection], YAML_VAL_REGEX_PTRN, YAML_VAL_RPLCMNT_PTRN):
                    if isEndOfParentNodeSect(line):
                        # set foundparentsection if previous section end was due to new parent section
                        foundparentsection = ''
                    print(line, end="")
            else:
                print(line, end="")
                foundparentsection = findParentKeyMatch(line, yaml_dicts[YamlDictName])
                
if __name__ == '__main__':
    main(sys.argv[1:])
EOM

#create accepted eula
echo "eula=true" >> ${MC_DIR}/eula.txt

#create server.properties with the few settings we care about
/bin/cat <<EOM > ${MC_DIR}/server.properties
difficulty=${MC_DIFFICULTY}
pvp=false
level-seed=wholy-${MC_WORLD_NAME}
server-port=${MC_PORT}
query.port=${MC_PORT}
EOM

echo "Server ${MC_WORLD_NAME} setup completed"
