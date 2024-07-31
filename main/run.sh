export LD_LIBRARY_PATH="../native;/usr/local/lib/;/usr/local/share/lua/5.1/"

export LUA_PATH="/usr/share/lua/5.1/?.lua;/usr/share/lua/5.1/?/init.lua;../lua/?.lua;"
export LUA_CPATH="/usr/lib64/lua/5.1/?.so;/usr/local/lib/lua/5.1/?.so;"

# valgrind --leak-check=full --show-leak-kinds=all --log-file=valgrind.log ./main
# valgrind --leak-check=full --show-leak-kinds=definite --log-file=valgrind.log ./main
./main