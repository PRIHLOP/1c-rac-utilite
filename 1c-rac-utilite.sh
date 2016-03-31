#!/bin/bash

source ./main.conf #connect main.conf file for define variables $DBUSER and $DBPASS
#request for root previlegies(need to reload apache web server when make 1c base web publication)
if [[ $EUID -ne 0 ]]; then
  echo "Запуск требует root прав для управления системными сервисами (apache2 для веб публикации)."
  echo "Подтвердите запрос root прав вводом пароля."
  sudo ls > /dev/null
fi
CL_STRING=$(/opt/1C/v8.3/i386/rac cluster list | grep 'cluster  *')
CLUSTER=${CL_STRING:32}
#Comment variables defined in main.conf
#DBUSER=                           #PostgreSQL database user
#DBPASS=                           #PostgreSQL database password
OPTION=1                          #Default option select to resolve error when script running with empty variable
#function for question with answer Y/N
question() {
  while echo -n "$1 [Y/N] " && read answer || true && ! grep -e '^[YyNn]$' <<< $answer > /dev/null; do echo "Введите N(n) либо Y(y)! "; done
  return $(tr 'YyNn' '0011' <<< $answer)
}
#function to resolve 1c db information
dbuid() {
read -p "Введите имя базы с которой желаете работать, или 0(ноль) для отмены: " DBNAME
DBINFO=$(/opt/1C/v8.3/i386/rac infobase --cluster=$CLUSTER summary list | grep -w -B 1 $DBNAME | grep infobase)
DBUID=${DBINFO:11}
}
echo
#echo -n "Введите логин пользователя 1С с правами администратора: "
#read LOGIN
#echo -n "Введите пароль пользователя 1С: "
#read -s PASSWD
clear
echo
echo
echo "Информация о локальном кластере сервера 1С:"
echo
/opt/1C/v8.3/i386/rac cluster list
#echo "$CLUSTER"
until [ $OPTION -eq 0 ]
do
echo
echo "Выберите для продолжения: "
echo "1) Вывести список БД"
echo "2) Добавить БД"
echo "3) Удалить БД"
echo "4) Выполнить веб публикацию серверной БД"
echo "5) Удалить веб публикацию серверной БД"
echo "6) Вывести список соединений"
echo "7) Вывести список сеансов"
echo "0) Выход"
echo
read -p "Выбранная опция: " OPTION
echo
case "$OPTION" in
   1) clear
/opt/1C/v8.3/i386/rac infobase --cluster=$CLUSTER summary list ;;
   2) clear
read -p "Введите имя создаваемой базы: " DBNAME
/opt/1C/v8.3/i386/rac infobase create --cluster=$CLUSTER --name=$DBNAME --create-database --dbms=PostgreSQL --db-server=127.0.0.1 --db-name=$DBNAME --locale=ru --db-user=$DBUSER --db-pwd=$DBPASS --license-distribution=allow > /dev/null
echo
echo "БД успешно создана";;
   3) clear
dbuid
while [ -z "$DBUID" ]
do
if [ $DBNAME != "0" ]; then
  echo
  echo "БД с таким именем не найдена! Повторите ввод."
  dbuid
fi
done
if [ $DBNAME != "0" ]; then
question "Уверены что хотите удалить БД с именем $DBNAME ?" && /opt/1C/v8.3/i386/rac infobase drop --cluster=$CLUSTER --infobase=$DBUID --drop-database
fi
echo
echo "БД $DBNAME успешно удалена!";;
   4) clear
dbuid
while [ -z "$DBUID" ]
do
if [ $DBNAME != "0" ]; then
  echo
  echo "БД с таким именем не найдена! Повторите ввод."
  dbuid
fi
done
if [ $DBNAME != "0" ]; then
question "Желаете выполнить веб-публикацию базы с именем $DBNAME ?" && echo "/opt/1C/v8.3/i386/webinst -publish -apache22 -wsdir $DBNAME -dir '/var/www/$DBNAME' -connStr 'Srvr="localhost";Ref="$DBNAME";' -confPath /etc/apache2/apache2.conf" | bash
sudo service apache2 reload > /dev/null
fi
echo
echo "Публикация доступна по адресу http://$EXTIP/$DBNAME";;
   5) clear
dbuid
while [ -z "$DBUID" ]
do
if [ $DBNAME != "0" ]; then
  echo
  echo "БД с таким именем не найдена! Повторите ввод."
  dbuid
fi
done
if [ $DBNAME != "0" ]; then
question "Желаете УДАЛИТЬ веб-публикацию базы с именем $DBNAME ?" && echo "/opt/1C/v8.3/i386/webinst -delete -apache22 -wsdir $DBNAME -dir '/var/www/$DBNAME' -connStr 'Srvr="localhost";Ref="$DBNAME";' -confPath /etc/apache2/apache2.conf" | bash
sudo service apache2 reload > /dev/null
fi
echo;;
  6) clear
echo
/opt/1C/v8.3/i386/rac connection --cluster=$CLUSTER list;;
   7) clear
/opt/1C/v8.3/i386/rac session --cluster=$CLUSTER list;;
   0) exit ;;
   *) echo
echo "Неверно выбрана опция.";;

esac
done
exit 0
