install:
	install -m 755 -D sync.sh $(HOME)/.local/bin/sync.sh
	install -m 755 -d $(HOME)/.local/log/rsync-backup
	install -m 755 -d $(HOME)/.config/rsync-backup

config:
	$(EDITOR) $(HOME)/.config/rsync-backup/config

init:
	$(HOME)/.local/bin/sync.sh init

enable:
	crontab -l | { cat; echo "*/5 * * * * $(HOME)/.local/bin/sync.sh"; } | crontab -

disable:
	crontab -l | grep -v "$(HOME)/.local/bin/sync.sh" | crontab -
