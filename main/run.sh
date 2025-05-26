export LD_LIBRARY_PATH=../native:/usr/local/lib/:/usr/local/share/lua/5.1/:$LD_LIBRARY_PATH

export LUA_PATH="/usr/share/lua/5.1/?.lua;/usr/share/lua/5.1/?/init.lua;/usr/local/share/lua/5.1/?/init.lua;/usr/local/share/lua/5.1/?.lua;../lua/?.lua;"
export LUA_CPATH="/usr/lib64/lua/5.1/?.so;/usr/local/lib/lua/5.1/?.so;"

# valgrind --leak-check=full --show-leak-kinds=all --log-file=valgrind.log ./main
# valgrind --leak-check=full --show-leak-kinds=definite --log-file=valgrind.log ./main
arg=${1:-"config.yaml"}
./main $arg