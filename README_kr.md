### EOS Private Network Tester
[![Englsh](https://img.shields.io/badge/language-English-orange.svg)](README.md) [![Korean](https://img.shields.io/badge/language-Korean-blue.svg)](README_kr.md)

### About
EOS Private Network Tester는 DAPP을 개발하는 개발자, EOS Booting부터 Producing 까지의 과정을 테스트 하려는 분들을 위해 만들었습니다. 
간단한(?) 설정을 통해 Testnet을 구성하고 이를 테스트 할 수 있도록 구성되었습니다. 
실제 EOSeoul의 Portal의 경우 이 테스트 스크립트를 이용하여 Booting하고 BP 노드를 구성하여 사용 하고 있습니다. 

### Announce
[dawn-v4.2.0]: https://github.com/EOSIO/eos/releases "DAWN-4.2.0" 릴리즈가 발표되었습니다.
Nodeos 실행에 대한 부분과 관련하여 변경된 내용이 있으므로, 꼭 릴리즈 업데이트 내용을 확인하여 주시기 바랍니다. 

### EOS Source information
* Release : dawn-v4.1.1 release
* OS : Ubuntu 16.04

### Quick Start
```
git clone http://github.com/eoseoul/testnet ./testnet
vi node_setup.conf 
# 각 환경에 맞게 수정
./node_setup.sh testnet
```

#### 기본 설정
- DATA_DIR : TESTNET 디렉토리 (현재 디렉토리)
- SRC_DIR : EOS Source 및 Program 디렉토리
- KEY_DIR : KEY파일들이 저장될 디렉토리 (BP node key 파일) - 테스트시에만 사용하시고 외부로 오픈되는 환경에서는 반드시 백업 후 삭제하세요. 
- BP_PROD : Appointment Node를 초기 셋팅기 위해 만드는 Json 파일
- CUR_SYM : NODEOS에서 사용할 기본 심볼을 설정하며 Default는 SYS이지만 EOS로 변경해서 사용합니다.

#### Wallet 설정
- WALLET_DIR : keosd(wallet daemon)이 사용할 데이터 디렉토리
- WALLET_CONFIG : keosd(wallet daemon)에서 사용할 설정 파일이 있는 디렉토리 
- WALLET_HOST : keosd(wallet daemon)의 Hostname 또는 도메인 주소(현재는 localhost만 사용가능)
- WALLET_PORT : keosd(wallet daemon)이 사용할 포트 (nodeos 데몬 또는 다른 Keosd  포트와 겹치면 안됩니다.)

#### Snapshot 설정
- LOAD_SNAPSHOT : 지정된 ERC-20 Snapshot 파일을 읽어서 초기 설정을 할 것인지 결정한다. 
- SNAPSHOT_FILE : ERC-20 Snapshot 파일의 경로와 파일명을 명시한다. 
- SNAPSHOT_ACCOUNT_PREFIX : Snapshot Migration에서 사용할 초기 계정들의 Prefix를 지정한다. 
- SNAPSHOT_BREAK : Snapshot 파일의 Account가 많을 경우 Boot initialize과정에 시간이 많이 소요되므로 적당한 숫자를 지정하여 중단 한다. 0으로 설정하면 모든 계정을 Migration 한다. 

#### Boot node
Work flow
```
a. Boot 디렉토리 생성
b. Boot node의 Public/Private Key 생성
c. config.ini/genesis.json/run.sh 생성
d. default(eosio) Wallet 생성 및 Private key 등록
e. eosio.token/eosio.msig 키 생성
f. boot node에 eosio.bios 컨트랙트 등록
g. eosio.token/eosio.msig 계정 wallet 생성 및 키 등록
h. eosio.token/eosio.msig 계정 생성
i. boot node에 eosio.token/eosio.msig 컨트랙트 등록
j. eosio.token 컨트랙트를 이용하여 100억개 토큰 생성(인플레이션 증가분 감안하여 100억개 생성함)
k. eosio 계정에 10억개 토큰 발행(EOS 기존 토큰량만큼)
l. Appointment node 셋팅 - 원래는 ABP 노드를 BPc중 선출하여 셋팅하지만, 테스트넷이므로 Bootnode가 21개 ABP 역활을 대신 하도록 구성
 l-1. apnode.[a-u] 계정 생성
 l-2. Setprod Action으로 ABP 21개 노드의 Publickey를 BP로 등록
 (이 과정은 차후 eos.go의 협의 내용에 따라 달라질 수 있습니다.)
m. eosio/eosio.msig/eosio.token 계정이 staking된 자원 없이 프로세싱 할 수 있도록 privilege 권한 설정
n. eosio.system 컨트랙트를 eosio에 업데이트 
o. Snapshot 된 계정들을 생성 한 후 기존 보유 TOKEN 개수만큼 eosio 계정이 transfer 처리 
p. eosio/eosio.msig/eosio.token 계정의 Public Key를 Update Authority를 통해 삭제(eosio 계정을 임의로 사용하지 못하도록)
   - 테스트 넷이기 때문이 이 작업은 제외 하였습니다. (차후 계정 생성 테스트나 Contract 테스트 하는데 eosio 계정이 필요 하기 때문)
```

#### Producer node
-  PDNAME[_v++] 변수에 저징된 값은 BP 노드 또는 Full Node 구성시 사용된다. 
기본 설정은 "BPNAME|HOSTNAME|HTTP_PORT|P2P_PORT|SSL_PORT|Organisation|Location|SiteURL|IsBPNODE" 값으로 구성되며 TESTNET 환경이 지속적으로 변경됨에 따라 필요 없는 값도 존재한다. 
이 스크립트는 Localhost 환경에 여러개의 BP Node를 띄워 테스트넷과 같은 환경구성을 위해 사용되므로 모두 Localhost로 지정하고 포트정도만 수정하면 된다. 

### Scripts
node_setup.sh : Private testnet 환경을 구성해주는 스크립트
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
```

node_ctrl.sh : Testnet으로 구성된 여러개의 노드 또는 지정된 하나의 노드를 시작/중지하거나 할 수 있는 스크립트
```
Usage : ./node_ctrl.sh [start|stop] {NodeName}
```

cle.sh : Testnet으로 구성된 여러개의 노드를 선택 한 후 cleos 명령을 실행 할 수 있는 스크립트
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
### input cleos subcommand
```
#### How to use 
- 테스트넷 구성 : node_setup.sh testnet
- 테스트넷 삭제 : node_setup.sh clean
- 네스트넷 노드 설정 추가 : node_setup.sh addconfig
- 테스트넷 boot 노드만 실행 : node_setup.sh boot
- 테스트넷의 각 노드들에 명령어 실행 : ./cle.sh 또는 td_node_BPNAME/cleos.sh 실행
- 테스트넷 BP Node 실행 후 Producer 등록 : td_node_BPNAME/regproducer.sh (첫번째 Producer는 2억개를 등록함 - 15% 이상 Transaction 발생 위해)
- 테스트넷 BP Node 초기화 : td_node_BPNAME/run.sh init (첫 실행시에만 사용합니다.)
- 테스트넷 BP Node 리셋 : td_node_BPNAME/blocks, state 디렉토리 삭제 후 td_node_BPNAME/run.sh init 명령을 실행 합니다. 
```

### Trouble Shooting
1. boot node 셋팅중 contract 셋팅에서 실패가 발생하는 경우 eos_source/build 디렉토리에서 sudo make install 하셔서 관련 라이브러리 파일의 재배포를 해주셔야 합니다. 
처음부터 make install을 통해 라이브러리를 배포하지 않으셨다면 아무런 문제가 없어야 합니다. 

2. 테스트 도중 일부 노드가 Fork된 경우 각 노드의 디렉토리에서 ./start.sh --resync-blockchain 또는 --replay-blockchain 명령을 통해 재동기화 하시면 정상화 됩니다. 만약 Dan Larimer가 테스트 하고 있는 Beast P2P 프로토콜이 반영된다면 --hard-replay를 통해 동기화 하게 될 것 입니다.
