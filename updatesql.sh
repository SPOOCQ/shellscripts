#!/bin/bash
### Script to check for SQL changes in a git repository using a gitlab-runner
##### TODO: Add a way to revert the changes to a specific hash using commandline paramaters
##### Usage ######
# Add it to your .gitlab-ci.yml like this:
#
#job_deploy_master:
#  stage: deploy
#  only:
#    - master
#  script:
#    - ~/sql_build $CI_COMMIT_BEFORE_SHA $COMMIT_SHA
#  tags:
#    - php
#
##################
OLD=$1
CURRENT=$2
#####
SQL_PATH="WHERE_THE_UPDATE_SQL_FILE_SHOULD_BE_PLACED_AND_FILENAME"
SQL_PATH="WHERE_DB_DUMPS_SHOULD_BE_SAVED"
SQL_DB="YOUR_DATABASE"
SQL_USER="YOUR_DBUSERNAME"
SQL_PASS="YOUR_DBPASSWORD"


build_updsql() {
        rm $SQL_PATH
        touch $SQL_PATH
        mapfile -t changes < <(git diff --name-only $OLD $CURRENT sql/)
        for element in "${changes[@]}"
                do
                        cat "$element" >> $SQL_PATH
                done
}


if [ "$OLD" == "$CURRENT" ]; then
        echo "Nothing to be done"
else
        build_updsql
        if [ -s $SQL_PATH ]
        then
                echo "Dumping existing database..."
                mysqldump -u $SQL_USER -p$SQL_PASS --databases $SQL_DB --result-file=$DUMP_PATH/$OLD.sql 
                echo "Updating database...
                mysql -u $SQL_USER -p$SQL_PASS $SQL_DB < $SQL_PATH
                echo "All done"
        else
                echo "Nothing to be done"
        fi
fi
