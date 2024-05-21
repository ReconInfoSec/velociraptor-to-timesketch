# Watch S3 bucket for new files
#/usr/bin/python

import os
import sys
import boto3
import pytz
from datetime import datetime,timedelta
from os import path

s3 = boto3.resource('s3')
s3_client = boto3.client('s3')

bucket_name = "${s3_bucket}" 
bucket = s3.Bucket(bucket_name)

while True:
    for key in bucket.objects.all():
        time_now = datetime.utcnow().replace(tzinfo=pytz.UTC)
        delta_1s = time_now - timedelta(seconds=1200)
        if key.last_modified >= delta_1s and ".zip" in key.key:

            if path.isfile("/opt/timesketch/upload/"+key.key):
                print("File exists, skipping")
            else:
                print("Downloading file")
                s3_client.download_file(bucket_name, key.key, '/opt/timesketch/upload/'+key.key)

