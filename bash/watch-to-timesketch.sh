# Watch this directory for new files (ie: vr_kapetriage_$system.zip added to /opt/timesketch/upload)
PARENT_DATA_DIR="/opt/timesketch/upload"

process_files () {
    ZIP=$1
    
    # Get system name
    SYSTEM=$(echo $ZIP|cut -d"." -f 1)
    SYSTEM=${ZIP%.*}

    # Unzip
    echo A | unzip $PARENT_DATA_DIR/$ZIP -d $PARENT_DATA_DIR/$SYSTEM
    
    # Remove from subdir
    mv $PARENT_DATA_DIR/$SYSTEM/fs/clients/*/collections/*/uploads/* $PARENT_DATA_DIR/$SYSTEM/
    
    # Delete unnecessary collection data
    rm -r $PARENT_DATA_DIR/$SYSTEM/fs $PARENT_DATA_DIR/$SYSTEM/UploadFlow.json $PARENT_DATA_DIR/$SYSTEM/UploadFlow 
    
    # Run log2timeline and generate Plaso file
    docker exec -i timesketch_timesketch-worker_1 /bin/bash -c "log2timeline.py --status_view window --storage_file /usr/share/timesketch/upload/plaso/$SYSTEM.plaso /usr/share/timesketch/upload/$SYSTEM"
    
    # Wait for file to become available
    sleep 10 

    # Run timesketch_importer to send Plaso data to Timesketch
    docker exec -i timesketch_timesketch-worker_1 /bin/bash -c "timesketch_importer -u $username -p "$password" --host http://timesketch-web:5000 --timeline_name $SYSTEM --sketch_name $SYSTEM /usr/share/timesketch/upload/plaso/$SYSTEM.plaso"

    # Copy Plaso files to dir being watched to upload to S3
    cp -ar /usr/share/timesketch/upload/plaso/$SYSTEM.plaso /usr/share/timesketch/upload/plaso_complete
}

inotifywait -m -r -e move "$PARENT_DATA_DIR" --format "%f" | while read ZIP
do
  extension="${ZIP##*.}"
  if [[ $extension == "zip" ]]; then
    process_files $ZIP &
  fi
done
