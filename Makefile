.PHONY: check package

check:
	bash ./tests/static.sh

package:
	./scripts/package-release.sh
