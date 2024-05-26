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
cp -Pp /usr/lib64/libssl.so* ${DIST}/install/
cp -Pp /usr/lib64/libcrypto.so* ${DIST}/install/
cp -Pp /usr/lib64/libz.so* ${DIST}/install/
cp -Pp /usr/lib64/libselinux.so* ${DIST}/install/
cp -Pp /usr/lib64/libgssapi_krb5.so* ${DIST}/install/
cp -Pp /usr/lib64/libkrb5.so* ${DIST}/install/
cp -Pp /usr/lib64/libcom_err.so* ${DIST}/install/
cp -Pp /usr/lib64/libk5crypto.so*  ${DIST}/install/
cp -Pp /usr/lib64/libkrb5support.so* ${DIST}/install/
cp -Pp /usr/lib64/libkeyutils.so* ${DIST}/install/
cp -Pp /usr/lib64/libpcre.so* ${DIST}/install/
find ${DIST}/install/ -type f -name "*.so" -exec strip {} \;
rm -f ${DIST}/install/libcrypto.so.1.1*
rm -f ${DIST}/install/libssl.so.1.1*

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

