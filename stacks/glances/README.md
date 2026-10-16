# glances

Glances web UI behind PocketID (`secured-auth`). It reads containers through the socket proxy.

Port 61208 is also published on `127.0.0.1` only. Home Assistant runs on the host network and its Glances integration cannot log in through PocketID, so it reads the loopback port instead.
