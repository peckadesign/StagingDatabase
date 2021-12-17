#!/bin/bash

IGNORED="" # g

while getopts "i:p:o:a:g::" o; do
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
	a)
		ANONYMIZE=${OPTARG}
		;;
	*)
		echo "Použití: $0 -i <cesta k souboru s identitou> -p <název produkční databáze> -o <adresář pro uložení dumpů> -g <mezerou oddělené názvy ignorovaných tabulek> -a <mezerou oddělené cesty k anonymizačním SQL skriptům>" 1>&2; exit 1;
		;;
	esac
done
shift $((OPTIND-1))


DUMP_COMMAND="mysqldump --defaults-extra-file=$IDENTITY_FILE $DATABASE --no-create-info --single-transaction --skip-triggers"
for IGNORED_TABLE in ${IGNORED}; do
	DUMP_COMMAND="$DUMP_COMMAND --ignore-table=${DATABASE}.${IGNORED_TABLE}"
done

echo $(date +%T) "Dumpuji produkční schéma"
mysqldump --defaults-extra-file=$IDENTITY_FILE $DATABASE --no-data --single-transaction --routines --events > ${OUTPUT}/${DATABASE}_structure.sql

echo $(date +%T) "Dumpuji produkční data"
$DUMP_COMMAND > ${OUTPUT}/${DATABASE}_data.sql

echo $(date +%T) "Připravuji schéma pro obnovení"
sed -i 's/DEFINER=[^*]*\*/\*/g' ${OUTPUT}/${DATABASE}_structure.sql 
sed -i '/ALTER DATABASE/d' ${OUTPUT}/${DATABASE}_structure.sql 

echo $(date +%T) "Mažu obsah databáze ${DATABASE}_bac"
mysql --defaults-extra-file=${IDENTITY_FILE} --skip-column-names -e "SELECT concat(IF(STRCMP(table_type, 'view'), 'DROP TABLE ', 'DROP VIEW '), table_name, ';') FROM information_schema.tables WHERE table_schema = '${DATABASE}_bac';" ${DATABASE}_bac | mysql --defaults-extra-file=${IDENTITY_FILE} --init-command="SET FOREIGN_KEY_CHECKS = 0;" ${DATABASE}_bac 

echo $(date +%T) "Obnovuji schéma pro anonymizaci"
cat ${OUTPUT}/${DATABASE}_structure.sql | mysql --defaults-extra-file=${IDENTITY_FILE} -A ${DATABASE}_bac

echo $(date +%T) "Obnovuji data pro anonymizaci"
cat ${OUTPUT}/${DATABASE}_data.sql | mysql --defaults-extra-file=${IDENTITY_FILE} ${DATABASE}_bac

echo $(date +%T) "Anonymizuji databázi"
for ANONYMIZE_SCRIPT in ${ANONYMIZE}; do
	echo $(date +%T) "Spouštím skript ${ANONYMIZE_SCRIPT}"
	cat ${ANONYMIZE_SCRIPT} | mysql --defaults-extra-file=${IDENTITY_FILE} ${DATABASE}_bac
done

echo $(date +%T) "Dumpuji anonymizovaná data"
mysqldump --defaults-extra-file=$IDENTITY_FILE ${DATABASE}_bac --no-create-info --single-transaction --skip-triggers > ${OUTPUT}/${DATABASE}_anonymize.sql
