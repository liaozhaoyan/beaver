export LD_LIBRARY_PATH="../native;"

DIR=$( cd "$(dirname "${BASH_SOURCE[0]}")" && pwd);
echo $DIR
cd $DIR

export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:../../install/:../native/

export LUA_PATH="../../lua/?.lua;../../lua/?/init.lua;../lua/?.lua;../lua/?/init.lua;"
export LUA_CPATH="../../lib/?.so;../../lib/loadall.so;./?.so;"

./main