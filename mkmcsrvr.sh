#!/bin/bash

MC_WORLD_NAME=${1:-Hector}
VANILLA_VERSION="1.17.1"
MC_DIR="${HOME}/mc/${MC_WORLD_NAME}"
PLUGIN_DIR="${MC_DIR}/plugins"
LOCAL_PLUGIN_REPO="${HOME}/mc/mcpluginrepo"

# create directory and download latest paper server
mkdir -p ${MC_DIR}
wget https://papermc.io/api/v1/paper/${VANILLA_VERSION}/latest/download -O ${MC_DIR}/paperclip.jar
# wget https://papermc.io/ci/job/Paper-${VANILLA_VERSION}/lastSuccessfulBuild/artifact/paperclip.jar -O ${MC_DIR}/paperclip.jar

# create plugins directory
mkdir ${PLUGIN_DIR}

# Plugin:  Protocollib
# not currently configured

# Plugin:  EssentialsX
curl -s https://api.github.com/repos/EssentialsX/Essentials/releases/latest | grep browser_download_url | cut -d '"' -f 4 | wget -i - -P ${PLUGIN_DIR}

# wget https://papermc.io/ci/view/%20%20Plugins/job/EssentialsX/lastSuccessfulBuild/artifact/*zip*/archive.zip -O ${PLUGIN_DIR}/EssX.zip
# unzip -j ${PLUGIN_DIR}/EssX.zip -d ${PLUGIN_DIR}
# rm ${PLUGIN_DIR}/EssX.zip
rm ${PLUGIN_DIR}/EssentialsXXMPP*.jar
rm ${PLUGIN_DIR}/EssentialsXGeo*.jar
rm ${PLUGIN_DIR}/EssentialsXAntiBuild*.jar

# Plugin:  Vault  :  redirect URL to get latest
curl -s https://api.github.com/repos/MilkBowl/Vault/releases/latest | grep browser_download_url | cut -d '"' -f 4 | wget -i - -P ${PLUGIN_DIR}
# https://www.spigotmc.org/resources/vault.34315/download?version=344916

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
rm ${PLUGIN_DIR}/LuckPerms*Bungee*.jar
rm ${PLUGIN_DIR}/LuckPerms*Velocity*.jar
rm ${PLUGIN_DIR}/LuckPerms*Nukkit*.jar
rm ${PLUGIN_DIR}/LuckPerms*Legacy*.jar
rm ${PLUGIN_DIR}/LuckPerms*Sponge*.jar
rm ${PLUGIN_DIR}/LuckPerms*Fabric*.jar

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

# create launch script
/bin/cat <<EOM > ./run_${MC_WORLD_NAME}.sh
#!/bin/bash
# if not already running in screen, start screen first
if [ -z "\$STY" ]; then exec screen -dm -S minecraftsrvr /bin/bash "\$0"; fi
cd ${MC_DIR}
java -Xmx3G -Xms3G -jar paperclip.jar nogui
#java -Xmx1024M -Xms1024M -jar paperclip.jar nogui
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
essx_parent_node_vals['sethome-multiple:'] = {'default:':6, 'vip:':15, 'staff':30}
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
difficulty=normal
pvp=false
level-seed=wholy-${MC_WORLD_NAME}
EOM

echo "Server ${MC_WORLD_NAME} setup completed"
