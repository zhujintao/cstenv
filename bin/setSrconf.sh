#!/bin/sh


domain=$1
port=${2:-80}
location=${3:-/}

SRfile=SR/$domain
LBfile=LB/$domain

tLBfile=$LBfile
tSRfile=$SRfile
if [ -n "`echo $domain|sed -n /\*/p`" ];then

   t=$(echo $domain|sed -n 's/\*/_/gp')
   tLBfile=LB/$t
   tSRfile=SR/$t

fi

crtpath=$5
keypath=$6
if [ "$port" == "443" ] || ([ -n "$4" ] && [ "$4" == "ssl" ]);then
ssl="
                         ssl_certificate           $crtpath;
                         ssl_certificate_key       $keypath;
                         ssl on;
                         ssl_session_cache  builtin:1000  shared:SSL:10m;
                         ssl_protocols  TLSv1 TLSv1.1 TLSv1.2;
                         ssl_ciphers HIGH:!aNULL:!eNULL:!EXPORT:!CAMELLIA:!DES:!MD5:!PSK:!RC4;
                         ssl_prefer_server_ciphers on;

"
fi

createItem() {
cat > $tSRfile << EOF
server {
   listen $port; 
   server_name $domain;
   $ssl
                         location $location {
                                        proxy_pass  http://$domain;
                                        proxy_set_header        Accept-Encoding   "";
                                        proxy_set_header        Host            \$host;
                                        proxy_set_header        X-Real-IP       \$remote_addr;
                                        proxy_set_header        X-Forwarded-For \$proxy_add_x_forwarded_for;
                                        proxy_set_header        X-Forwarded-Proto \$scheme;
                                        add_header              Front-End-Https   on;
                                        proxy_redirect          off;

                                    }
          }

EOF
}





addHttps443() {
     tmppath=/tmp/tmpssl`date +%N`
     if [ ! -n "`sed -ne "/listen*.*;/ {/443/p}" $tSRfile`" ];then

cat > $tmppath <<EOF

                         ssl_certificate           $crtpath;
                         ssl_certificate_key       $keypath;
                         ssl_session_cache  builtin:1000  shared:SSL:10m;
                         ssl_protocols  TLSv1 TLSv1.1 TLSv1.2;
                         ssl_ciphers HIGH:!aNULL:!eNULL:!EXPORT:!CAMELLIA:!DES:!MD5:!PSK:!RC4;
                         ssl_prefer_server_ciphers on;

EOF

	sed -i '/listen*.*;/{p;s/80/443 ssl/}' $tSRfile
	if [ ! -n  "`sed -n "/server_name*.*;*/p" $tSRfile`" ];then
		sed -i "/server_name*.*/,/;/!b;/;/r $tmppath" $tSRfile

        else
       		sed -i "/server_name*.*;*/r $tmppath" $tSRfile
	fi
        	rm -rf $tmppath
     fi
}


addServer() {
location=${location:1}
cat >> $tSRfile << EOF
server {
   listen $port; 
   server_name $domain;
   $ssl
                         location $location {
                                        proxy_pass  http://$domain;
                                        proxy_set_header        Accept-Encoding   "";
                                        proxy_set_header        Host            \$host;
                                        proxy_set_header        X-Real-IP       \$remote_addr;
                                        proxy_set_header        X-Forwarded-For \$proxy_add_x_forwarded_for;
                                        proxy_set_header        X-Forwarded-Proto \$scheme;
                                        add_header              Front-End-Https   on;
                                        proxy_redirect          off;

                                    }
          }

EOF
}

addLocation() {
   tmppath=/tmp/tmplocation`date +%N`
   location=${location:1}
   
cat > $tmppath <<EOF

                         location $location {
                                        proxy_pass  http://$1;
                                        proxy_set_header        Accept-Encoding   "";
                                        proxy_set_header        Host            \$host;
                                        proxy_set_header        X-Real-IP       \$remote_addr;
                                        proxy_set_header        X-Forwarded-For \$proxy_add_x_forwarded_for;
                                        proxy_set_header        X-Forwarded-Proto \$scheme;
                                        add_header              Front-End-Https   on;
                                        proxy_redirect          off;

                                    }

EOF

   sed -i "/listen*.*$port/,/}/!b;/}/r $tmppath" $tSRfile 
   rm $tmppath
}


addDomain() {
  
  echo "aa"

}


if [ -e $tSRfile ]; then
	
   
  if (("$port" == "443"));then
      addHttps443
  fi

  if [ $location == "+" ];then
     shift 3
     sed -i "/listen*.* $port[ ;]/,/server_name/{s/server_name/server_name $*/}" $tSRfile
  fi
   

  if  [ ! -n "`sed -n "/listen*.*$port/p" $tSRfile`" ];then

     addServer

  elif  [ ${location:0:2} == "+/" ];then
    location=$(echo ${location:1}|sed -n 's/\//\\\//gp')
    if [ ! -n "`sed -ne "/listen*.*$port/,/location*.*$location .*{/{/location*.*$location .*{/p}" $tSRfile`" ];then
     if [ ! -n "$4" ];then
        echo "args: \$4"
        exit 1
     fi 
	
     eupstream=$(echo $domain|sed -n 's/\./\\./gp')
     a=${eupstream}_$4 
     if [ -n "`sed -n "/$a .*{/p" $tLBfile`" ];then 
        addLocation ${domain}_$4
      else
	echo "pls create sub us"
     fi

    fi

  fi

elif [ -e $tLBfile ]  ;then
     if [ ${location:0:1} != "/" ];then
        echo "path error"
        exit
     fi
     createItem 
else
     echo "pls create us"
fi

