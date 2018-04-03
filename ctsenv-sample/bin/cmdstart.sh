#! /bin/sh


# Source function library.
. /etc/init.d/functions

# Check that networking is up.
. /etc/sysconfig/network

if [ -f ../.env ]; then
      . ../.env
elif [ -f .env ];then
      . ./.env
fi

PWD=`pwd`
if [ "$WORKPATH" = "${PWD%/bin}" ]; then
	cd $WORKPATH
else
	echo -e "\nplases set .env file\n"
	exit 1

fi

ITEM=`basename $WORKPATH`
echo -e "\nItme:\t$ITEM\nEnv:\t`pwd` \n"



if [ "$NETWORKING" = "no" ]
then
	exit 0
fi

RETVAL=0

prog=$ITEM
phpfpm_pidfile=run/php-fpm.pid
phpfpm_lockfile=run/lock/php-fpm
nginx=${NGINX-/opt/cstenv/sbin/nginx}
phpfpm=${PHPFPM-/opt/cstenv/sbin/php-fpm}
nginx_conffile=etc/nginx.conf
nginx_lockfile=run/lock/nginx
nginx_pidfile=run/nginx.pid
SLEEPMSEC=${SLEEPMSEC-200000}
UPGRADEWAITLOOPS=${UPGRADEWAITLOOPS-5}

nginx_start() {
    echo -n $"[webserver] Starting $prog: "

    daemon --pidfile=${nginx_pidfile} ${nginx} -p $WORKPATH -c ${nginx_conffile}
    RETVAL=$?
    echo
    [ $RETVAL = 0 ] && touch ${nginx_lockfile}
    return $RETVAL
}

nginx_stop() {
    echo -n $"[webserver] Stopping $prog: "
    killproc -p ${nginx_pidfile} ${nginx}
    RETVAL=$?
    echo
    if [ $RETVAL -eq 0 ] ; then
    	rm -f ${nginx_lockfile} ${nginx_pidfile}
    fi
}

nginx_reload() {
    echo -n $"[webserver] Reloading $prog: "
    killproc -p ${nginx_pidfile} ${nginx} -HUP
    RETVAL=$?
    echo
}

nginx_upgrade() {
    nginx_oldbinpidfile=${nginx_pidfile}.oldbin

    nginx_configtest -q || return
    echo -n $"Starting new master $prog: "
    killproc -p ${nginx_pidfile} ${nginx} -USR2
    echo

    for i in `/usr/bin/seq $UPGRADEWAITLOOPS`; do
        /bin/usleep $SLEEPMSEC
        if [ -f ${nginx_oldbinpidfile} -a -f ${pidfile} ]; then
            echo -n $"Graceful shutdown of old $prog: "
            killproc -p ${nginx_oldbinpidfile} ${prog} -QUIT
            RETVAL=$?
            echo
            return
        fi
    done

    echo $"Upgrade failed!"
    RETVAL=1
}

nginx_configtest() {

    if [ "$#" -ne 0 ] ; then
        case "$1" in
            -q)
                FLAG=$1
                ;;
            *)
                ;;
        esac
        shift
    fi

    ${nginx} -p $WORKPATH -t -c ${nginx_conffile} 
    RETVAL=$?
    return $RETVAL

}




phpfpm_start () {
	echo -n $"[cgimanage] Starting $prog: "
	dir=$(dirname ${phpfpm_pidfile})
	[ -d $dir ] || mkdir $dir
	daemon --pidfile ${phpfpm_pidfile} ${phpfpm} -p $WORKPATH  --daemonize
	RETVAL=$?
	echo
	[ $RETVAL -eq 0 ] && touch ${phpfpm_lockfile}
}
phpfpm_stop () {
	echo -n $"[cgimanage] Stopping $prog: "
	killproc -p ${phpfpm_pidfile} ${phpfpm}
	RETVAL=$?
	echo
	if [ $RETVAL -eq 0 ] ; then
		rm -f ${phpfpm_lockfile} ${phpfpm_pidfile}
	fi
}

phpfpm_restart () {
       phpfpm_stop
       phpfpm_start
}

phpfpm_reload () {
	echo -n $"[cgimanage] Reloading $prog: "
	if ! ${phpfpm} -p $WORKPATH --test ; then
	        RETVAL=6
	        echo $"not reloading due to configuration syntax error"
	        failure $"not reloading $prog due to configuration syntax error"
	else
		killproc -p ${phpfpm_pidfile} ${phpfpm} -USR2
		RETVAL=$?
	fi
	echo
}

phpfpm_configtest() {
    ${phpfpm} -p $WORKPATH --test
    RETVAL=$?
    return $RETVAL
}

echover() {
 
 echo -n "[$1] "

}



# See how we were called.


case "$1" in

    all)
        case "$2" in
           stop)
                nginx_stop 
                phpfpm_stop
                ;;

           start)
                nginx_start || exit $RETVAL
                phpfpm_start
		;;

	 restart)
		nginx_configtest  || exit $RETVAL
		phpfpm_configtest || exit $RETVAL
		nginx_stop

	        phpfpm_stop
		phpfpm_start
		nginx_start
		;;

	 reload)
		
		phpfpm_reload
		nginx_reload
		;;

	 status)
		echover "webserver"
		status -p ${nginx_pidfile}  $ITEM
		echover "cgimanage"
		status -p ${phpfpm_pidfile} $ITEM

		RETVAL=$?
		;;

        esac ;;

  nginx)
        case "$2" in
           stop)
                nginx_stop ;;
           start)
                nginx_start ;;
	 restart)
	        nginx_configtest -q || exit $RETVAL
        	nginx_stop
        	nginx_start
		;;

	 reload)
		nginx_reload

		;;

	  status) 
		status -p ${nginx_pidfile} $ITEM
        	RETVAL=$?
		;;
          esac ;;

 phpfpm)
	case "$2" in
	   stop)
		phpfpm_stop
		;;
	  start)
		phpfpm_start
		;;
	restart)
		phpfpm_restart
		;;	

	 reload)
		phpfpm_reload

		;;
	 status)
		status -p ${phpfpm_pidfile} "$ITEM"
		RETVAL=$?
		;;
	esac ;;

     *)                 

	echo $"Args: [all|nginx|phpfpm] start|stop|status|restart|reload"
	RETVAL=2
	;;
	
esac
exit $RETVAL
