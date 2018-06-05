
### Defualt config 
blocks-dir = "blocks"
genesis-json = ./genesis.json
chain-state-db-size-mb = 2048
reversible-blocks-db-size-mb = 340
contracts-console = false
access-control-allow-credentials = false
sync-fetch-span = 100
max-implicit-request = 1500

# actor-whitelist =
# actor-blacklist =
# contract-whitelist =
# contract-blacklist =
# filter-on =
# https-client-root-cert =

https-client-validate-peers = 1
http-server-address = 127.0.0.1:__BOOT_HTTP__
p2p-listen-endpoint = 0.0.0.0:__BOOT_P2P__
p2p-server-address = __BOOT_HOST__:__BOOT_P2P__
p2p-max-nodes-per-host = 1
#__BOOT_PEER__
#__P2P_PEER_LIST__

# peer-key =
# peer-private-key =

agent-name = "EOS BOOT NODE"
allowed-connection = any
max-clients = 120
connection-cleanup-period = 30
network-version-match = 1

enable-stale-production = true
#pause-on-startup = false
max-transaction-time = 30
max-irreversible-block-age = -1

# Enable block production with the testnet producers
producer-name = eosio
signature-provider = __PUBKEY__=KEY:__PRIVKEY__
private-key = ["__PUBKEY__","__PRIVKEY__"]
# Appointment Producer
producer-name = appointnodea
producer-name = appointnodeb
producer-name = appointnodec
producer-name = appointnoded
producer-name = appointnodee
producer-name = appointnodef
producer-name = appointnodeg
producer-name = appointnodeh
producer-name = appointnodei
producer-name = appointnodej
producer-name = appointnodek
producer-name = appointnodel
producer-name = appointnodem
producer-name = appointnoden
producer-name = appointnodeo
producer-name = appointnodep
producer-name = appointnodeq
producer-name = appointnoder
producer-name = appointnodes
producer-name = appointnodet
producer-name = appointnodeu

# Wallet config
keosd-provider-timeout = 5
txn-reference-block-lag = 0
wallet-dir = "."
unlock-timeout = 900

# BNET Config
#__BNET_PLUGIN__

# eosio-key =
# plugin =
plugin = eosio::chain_api_plugin
plugin = eosio::history_api_plugin
plugin = eosio::http_plugin
