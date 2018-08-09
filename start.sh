#!/usr/bin/env bash

IMAGE="rtakauti/magento2-dev"
VERSION=2.2.5
DOC=~/Documentos/Vindi/Projetos/Magento/Version/magento
GITHUB=https://github.com/magento/magento2/archive/${VERSION}.tar.gz
PROXY=~/docker/nginx-proxy
PROXY_CERT=${PROXY}/data/certs/
ETC_HOSTS=/etc/hosts
IP="127.0.0.1"
FOLDER="$(basename "$PWD")"
HOSTNAME="$FOLDER.local"
CREDENTIALS="/C=BR/ST=SP/L=Sao Paulo/CN=${HOSTNAME}.br/OU=IT/O=Vindi SA/emailAddress=rubens.takauti@vindi.com"
FILE="docker-compose.yml"
HOSTS_LINE="$IP\t$HOSTNAME"


if [ -z "$(grep $HOSTNAME $ETC_HOSTS)" ]; then
   sudo -- sh -c -e "echo '$HOSTS_LINE' >> /etc/hosts";
    if [ -n "$(grep $HOSTNAME $ETC_HOSTS)" ]; then
        echo "$HOSTNAME foi adicionado com sucesso \n $(grep $HOSTNAME /etc/hosts)";
    fi
fi


DOCKER_COMPOSE=$(cat <<EOF
version: '3.3'
services:
    ${FOLDER}db:
        image: mariadb
        container_name: ${FOLDER}_db
        volumes:
         - ./${FOLDER}_db:/var/lib/mysql
        ports:
         - "3306"
        environment:
         - MYSQL_DATABASE=${FOLDER}
         - MYSQL_ROOT_PASSWORD=123
    ${FOLDER}web:
#        image: webgriffe/php-apache-base
        image: ${IMAGE}
        container_name: ${FOLDER}_web
        depends_on:
        - ${FOLDER}db
        volumes:
        - ./${FOLDER}_html:/var/www/html
        ports:
        - "80"
        links:
         - ${FOLDER}db:mysql
        environment:
        - VIRTUAL_HOST=${HOSTNAME}
        - APACHE_DOC_ROOT=/var/www/html
        - XDEBUG_ENABLE=1
        - PHP_TIMEZONE=America/Sao_Paulo

networks:
  default:
    external:
      name: webproxy
EOF
)

if [ ! -f "$FILE" ]; then
    echo "$DOCKER_COMPOSE" > $FILE;
fi

if [ ! -f "${PROXY_CERT}${HOSTNAME}.key" ]; then
    openssl req \
       -newkey rsa:2048 -nodes -keyout ${PROXY_CERT}${HOSTNAME}.key \
       -subj "$CREDENTIALS" \
       -out ${PROXY_CERT}${HOSTNAME}.csr

    openssl req \
    -key ${PROXY_CERT}${HOSTNAME}.key \
    -x509 \
    -nodes \
    -new \
    -out ${PROXY_CERT}${HOSTNAME}.crt \
    -subj "$CREDENTIALS" \
    -reqexts SAN \
    -extensions SAN \
    -config <(cat /usr/lib/ssl/openssl.cnf \
        <(printf "[SAN]\nsubjectAltName=DNS:${HOSTNAME}")) \
    -sha256 \
    -days 3650
fi

if [ ! -f "${DOC}${VERSION}.tar.gz" ]; then
    wget ${GITHUB} -O ${DOC}${VERSION}.tar.gz
fi


if [ ! -f "${FOLDER}_html/app/bootstrap.php" ]; then
    mkdir ${FOLDER}_html
    tar -xzf ${DOC}${VERSION}.tar.gz -C ${FOLDER}_html --strip-components 1
fi

docker-compose down && docker-compose up -d
docker-compose -f ${PROXY}/docker-compose.yml up -d
docker ps
docker run --rm -it -v $PWD/${FOLDER}_html:/usr/src -w /usr/src ${IMAGE} composer install
sudo chmod -R 777 ~/docker 

google-chrome https://${HOSTNAME}
