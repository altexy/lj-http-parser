CFLAGS= -O2 -Wall -fPIC -Werror
CC= gcc
LIBS=-lm -lrt
SO_INSTALL_PATH="/usr/lib/"
LUA_DIR=/usr/local
LUA_LIBDIR=$(LUA_DIR)/lib/lua/5.1
LUA_SHAREDIR=$(LUA_DIR)/share/lua/5.1

all: liblj_http_parser.so

http_parser.o: http_parser.c
	$(CC) -c $< -o $@ ${CFLAGS}

lj_http_parser.o: lj_http_parser.c lj_http_parser.h
	$(CC) -c $< -o $@ ${CFLAGS}

liblj_http_parser.so: lj_http_parser.o http_parser.o
	$(CC) -o liblj_http_parser.so lj_http_parser.o http_parser.o ${LIBS} -shared

clean:
	rm -f *.so *.o

install: liblj_http_parser.so
	cp liblj_http_parser.so $(SO_INSTALL_PATH)liblj_http_parser.so

test: liblj_http_parser.so
	luajit test.lua


