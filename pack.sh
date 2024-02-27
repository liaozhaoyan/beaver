DIST=$1/beaver
APP=${DIST}/app

echo $DIST
echo $APP
rm -rf $DIST
mkdir $DIST

mkdir ${DIST}/install
cp /usr/local/lib/libyaml-0.so* ${DIST}/install/
cp /usr/local/lib/libluajit-5.1.so* ${DIST}/install/
cp /usr/local/lib/libyaml.so* ${DIST}/install/
cp /usr/lib64/libssl.so* ${DIST}/install/
cp /usr/lib64/libcrypto.so* ${DIST}/install/
cp /usr/lib64/libgssapi_krb5.so* ${DIST}/install/
cp /usr/lib64/libkrb5.so* ${DIST}/install/
cp /usr/lib64/libcom_err.so* ${DIST}/install/
cp /usr/lib64/libk5crypto.so*  ${DIST}/install/
cp /usr/lib64/libkrb5support.so* ${DIST}/install/
cp /usr/lib64/libkeyutils.so* ${DIST}/install/
cp /usr/lib64/libpcre.so* ${DIST}/install/

mkdir ${DIST}/lib
cp -r /usr/lib64/lua/5.1/* ${DIST}/lib/
cp -r /usr/local/lib/lua/5.1/* ${DIST}/lib/

mkdir ${DIST}/lua
cp -r /usr/share/lua/5.1/* ${DIST}/lua/
cp -r /usr/local/share/lua/5.1/* ${DIST}/lua/

mkdir ${APP}
cp -r lua ${APP}
mkdir ${APP}/main
cp main/main ${APP}/main/
cp main/run_dist.sh ${APP}/main/run.sh
cp main/config.yaml ${APP}/main/

mkdir ${APP}/native
cp native/*.so ${APP}/native

