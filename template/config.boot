# Default config
genesis-json = ./genesis.json
blocks-dir = "blocks"
chain-state-db-size-mb = 8192
wasm-runtime=binaryen
access-control-allow-origin = *
access-control-allow-credentials = false
reversible-blocks-db-size-mb=4096
contracts-console=true
send-whole-blocks = 1
allowed-connection = any
log-level-net-plugin = info
max-clients = 35
connection-cleanup-period = 30
network-version-match = 0
enable-stale-production = true
required-participation = 33
# peer-key =
# peer-private-key =

# Connection config
http-server-address = 0.0.0.0:__BOOT_HTTP__
p2p-listen-endpoint = 0.0.0.0:__BOOT_P2P__
p2p-server-address = __BOOT_HOST__:__BOOT_P2P__
agent-name = "EOS Boot Node"

#__BOOT_PEER__
#__P2P_PEER_LIST__

# Enable block production with the testnet producers
producer-name = eosio
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

private-key = ["__PUBKEY__","__PRIVKEY__"]
# Plugin(s) to enable, may be specified multiple times
plugin = eosio::producer_plugin
plugin = eosio::chain_api_plugin
plugin = eosio::http_plugin

