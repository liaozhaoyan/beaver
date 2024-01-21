all:
	echo "build the beaver frame."
	make -C lib
	make -C native
	make -C main

rm:
	rm -rf dist/

dist:
	sh pack.sh ./
	tar zcv -f dist.tar.gz dist/

clean:
	make -C lib clean
	make -C native clean
	make -C main clean
