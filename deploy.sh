#!/bin/sh

#############################
# Main Application Folder
#############################
CWD='/path/to/your/application'

############################################
# Stores configuration files & other files/folders that should be shared across the application
############################################
SHARE_DIR="$CWD/shared"

############################################
# Stores files & folders that have read/write/execute permissions(0777)
############################################
WRITABLE_DIR="$SHARE_DIR/writeable"

######################################
# Stores the code releases/checkouts
######################################
RELEASE_DIR="$CWD/releases"

## Number of releases to keep
NUM_RELEASES=3

######################################
# The SYMLINK_DIR is where we point to our current release
# This could also be your /public_html, or you can use /current and create another symlink that points to it
######################################
SYMLINK_DIR="$CWD/current"

######################################
# We name this current release with a timestamp
######################################
TS=$(date +"%Y-%m-%d-%H-%M-%S")

######################################
# We name this current release with a timestamp
######################################
CUR_RLS_DIR="$RELEASE_DIR/$TS"

######################################
# List any folders that have write permissions here.
# These folders will be symlinked to the shared folder.
######################################
SHARE_WRITE[0]='app/logs'
SHARE_WRITE[1]='app/var'

echo "#####  Checking out files to new release directory..."
cd $CWD && git read-tree HEAD && git checkout-index -a -f --prefix=$CUR_RLS_DIR/

mkdir -p $WRITABLE_DIR
chmod 0777 $WRITABLE_DIR
chmod 0777 $CUR_RLS_DIR/app/cache

echo "#####  Creating Symlink for parameters.yml & .htaccess ..."
ln -s $SHARE_DIR/parameters.yml $CUR_RLS_DIR/app/config/parameters.yml 
ln -s $SHARE_DIR/.htaccess $CUR_RLS_DIR/web/.htaccess 

echo "#####  Symlinking shared folders ..."
for WRITE in "${SHARE_WRITE[@]}"
do
   rm -rf $CUR_RLS_DIR/"${WRITE}"
   mkdir -p $WRITABLE_DIR/"${WRITE}"
   chmod 0777 $WRITABLE_DIR/"${WRITE}"
   ln -s $WRITABLE_DIR/"${WRITE}" $CUR_RLS_DIR/"${WRITE}"
done

echo "#####  Copying vendors from previous release..."
cp -rf $SYMLINK_DIR/vendor $CUR_RLS_DIR/vendor

echo "#####  Installing new vendors..."
cd $CUR_RLS_DIR && php composer.phar install --prefer-dist --no-interaction --quiet

echo "#####  Performing Doctrine Migrations..."
cd $CUR_RLS_DIR && php app/console doctrine:migrations:migrate --no-interaction

echo "##### Creating new release symlink..."
ln -sfn $CUR_RLS_DIR $SYMLINK_DIR

echo "######################################"
echo "##### DEPLOYMENT COMPLETE!            "
echo "##### Cleaning up old releases ...    "
echo "######################################"

echo $TS|cat - $CWD/deploy_history.txt > $CWD/deploy_hist.tmp && mv $CWD/deploy_hist.tmp $CWD/deploy_history.txt

DEPLOY_COUNTER=0
while read line
do
    DEPLOY_COUNTER=$((DEPLOY_COUNTER+1))
    if test $DEPLOY_COUNTER -gt $NUM_RELEASES
    then
        if [ -d "$RELEASE_DIR/$line" ]; then
            echo "##### Removing old release $line ..."
            rm -rf $RELEASE_DIR/$line
        fi
    fi

done < $CWD/deploy_history.txt

echo "######################################"
echo "##### CLEANUP COMPLETE!               "
echo "######################################"
