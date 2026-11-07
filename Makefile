SHELL := /bin/bash
.SHELLFLAGS := -eu -o pipefail -c

# Prefer the project virtualenv so the scripts see the same PyYAML as Ansible.
PYTHON ?= $(shell if [ -x .venv/bin/python ]; then echo .venv/bin/python; else echo python3; fi)

.PHONY: check checksums update-checksums drift vm-up vm-verify vm-idempotence vm-test

check:
	ci/check.sh

checksums:
	$(PYTHON) ci/verify-checksums.py

update-checksums:
	$(PYTHON) ci/verify-checksums.py --update

drift:
	$(PYTHON) ci/verify-checksums.py
	$(PYTHON) ci/check-box-updates.py --markdown --fail-on-updates

vm-up:
	vagrant up --provider=libvirt

vm-verify:
	vagrant ssh -c 'bash /vagrant/ci/verify-vm.sh'

vm-idempotence:
	vagrant provision 2>&1 | tee /tmp/ansible-drp-provision.log
	ci/assert-recap.sh /tmp/ansible-drp-provision.log 0

vm-test: vm-up vm-verify vm-idempotence
