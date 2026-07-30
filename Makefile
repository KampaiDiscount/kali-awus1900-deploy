.PHONY: check package install-gh publish-public publish-private

check:
	bash ./tests/static.sh

package:
	./scripts/package-release.sh

install-gh:
	./scripts/install-github-cli.sh

publish-public:
	./publish-to-github.sh public

publish-private:
	./publish-to-github.sh private
