all:
	install -m 755 -D sync.sh $(HOME)/.local/bin/sync.sh

crontab:
	crontab -l | { cat; echo "*/5 * * * * $(HOME)/.local/bin/sync.sh"; } | crontab -
