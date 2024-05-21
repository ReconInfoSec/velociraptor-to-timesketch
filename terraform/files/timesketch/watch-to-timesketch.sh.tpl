# Watch this directory for new files (ie: vr_kapetriage_$system.zip added to /opt/timesketch/upload)
PARENT_DATA_DIR="/opt/timesketch/upload"

process_files () {
    ZIP=$1
    
    # Get system name
    SYSTEM=$(echo "$ZIP" | awk -F. '{OFS="."; $NF=""; sub(/\.$/, "", $0); print}')

    # Velociraptor artifact inserts `_$label` to the zip (ex: exchangesrv_ir-1) so we can use the label "ir-1" as the sketch name, and have multiple timelines for an IR under a single sketch
    LABEL=$(echo $SYSTEM|cut -d"_" -f 4)

    # Unzip
    echo A | unzip $PARENT_DATA_DIR/$ZIP -d $PARENT_DATA_DIR/$SYSTEM
    
    # Remove from subdir
    mv $PARENT_DATA_DIR/$SYSTEM/fs/fs/clients/*/collections/*/uploads/* $PARENT_DATA_DIR/$SYSTEM/
    
    # Delete unnecessary collection data
    rm -r $PARENT_DATA_DIR/$SYSTEM/fs $PARENT_DATA_DIR/$SYSTEM/UploadFlow.json $PARENT_DATA_DIR/$SYSTEM/UploadFlow 
    
    # Run log2timeline and generate Plaso file
    docker exec -i timesketch-worker /bin/bash -c "log2timeline.py --status_view window --storage_file /usr/share/timesketch/upload/plaso/$SYSTEM.plaso /usr/share/timesketch/upload/$SYSTEM"
    
    # Wait for file to become available
    sleep 40

    # Get ID of sketch if it exists
    SKETCHES=`docker exec -i timesketch-web tsctl list-sketches`
    while IFS= read -r line; do
        name=`echo $line|cut -f 2 -d " "`
        id=`echo $line|cut -f 1 -d " "`
        if [[ "$name" == "$LABEL" ]]; then
                SKETCH_ID=$id
        else
                SKETCH_ID="none"
        fi
    done <<< "$SKETCHES"

    # Run timesketch_importer to import Plaso data into Timesketch
    if [[ "$LABEL" == "ir-"* ]]; then
        if [[ "$SKETCH_ID" == "none" ]]; then    
                docker exec -i timesketch-worker /bin/bash -c "timesketch_importer -u ${timesketch_user} -p '${timesketch_pass}' --host http://timesketch-web:5000 --timeline_name $SYSTEM --sketch_name $LABEL /usr/share/timesketch/upload/plaso/$SYSTEM.plaso"
        else
                docker exec -i timesketch-worker /bin/bash -c "timesketch_importer -u ${timesketch_user} -p '${timesketch_pass}' --host http://timesketch-web:5000 --timeline_name $SYSTEM --sketch_id $SKETCH_ID /usr/share/timesketch/upload/plaso/$SYSTEM.plaso"
        fi
    else        
        docker exec -i timesketch-worker /bin/bash -c "timesketch_importer -u ${timesketch_user} -p '${timesketch_pass}' --host http://timesketch-web:5000 --timeline_name $SYSTEM --sketch_name $SYSTEM /usr/share/timesketch/upload/plaso/$SYSTEM.plaso"
    fi

    # Copy Plaso files to dir being watched to upload to S3
    cp -ar /opt/timesketch/upload/plaso/$SYSTEM.plaso /opt/timesketch/upload/plaso_complete/
}

inotifywait -m -r -e move "$PARENT_DATA_DIR" --format "%f" | while read ZIP
do
  extension=$(echo "$ZIP" | awk -F. '{print $NF}')
  if [[ $extension == "zip" ]]; then
    process_files $ZIP &
  fi
done

