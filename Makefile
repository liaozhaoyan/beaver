all:
	echo "build the beaver frame."
	make -C lib
	make -C native
	make -C main

rm:
	rm -rf beaver/

dist:
	sh pack.sh ./
	tar zcv -f beaver.tar.gz beaver/

clean:
	make -C lib clean
	make -C native clean
	make -C main clean
