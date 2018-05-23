# Track only transactions whose scopes involve the listed accounts. Default is to track all transactions.
# filter_on_accounts =

# Limits the maximum time (in milliseconds) processing a single get_transactions call.
get-transactions-time-limit = 3

# File to read Genesis State from
genesis-json = genesis.json

# override the initial timestamp in the Genesis State file
# genesis-timestamp =

# the location of the block log (absolute path or relative to application data dir)
block-log-dir = "blocks"

# Pairs of [BLOCK_NUM,BLOCK_ID] that should be enforced as checkpoints.
# checkpoint =

# the location of the chain shared memory files (absolute path or relative to application data dir)
shared-file-dir = "blockchain"

# Minimum size MB of database shared memory file
shared-file-size = 8192

# The local IP and port to listen for incoming http connections.
http-server-address = 0.0.0.0:__BOOT_HTTP__

# Specify the Access-Control-Allow-Origin to be returned on each request.
access-control-allow-origin = *

# Specify the Access-Control-Allow-Headers to be returned on each request.
# access-control-allow-headers =

# Specify if Access-Control-Allow-Credentials: true should be returned on each request.
access-control-allow-credentials = false

# The actual host:port used to listen for incoming p2p connections.
p2p-listen-endpoint = 0.0.0.0:__BOOT_P2P__

# An externally accessible host:port for identifying this node. Defaults to p2p-listen-endpoint.
p2p-server-address = __BOOT_HOST__:__BOOT_P2P__

# The public endpoint of a peer node to connect to. Use multiple p2p-peer-address options as needed to compose a network.
p2p-peer-address = __BOOT_HOST__:__BOOT_P2P__

# The name supplied to identify this node amongst the peers.
agent-name = "EOS BOOT NODE"

# True to always send full blocks, false to send block summaries
send-whole-blocks = 1

# Can be 'any' or 'producers' or 'specified' or 'none'. If 'specified', peer-key must be specified at least once. If only 'producers', peer-key is not required. 'producers' and 'specified' may be combined.
allowed-connection = any

# Optional public key of peer allowed to connect.  May be used multiple times.
# peer-key =

# Tuple of [PublicKey, WIF private key] (may specify multiple times)
# peer-private-key =
# Log level: one of 'all', 'debug', 'info', 'warn', 'error', or 'off'
log-level-net-plugin = info

# Maximum number of clients from which connections are accepted, use 0 for no limit
max-clients = 30

# number of seconds to wait before cleaning up dead connections
connection-cleanup-period = 30

# True to require exact match of peer network version.
network-version-match = 1

# Enable block production, even if the chain is stale.
enable-stale-production = true

# Percent of producers (0-100) that must be participating in order to produce blocks 
required-participation = 0

# ID of producer controlled by this node (e.g. inita; may specify multiple times)
producer-name = eosio

# Appointment Producer Node name
producer-name = apnode.a
producer-name = apnode.b
producer-name = apnode.c
producer-name = apnode.d
producer-name = apnode.e
producer-name = apnode.f
producer-name = apnode.g
producer-name = apnode.h
producer-name = apnode.i
producer-name = apnode.j
producer-name = apnode.k
producer-name = apnode.l
producer-name = apnode.m
producer-name = apnode.n
producer-name = apnode.o
producer-name = apnode.p
producer-name = apnode.q
producer-name = apnode.r
producer-name = apnode.s
producer-name = apnode.t
producer-name = apnode.u

# Plugin(s) to enable, may be specified multiple times
# plugin =
# Plugin(s) to enable, may be specified multiple times
plugin = eosio::producer_plugin
plugin = eosio::chain_api_plugin
#plugin = eosio::wallet_api_plugin
plugin = eosio::history_plugin
plugin = eosio::http_plugin
plugin = eosio::history_api_plugin
# plugin = eosio::mongo_db_plugin

# Enable block production with the testnet producers
# Tuple of [public key, WIF private key] (may specify multiple times)
private-key=["__PUBKEY__","__PRIVKEY__"]
