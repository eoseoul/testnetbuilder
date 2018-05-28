### EOS Private Network Tester
[![Englsh](https://img.shields.io/badge/language-English-orange.svg)](README.md) [![Korean](https://img.shields.io/badge/language-Korean-blue.svg)](README_kr.md)

### About
EOS Private Network Tester is designed for developing DAPP or  test the process from EOS Booting to Producing.
You can set Testnet with a simple(?) Setting and configure it to test it.
In case of EOSeoul portal, we used this test script to configure the BP node and setup.

### EOS Source information
* Release : dawn-v4.2.0 release
* OS : Ubuntu 16.04

### Quick Start
```
git clone http://github.com/eoseoul/testnet ./testnet
vi node_setup.conf 
# modify for environment
./node_setup.sh testnet
```

#### Basic Environment
- DATA_DIR : TESTNET directory (current directory)
- SRC_DIR  : EOS Source and Program directory
- KEY_DIR  : The directory where the KEY files will be stored (BP node key file) - Use only for testing.
- BP_PROD  : Json file to make Appointment Node for initial setup
- CUR_SYM  : Set the default symbol to be used in NODEOS. Default is SYS, but it is changed to EOS.

#### EOS Source
- GIT_REPO    : EOS source code is the Git address.
- EOS_RELEASE : Tag of EOS release to checkout.

#### EOS Boot node info
- TESTNET_NAME  : The name of the TESTNET.
- BOOT_HTTP     : HTTP port of the boot node.
- BOOT_P2P      : P2P Port of Boot node.
- BOOT_HOST     : Boot Host information (Defaut : Localhost)

#### Wallet Config
- WALLET_DIR    : Data directory to be used by keosd(wallet daemon)
- WALLET_CONFIG : Directory containing the configuration file to be used by keosd
- WALLET_HOST   : Hostname or domain address of keosd (currently localhost only)
- WALLET_PORT   : Port to be used by keosd (should not overlap nodeos or other Keosd port)

#### Snapshot Migration
- LOAD_SNAPSHOT            : Reads the snapshot file and determines whether to migrate.
- SNAPSHOT_FILE            : path and file name of the snapshot file
- SNAPSHOT_ACCOUNT_PREFIX  : Specifies the prefix of the account to be used in the snapshot migration.
- SNAPSHOT_BREAK           : The boot initialization process takes a long time if there are many accounts in the snapshot file. 
                             Creates accounts with the specified number. If set to 0, all accounts are migrated.

#### Boot node
Work flow
```
a. Make boot directory
b. generate boot node private key & public key
c. deploy config.boot/genesis.boot/run.sh to boot directory
d. default(eosio) wallet create and import private key
e. generate eosio.token/eosio.msig key
f. eosio.bios contract set on boot node
g. eosio.token/eosio.msig wallet create and import private key
h. eosio.token/eosio.msig account create
i. eosio.token/eosio.msig contracct set on boot node
j. Create EOS Token - "10 Billion EOS" Using eosio.token contract
k. Issue(Deploy) EOS Token - "1 Billion EOS" to eosio
l. Appointment node setup - The AP Node must originally elect an ABP node, but since it is a test here, it replaces the Boot node with 21 AP nodes.
 l-1. create account apnode.[a-u] 
 l-2. Set to ABP Node information on EOS Block
m. Set Privilege on eosio/eosio.msig/eosio.token
n. Update eosio.system contract on eosio account 
p. Create ERC-20 migration account and transfer EOS Token from eosio
n. Update eosio/eosio.msig/eosio.token Authority - Skip, its testnet!
```

#### Producer node
PDNAME [_v ++] variable is used for BP node or full node configuration.
The default setting is "BPNAME | HOSTNAME | HTTP_PORT | P2P_PORT | SSL_PORT | Organization | Location | SiteURL | IsBPNODE"
Some values are not used because the release has changed.
This script is used to configure multiple BP nodes in the Localhost environment and to configure the same environment as the test net.

### Scripts
node_setup.sh : Private testnet build script
```
Usage: ./node_setup.sh [ command ]

 [ command ]
  - boot            : deploy boot node for private testnet initialize
  - wallet          : deploy local wallet daemon
  - testnet         : deploy boot node and bp nodes for private testnet
  - addnode         : add node config to node_setup.conf
  - clean           : remove all node directory and config files
  - setenv          : cleos alias script set on profile
  - unsetenv        : cleos alias script unset on profile

  # setenv/unsetenv option is not currently used.

```

node_ctrl.sh : script that can start / stop multiple nodes configured with Testnet or one specified node
```
Usage : ./node_ctrl.sh [start|stop] {NodeName}
```

cle.sh : A script that allows you to select one of several nodes configured with Testnet and execute the cleos command
```
Usage : ./cle.sh 
Ex)
eos@mrmsm:~/testnet$ ./cle.sh
################################
  0 : applecookies (Port: 8801)
  1 : monkeybanana (Port: 8802)
################################
 SELECT Node number : : 1

==============================================
   If you want to exit then Press CTRL + C
   - HOST : localhost
   - PORT : 8802
==============================================
Neo EOS> get info
{
  "server_version": "9be89106",
  "head_block_num": 279,
  "last_irreversible_block_num": 279,
  "last_irreversible_block_id": "0000011760740b8c7198616a68fc6aaf4a9ab446afea085e035d0858dd11462e",
  "head_block_id": "0000011760740b8c7198616a68fc6aaf4a9ab446afea085e035d0858dd11462e",
  "head_block_time": "2018-05-18T10:20:56",
  "head_block_producer": "eosio",
  "virtual_block_cpu_limit": 131909,
  "virtual_block_net_limit": 1384664,
  "block_cpu_limit": 99900,
  "block_net_limit": 1048576
}

```
```
#### How to use 
- Testnet Setup : node_setup.sh testnet
- Testnet Reset : node_setup.sh clean
- Add testnet node config : node_setup.sh addconfig
- setup boot node only : node_setup.sh boot
- Execute commands on each node of the testnet : ./cle.sh  or  ./td_node_BPNAME/cleos.sh 
- Testnet BP Register : td_node_BPNAME/regproducer.sh (First Producer registers 200 million - To generate more than 15% of transactions)
- BP Node initialize : td_node_BPNAME/run.sh init (only first run!)
- BP Node resync : Remove td_node_BPNAME/blocks, state directory and run command td_node_BPNAME/run.sh init
```
