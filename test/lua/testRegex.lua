local lrexlib = require("rex_posix")

local str = "/usr/lib/jvm/jre/bin/java -Djavax.sql.DataSource.Factory=org.apache.commons.dbcp.BasicDataSourceFactory -classpath /usr/share/tomcat/bin/bootstrap.jar:/usr/share/tomcat/bin/tomcat-juli.jar: -Dcatalina.base=/usr/share/tomcat -Dcatalina.home=/usr/share/tomcat -Djava.endorsed.dirs= -Djava.io.tmpdir=/var/cache/tomcat/temp -Djava.util.logging.config.file=/usr/share/tomcat/conf/logging.properties -Djava.util.logging.manager=org.apache.juli.ClassLoaderLogManager org.apache.catalina.startup.Bootstrap start"
local pattern = "tomcat.juli.jar"

-- 使用 match 函数
local result = lrexlib.match(str, pattern)
if result then
    print("找到了匹配的子串:", result)
else
    print("没有找到匹配的子串")
end
