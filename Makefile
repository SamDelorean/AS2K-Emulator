# AS2K Stable Reduced - local VONTAR X3 / Armbian ARM64
.DEFAULT_GOAL := help
.PHONY: help check-vontar install-vontar
help:
	@printf 'VONTAR: make check-vontar | make install-vontar\n'
check-vontar:
	@sh -n ./install-as2k-vontar.sh
	@sh ./install-as2k-vontar.sh --check
install-vontar:
	@sh ./install-as2k-vontar.sh --install
