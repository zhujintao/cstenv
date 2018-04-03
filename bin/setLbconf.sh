#!/bin/sh


domain=`echo $1|awk -F_ '{print $1}'`
suffix=`echo $1|awk -F_ '{print $2}'`


LBfile=LB/$domain
upstream=$domain
if [ -n "$suffix" ];then
   upstream=$1
fi
shift
backends=`echo "$*"|awk '{for(i=1;i<=NF;i++)a[NR,i]=$i}END{for(j=1;j<=NF;j++)for(k=1;k<=NR;k++)printf k==NR?"  server " a[k,j]";" RS:a[k,j] FS}'`



tLBfile=$LBfile
if [ -n "`echo $domain|sed -n /\*/p`" ];then

   t=$(echo $domain|sed -n 's/\*/_/gp')
   tLBfile=LB/$t

fi

if [ ! -e $tLBfile ];then
 
cat > $tLBfile << EOF
upstream $upstream {
 
$backends 

}
EOF

else

eupstream=$(echo $upstream|sed -n 's/\./\\./gp')
if [ ! -n "`sed -n "/$eupstream/p" $tLBfile`" ];then

cat >> $tLBfile << EOF

upstream $upstream {
 
$backends 

}
EOF
fi 
fi

