all:
	echo "build the beaver frame."
	make -C lib
	make -C native
	make -C main

dist:
	sh pack.sh ./
	rm -f beaver.tar.gz
	tar zcv -f beaver.tar.gz beaver/
	rm -rf beaver/
	scp beaver.tar.gz root@172.16.0.119:/root/oss/group/beaver.devel.tar.gz

clean:
	make -C lib clean
	make -C native clean
	make -C main clean
	rm -f beaver.tar.gz
	rm -rf beaver/
