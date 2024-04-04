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

clean:
	make -C lib clean
	make -C native clean
	make -C main clean
	rm -f beaver.tar.gz
	rm -rf beaver/
