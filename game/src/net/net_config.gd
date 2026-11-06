class_name NetConfig
## Where the online relay lives. Empty until relay/worker.js is deployed: the ONLINE option
## then says it isn't set up yet, and Wi-Fi/Bluetooth still work. See relay/README.md.
##   Tests (or a self-hosted relay) can point at another one:  -- --relay-url ws://127.0.0.1:24790

const RELAY_URL := ""

static func relay_url() -> String:
	var args := OS.get_cmdline_user_args()
	var i := args.find("--relay-url")
	if i >= 0 and i + 1 < args.size():
		return args[i + 1]
	return RELAY_URL
