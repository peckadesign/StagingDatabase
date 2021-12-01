#!/bin/bash

IGNORED="" # g
UPLOAD_SKIP=false

while getopts "i:p:o:s:l:d:a:g::u" o; do
        case "${o}" in
        i)
                IDENTITY_FILE=${OPTARG}
                ;;
        p)
                DATABASE=${OPTARG}
                ;;
        o)
                OUTPUT=${OPTARG}
                ;;
        g)
                IGNORED=${OPTARG}
                ;;
	s)
		SSH_NAME=${OPTARG}
		;;
	l)
		LOCAL_IDENTITY_FILE=${OPTARG}
		;;
	d)
		LOCAL_DATABASE=${OPTARG}
		;;
	a)
		ANONYMIZE=${OPTARG}
		;;
	u)
		UPLOAD_SKIP=true
		;;
	*)
                echo "Použití: $0 -i <cesta k souboru s identitou> -p <název produkční databáze> -o <adresář pro uložení dumpů> -g <mezerou oddělené názvy ignorovaných tabulek> -s <název SSH konfigurace> -l <cesta k souboru s identiou k lokální databázi> -d <název lokální databáze> -a <mezerou oddělené cesty k SQL kriptům, které budou upravovat data před dumpem>" 1>&2; exit 1;
                ;;
        esac
done
shift $((OPTIND-1))

if [ -z "${IDENTITY_FILE}" ] || [ -z "${DATABASE}" ] || [ -z "${OUTPUT}" ] || [ -z "${IGNORED}" ] || [ -z "${SSH_NAME}" ] || [ -z "${LOCAL_IDENTITY_FILE}" ] || [ -z "${LOCAL_DATABASE}" ]; then
	exit 1
fi	

if  ! $UPLOAD_SKIP ; then
	echo $(date +%T) "Nahraji zálohovací skript na ostrý server"
	scp /root/StagingDatabase/backup_production.sh ${SSH_NAME}:${OUTPUT}
fi

echo $(date +%T) "Spustím zálohu na ostrém serveru"
ssh ${SSH_NAME} bash ${OUTPUT}/backup_production.sh -i ${IDENTITY_FILE} -p ${DATABASE} -o ${OUTPUT} -a \"${ANONYMIZE}\" -g \"${IGNORED}\"

echo $(date +%T) "Stáhnu strukturu databáze"
scp -C ${SSH_NAME}:${OUTPUT}/${DATABASE}_structure.sql /var/databases/${DATABASE}_structure.sql

echo $(date +%T) "Stáhnu anonymizovaná data"
scp -C ${SSH_NAME}:${OUTPUT}/${DATABASE}_anonymize.sql /var/databases/${DATABASE}_data.sql

echo $(date +%T) "Mažu obsah databáze"
mysql --defaults-extra-file=${LOCAL_IDENTITY_FILE} --skip-column-names -e "SELECT concat(IF(STRCMP(table_type, 'view'), 'DROP TABLE ', 'DROP VIEW '), '\`', table_name, '\`;') FROM information_schema.tables WHERE table_schema = '${LOCAL_DATABASE}';" ${LOCAL_DATABASE} | mysql --defaults-extra-file=${LOCAL_IDENTITY_FILE} --init-command="SET FOREIGN_KEY_CHECKS = 0;" ${LOCAL_DATABASE}

echo $(date +%T) "Obnovím strukturu databáze"
cat /var/databases/${DATABASE}_structure.sql | mysql --defaults-extra-file=${LOCAL_IDENTITY_FILE} ${LOCAL_DATABASE}

echo $(date +%T) "Obnovím data"
cat /var/databases/${DATABASE}_data.sql | mysql --defaults-extra-file=${LOCAL_IDENTITY_FILE} ${LOCAL_DATABASE}

echo $(date +%T) "Optimalizuji databázi"
mysqloptimize --defaults-extra-file=${LOCAL_IDENTITY_FILE} ${LOCAL_DATABASE}

echo $(date +%T) "Obnova dokončena"
