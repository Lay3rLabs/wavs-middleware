# deps
update:; cd contracts && forge update
build  :; cd contracts && forge build
size  :; cd contracts && forge build --sizes

# storage inspection
inspect :; cd contracts && forge inspect ${contract} storage-layout --pretty

# if we want to run only matching tests, set that here
test := test_

# Declare PHONY targets
.PHONY: test update build size inspect trace gas test-contract trace-contract test-test trace-test snapshot snapshot-diff trace-setup trace-max coverage coverage-report coverage-debug clean format format-check coverage-html

# local tests without fork
test :; cd contracts && forge test -vv
trace :; cd contracts && forge test -vvv
gas :; cd contracts && forge test --gas-report
test-contract :; cd contracts && forge test -vv --match-contract $(contract)
test-contract-gas :; cd contracts && forge test --gas-report --match-contract ${contract}
trace-contract :; cd contracts && forge test -vvv --match-contract $(contract)
test-test :; cd contracts && forge test -vv --match-test $(test)
test-test-trace :; cd contracts && forge test -vvv --match-test $(test)
trace-test :; cd contracts && forge test -vvvvv --match-test $(test)
snapshot :; cd contracts && forge snapshot -vv
snapshot-diff :; cd contracts && forge snapshot --diff -vv
trace-setup :; cd contracts && forge test -vvvv
trace-max :; cd contracts && forge test -vvvvv
coverage :; cd contracts && forge coverage
coverage-report :; cd contracts && forge coverage --report lcov
coverage-debug :; cd contracts && forge coverage --report debug

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
