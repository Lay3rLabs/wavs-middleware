# deps
update:; cd contracts && forge update
build-bls:; cd contracts && FOUNDRY_PROFILE=bls forge build
build-ecdsa:; cd contracts && FOUNDRY_PROFILE=ecdsa forge build
build: build-bls build-ecdsa
size-bls:; cd contracts && FOUNDRY_PROFILE=bls forge build --sizes
size-ecdsa:; cd contracts && FOUNDRY_PROFILE=ecdsa forge build --sizes
size: size-bls size-ecdsa

# storage inspection
inspect-bls :; cd contracts && FOUNDRY_PROFILE=bls forge inspect ${contract} storage-layout --pretty
inspect-ecdsa :; cd contracts && FOUNDRY_PROFILE=ecdsa forge inspect ${contract} storage-layout --pretty
inspect: inspect-bls inspect-ecdsa

# if we want to run only matching tests, set that here
test := test_

# Declare PHONY targets
.PHONY: test update build size inspect trace gas test-contract trace-contract test-test trace-test snapshot snapshot-diff trace-setup trace-max coverage coverage-report coverage-debug clean format format-check coverage-html

# local tests without fork

test-bls :; cd contracts && FOUNDRY_PROFILE=bls forge test -vv
test-ecdsa :; cd contracts && FOUNDRY_PROFILE=ecdsa forge test -vv
test : test-bls test-ecdsa

gas-bls :; cd contracts && FOUNDRY_PROFILE=bls forge test --gas-report
gas-ecdsa :; cd contracts && FOUNDRY_PROFILE=ecdsa forge test --gas-report
gas : gas-bls gas-ecdsa

snapshot-bls :; cd contracts && FOUNDRY_PROFILE=bls forge snapshot -vv
snapshot-ecdsa :; cd contracts && FOUNDRY_PROFILE=ecdsa forge snapshot -vv
snapshot : snapshot-bls snapshot-ecdsa

coverage-bls :; cd contracts && FOUNDRY_PROFILE=bls forge coverage
coverage-ecdsa :; cd contracts && FOUNDRY_PROFILE=ecdsa forge coverage
coverage : coverage-bls coverage-ecdsa
coverage-report-bls :; cd contracts && FOUNDRY_PROFILE=bls forge coverage --report lcov
coverage-report-ecdsa :; cd contracts && FOUNDRY_PROFILE=ecdsa forge coverage --report lcov
coverage-report : coverage-report-bls coverage-report-ecdsa

clean :; cd contracts && forge clean
format :; cd contracts && forge fmt
format-check :; cd contracts && forge fmt --check

coverage-html:
	@echo "Running coverage..."
	cd contracts && forge build;\
	forge coverage --report lcov
	@echo "Analyzing..."
	lcov --remove lcov.info 'script/*' --output-file lcov.info; \
	genhtml -o coverage-report lcov.info;
	@echo "Coverage report generated at coverage-report/index.html"
