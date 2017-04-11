#!/bin/bash

# Funciones ##########################################################
parse_yaml() {
   local prefix=$2
   local s='[[:space:]]*' w='[a-zA-Z0-9_]*' fs=$(echo @|tr @ '\034')
   sed -ne "s|^\($s\)\($w\)$s:$s\"\(.*\)\"$s\$|\1$fs\2$fs\3|p" \
        -e "s|^\($s\)\($w\)$s:$s\(.*\)$s\$|\1$fs\2$fs\3|p"  $1 |
   awk -F$fs '{
      indent = length($1)/2;
      vname[indent] = $2;
      for (i in vname) {if (i > indent) {delete vname[i]}}
      if (length($3) > 0) {
         vn=""; for (i=0; i<indent; i++) {vn=(vn)(vname[i])("_")}
         printf("%s%s%s=\"%s\"\n", "'$prefix'",vn, $2, $3);
      }
   }'
}

require_clean_work_tree () {
    # Update the index
    git update-index -q --ignore-submodules --refresh
    err=0

    # check for unstaged changes in the working tree
    if [[ $(check_unstaged_files) > 0 ]]; then
        err=1
    fi

    # Check untracked files in the working tree
    if [[ $(check_untracked_files) > 0 ]]; then
        err=1
    fi

    echo "$err"
}

function check_unstaged_files {
    git diff --no-ext-diff --quiet --exit-code
    echo $?
}

function check_untracked_files {
   expr `git status --porcelain 2>/dev/null| grep "^??" | wc -l`
}

confirm() {
    read -r -p "${1:-Are you sure? [Y/n]} " response
    case "$response" in
        [yY][eE][sS]|[yY])
            true
            ;;
        *)
            if [ -z $response ]; then
                true
            else
                false
            fi
            ;;
    esac
}

function get_latest_dump {
    if [ ! -d "$DUMP_DIRECTORY" ]; then
       mkdir -p data/dumps;
    fi
    LATEST_DUMP="$(ls data/dumps/ -1t | head -1)"
    echo $LATEST_DUMP
}

function get_database_container {
    MYSQL_CONTAINER=$(./sfdocker ps | grep mysql);
    if [[ $MYSQL_CONTAINER == "" ]]; then
        MYSQL_CONTAINER=$(./sfdocker ps | grep percona);
    fi
    if [[ $MYSQL_CONTAINER == "" ]]; then
        echo "$ERROR_PREFIX No se pudo encontrar ningun contenedor en ejecución que contenga las palabras clave 'mysql' y/o 'percona'"
        exit 1;
    fi

    set -- "$MYSQL_CONTAINER"
    IFS=" "; declare -a Array=($*)
    echo "${Array[0]}"
}
# Funciones END #######################################################

eval $(parse_yaml app/config/parameters.yml "yml_")

COMPOSE="docker-compose"
COMPOSE_FILE="$(ls docker-compose*)"

if [[ $COMPOSE_FILE != "docker-compose.yml" ]]; then
  COMPOSE="$COMPOSE -f $COMPOSE_FILE"
fi

CONTAINER=$yml_parameters__sfdocker_default_container
CACHE_ENV="dev"
EXEC="$COMPOSE exec --user www-data"
EXEC_T="$COMPOSE exec -T --user www-data"
EXEC_PRIVILEGED="$COMPOSE exec --user root"
BASH_C="bash -c"
ERROR_PREFIX="ERROR ::"
WARNING_PREFIX="WARNING ::"
INFO_PREFIX="INFO ::"
HOOK=1
FOUND=0

if [[ $# < 1 ]]; then
    echo "$ERROR_PREFIX Dame un argumento madafaka! (start/stop/restart/enter/logs/console/ccode/cache/destroy/composer/ps/mysql)";
    exit 1;
fi

# Docker handling
if [[ $1 == "start" ]]; then
    if [[ $# > 1 && $2 == "-b" ]]; then
      $COMPOSE up -d --build
    else
      $COMPOSE up -d
    fi
    FOUND=1
fi

if [[ $1 == "stop" ]]; then
    $COMPOSE down
    FOUND=1
fi

if [[ $1 == "restart" ]]; then
    $COMPOSE down
    $COMPOSE up -d
    FOUND=1
fi

if [[ $1 == "enter" ]]; then
    if [[ $# > 1 && $2 != "-p" ]]; then
      CONTAINER=$2
    fi
    if [[ "${@: -1}" == "-p" ]]; then
      $EXEC_PRIVILEGED $CONTAINER bash
    else
      $EXEC $CONTAINER bash
    fi
    FOUND=1
fi

if [[ $1 == "logs" ]]; then
    if [[ $# > 0 && $2 != "all" ]]; then
        if [[ $# > 1 ]]; then
            CONTAINER=$2
        fi
      $COMPOSE logs | grep $CONTAINER
    else
      $COMPOSE logs
    fi
    FOUND=1
fi

# Symfony console handling
if [[ $1 == "console" ]]; then
     $EXEC $CONTAINER $BASH_C "php app/console $2 $3 $4";
     FOUND=1
fi

# Code handling (pre-commit hook)
if [[ $1 == "ccode" ]]; then
    if [[ $(require_clean_work_tree) == 1 ]]; then
      echo "#########################################################################"
      echo "# $WARNING_PREFIX Tienes ficheros sin añadir a staging que no se comprobarán #"
      echo "#########################################################################"
    fi
    if [[ $HOOK == 1 ]]; then
      $EXEC_T $CONTAINER $BASH_C "php app/hooks/pre-commit.php"
    fi
    FOUND=1
fi

# Cache handling
if [[ $1 == "cache" ]]; then
    if [[ $# > 1 ]]; then
      CACHE_ENV=$2
    fi
    if [[ $2 == "all" ]]; then
        $EXEC $CONTAINER $BASH_C "php app/console ca:cl --env=dev;php app/console ca:cl --env=test;php app/console ca:cl --env=prod";
    else
        $EXEC $CONTAINER $BASH_C "php app/console ca:cl --env=$CACHE_ENV";
    fi
    FOUND=1
fi

# Destroy handling
if [[ $1 == "destroy" ]]; then
    if confirm "Te vas a cepillar todos los contenedores docker que tengas en tu equipo. ¿Estás seguro? [Y/n] "; then
        # Levantar los contenedores, por si no estuvieran todos levantados
        $COMPOSE up -d --remove-orphans
        # Parar todos los contenedores y después eliminarlos
        docker stop $(docker ps -a -q)
        docker rm $(docker ps -a -q)
    fi
    FOUND=1
fi

# Composer handling
if [[ $1 == "composer" ]]; then
    if [[ $# < 2 ]]; then
        echo "$ERROR_PREFIX ¡Necesito un segundo un argumento madafaka! (install/update/require/...)";
        exit 1;
    fi
    if [ -f /etc/php/7.1/cli/conf.d/20-xdebug.ini ]; then
        $EXEC_PRIVILEGED $CONTAINER $BASH_C "mv /etc/php/7.1/cli/conf.d/20-xdebug.ini /etc/php/7.1/cli/conf.d/20-xdebug.ini.bak";
    fi
    $EXEC $CONTAINER $BASH_C "$1 $2 $3 $4";
    if [ -f /etc/php/7.1/cli/conf.d/20-xdebug.ini.bak ]; then
        $EXEC_PRIVILEGED $CONTAINER $BASH_C "mv /etc/php/7.1/cli/conf.d/20-xdebug.ini.bak /etc/php/7.1/cli/conf.d/20-xdebug.ini";
    fi
    FOUND=1
fi

if [[ $1 == "ps" ]]; then
    $COMPOSE ps;
    FOUND=1;
fi

if [[ $1 == "mysql" ]]; then
     if [[ $# < 2 ]]; then
        echo "$ERROR_PREFIX ¡Necesito un segundo un argumento madafaka! (dump/restore)"
        exit 1
     fi
     FOUND=1
     NOW_DATE=`date +%d-%m-%Y_%H-%M-%S`
     DATABASE_CONTAINER=$(get_database_container)

     DATABASE_HOST=$yml_parameters__database_host
     DATABASE_PORT=$yml_parameters__database_port
     DATABASE_NAME=$yml_parameters__database_name
     DATABASE_USER=$yml_parameters__database_user
     DATABASE_PASSWORD=$yml_parameters__database_password

     DUMP_DIRECTORY="data/dumps/"
     DUMP_NAME=$(echo ${DATABASE_NAME}_${NOW_DATE})".sql"
     DUMP_FILE=$DUMP_DIRECTORY$DUMP_NAME
     DUMP_INFO="$INFO_PREFIX Exportando la base de datos $DATABASE_NAME al fichero: $DUMP_FILE"

     RESTORE_FILE=$(get_latest_dump)
     RESTORE_PATH=$DUMP_DIRECTORY$RESTORE_FILE

     DUMP_CMD="docker exec -i $DATABASE_CONTAINER mysqldump -h $DATABASE_HOST -P $DATABASE_PORT -u $DATABASE_USER -p$DATABASE_PASSWORD $DATABASE_NAME > $DUMP_FILE 2>/dev/null"

     if [[ -z "$RESTORE_FILE" && $2 == "restore" ]]; then
        echo "¡No existe ningun dump en la carpeta $DUMP_DIRECTORY!"
        exit 1;
     fi

     RESTORE_CMD="docker exec -i $DATABASE_CONTAINER mysql -u$DATABASE_USER -p$DATABASE_PASSWORD $DATABASE_NAME < $RESTORE_PATH 2>/dev/null"
     RESTORE_INFO="$INFO_PREFIX Importando la base de datos $DATABASE_NAME al fichero: $RESTORE_PATH"

     if [[ $2 == "restore" ]]; then
        if confirm "Te dispones a restaurar la última versión de la base de datos: $RESTORE_FILE ¿Estás seguro? [Y/n] "; then
            eval $RESTORE_CMD
            printf "\n¡Restauración efectuda correctamente!\n\n"
        fi
     elif [[ $2 == "dump" ]]; then
        echo "$DUMP_FILE"
        eval $DUMP_CMD
     elif [[ $2 == "clear" ]]; then
        cd $DUMP_DIRECTORY && find . -type f ! -name $RESTORE_FILE -delete
        printf "\n¡Limpieza de dumps efectuda correctamente!\n\n"
     else
        FOUND=0;
     fi
fi

# Help handling
if [[ $1 == "--help" ]]; then
    echo "###################################################";
    echo "AYUDA DE SFDOCKER:";
    echo "1.- Contenedores: ./sfdocker <start/stop/restart/destroy/enter/ps/logs>";
    echo "2.- Consola de symfony: ./sfdocker console <args>";
    echo "3.- Caché de symfony: ./sfdocker cache <dev/prod/all>";
    echo "4.- Check de código pre-commit: ./sfdocker ccode";
    echo "5.- Composer: ./sfdocker composer <args>";
    echo "6.- Mysql: ./sfdocker mysql <dump/restore/clear>";
    echo "###################################################";
    FOUND=1
fi

# Error handling
if [[ $FOUND == 0 ]]; then
  echo "$ERROR_PREFIX ¿Y qué tal si introduces un comando que exista cabeza de chorlit@?";
  echo "./sfdocker --help para ayuda.";
fi