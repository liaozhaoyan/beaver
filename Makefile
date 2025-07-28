TARBALL := beaver.tar.gz
ARCH := $(shell uname -m)

ifeq ($(ARCH), x86_64)
    TARGET = target_x86_64
else ifeq ($(ARCH), aarch64)
    TARGET = target_aarch64
else
    $(error Unsupported architecture: $(ARCH))
endif

all:
	echo "build the beaver frame."
	make -C lib
	make -C native
	make -C main

dist: $(TARGET)

pack_common:
	sh pack.sh ./
	rm -f $(TARBALL)
	tar zcv -f $(TARBALL) beaver/
	rm -rf beaver/

target_aarch64: pack_common
	sh update.sh $(TARBALL) 22 10.0.0.236 beaver.devel.$(ARCH).tar.gz

target_x86_64: pack_common
	sh update.sh $(TARBALL) 11000 100.83.167.31 beaver.devel.$(ARCH).tar.gz

clean:
	make -C lib clean
	make -C native clean
	make -C main clean
	rm -f $(TARBALL)
	rm -rf beaver/
