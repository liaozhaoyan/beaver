DIST=$1/beaver
APP=${DIST}/app

echo $DIST
echo $APP
rm -rf $DIST
mkdir $DIST

mkdir ${DIST}/install
cp -Pp /usr/local/lib/libluajit-5.1.so* ${DIST}/install/
cp -Pp /usr/local/lib/libyaml-* ${DIST}/install/
cp -Pp /usr/local/lib/libyaml.so* ${DIST}/install/
cp -Pp /usr/lib64/libz.so* ${DIST}/install/
cp -Pp /usr/lib64/libtcmalloc.so ${DIST}/install/
cp -Pp /usr/lib64/libtcmalloc_minimal.so.* ${DIST}/install/

cd ${DIST}/install
find ./ -type f -name "*.so" -exec strip {} \;
cd -

mkdir ${DIST}/lib
cp -r /usr/lib64/lua/5.1/* ${DIST}/lib/
cp -r /usr/local/lib/lua/5.1/* ${DIST}/lib/
find ${DIST}/lib/ -type f -name "*.so" -exec strip {} \;
rm -rf ${DIST}/lib/luarocks

mkdir ${DIST}/lua
cp -r /usr/share/lua/5.1/* ${DIST}/lua/
cp -r /usr/local/share/lua/5.1/* ${DIST}/lua/
rm -rf ${DIST}/lua/luarocks

mkdir ${APP}
cp -r lua ${APP}
rm -f ${APP}/lua/app/*
cp lua/app/hello.lua ${APP}/lua/app/
mkdir ${APP}/main
cp main/main ${APP}/main/
cp main/run_dist.sh ${APP}/main/run.sh
cp main/sample.yaml ${APP}/main/config.yaml

mkdir ${APP}/native
cp native/*.so ${APP}/native

