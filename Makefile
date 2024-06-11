.PHONY: build 3rd skynet clean

all: help

help:
	@echo "支持下面命令："
	@echo "  make build   # 编译项目"
	@echo "  make clean   # 清理 "
	@echo "  make server  # 启动服务端"
	@echo "  make client  # 启动客户端"
	@echo "  make console # 启动控制台"
	@echo "  make pb 	  # 生成pb"

LOG_PATH ?= log
LUA_CLIB_PATH ?= luaclib
LUA_INCLUDE_DIR ?= skynet/3rd/lua

build: 3rd skynet
	mkdir $(LOG_PATH) 

3rd: 
	git submodule update --init
	cd 3rd/lua-cjson && $(MAKE) install LUA_INCLUDE_DIR=../../$(LUA_INCLUDE_DIR) DESTDIR=../.. LUA_CMODULE_DIR=./$(LUA_CLIB_PATH) CC='$(CC) -std=gnu99'

skynet:
	git submodule update --init
	cd skynet && $(MAKE) linux 

server:
	@./skynet/skynet etc/config

client:
	@./skynet/skynet etc/config.client

console:
	@telnet 127.0.0.1 4040

pb: proto/login.pb proto/room.pb proto/table.pb proto/msg.pb

clean:
	rm -f $(LOG_PATH)/*
	rm -f $(LUA_CLIB_PATH)/*.so
	rm proto/*.pb