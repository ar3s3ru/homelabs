MAKEFLAGS    += -s --always-make -C
SHELL        := bash
.SHELLFLAGS  := -Eeuo pipefail -c

# Get the path to this Makefile and directory
MAKEFILE_DIR := $(patsubst %/,%,$(dir $(abspath $(lastword $(MAKEFILE_LIST)))))

SSH_OPTIONS=-o PubkeyAuthentication=no -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no

remote/rsync:
	echo "REMEMBER: have you 'sudo systemctl start sshd' and 'passwd' on the target machine?"
	rsync -av -e 'ssh -p 22' \
		--exclude='.git/' \
		--exclude='.git-crypt/' \
		--exclude='.direnv' \
		--exclude='**/.terraform' \
		$(MAKEFILE_DIR)/ ${or $(user), nixos}@${hostname}:~/homelabs
