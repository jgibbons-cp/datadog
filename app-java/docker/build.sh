cd ..

#maven installed
mvn -v > /dev/null
if [ "$?" -ne "0" ]
then
  echo "mvn not installed.... exiting..."
  exit -1
fi

#jdk installed
javac -version > /dev/null
if [ "$?" -ne "0" ]
then
  echo "openjdk not installed.... tested with 11... exiting..."
  exit -1
else
  #tested version
  javac -version | grep 11
  if [ "$?" -ne "0" ]
  then
    echo "openjdk version tested with was 11 just to note..."
  fi
fi

#docker installed and configured
docker > /dev/null
if [ "$?" -ne "0" ]
then
  echo "docker not installed.... exiting..."
  exit -1
else
  docker images > /dev/null
  if [ "$?" -ne "0" ]
  then
    echo "docker daemon running, user in group... exiting..."
    exit -1
  fi
fi

#build war
mvn compile && mvn package

#build app container

if [ ! -f ./dd-java-agent.jar ]; then
    wget -O dd-java-agent.jar https://dtdg.co/latest-java-tracer
fi

docker build -t jgibbons-cp/app-java -f docker/Dockerfile.tomcat .

if [ ! -d "initdb" ]
then
  #create db
  wget -P initdb https://raw.githubusercontent.com/datacharmer/test_db/master/employees.sql && \
  find initdb -type f -name "employees.sql" -print0 | xargs -0 sed -i '' -e 's/source /source \/docker-entrypoint-initdb.d\//g'
  wget -P initdb https://raw.githubusercontent.com/datacharmer/test_db/master/load_departments.dump  && \
  wget -P initdb https://raw.githubusercontent.com/datacharmer/test_db/master/load_employees.dump && \
  wget -P initdb https://raw.githubusercontent.com/datacharmer/test_db/master/load_dept_emp.dump  && \
  wget -P initdb https://raw.githubusercontent.com/datacharmer/test_db/master/load_dept_manager.dump && \
  wget -P initdb https://raw.githubusercontent.com/datacharmer/test_db/master/load_titles.dump && \
  wget -P initdb https://raw.githubusercontent.com/datacharmer/test_db/master/load_salaries1.dump && \
  wget -P initdb https://raw.githubusercontent.com/datacharmer/test_db/master/load_salaries2.dump && \
  wget -P initdb https://raw.githubusercontent.com/datacharmer/test_db/master/load_salaries3.dump && \
  wget -P initdb https://raw.githubusercontent.com/datacharmer/test_db/master/show_elapsed.sql

  #create lab user
  echo "create user 'lab'@'localhost' identified by 'lab';" > initdb/user_lab.sql
  echo "create user 'lab'@'%' identified by 'lab';" >> initdb/user_lab.sql
  echo "grant all on *.* to 'lab'@'localhost';" >> initdb/user_lab.sql
  echo "grant all on *.* to 'lab'@'%';" >> initdb/user_lab.sql
  echo "flush privileges;" >> initdb/user_lab.sql

  #build mysql container with db
  docker build -t jgibbons-cp/mysql -f docker/Dockerfile.mysql .
else
  echo "mysql employees scripts already here.... not building mysql container...\n"
fi

cd -
