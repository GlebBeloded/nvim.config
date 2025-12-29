.PHONY: install lint fmt

install:
	brew install selene stylua

lint:
	selene lua/

fmt:
	stylua lua/ init.lua
