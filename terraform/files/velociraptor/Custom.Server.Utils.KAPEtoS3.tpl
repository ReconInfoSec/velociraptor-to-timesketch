name: Custom.Server.Utils.KAPEtoS3
description: |
   This server monitoring artifact will automatically backup any collected artifacts to S3.
   Filename: `vr_kapefiles_$fqdn_$label.zip`

type: SERVER_EVENT

parameters:
   - name: ArtifactNameRegex
     default: "Windows.KapeFiles.Targets"
     description: A regular expression to select which artifacts to upload
   - name: Bucket
     default: "${s3_bucket}"
   - name: Region
     default: "${region}"
   - name: CredentialsKey
     default: "${credkey}"
   - name: CredentialsSecret
     default: "${credsecret}"

sources:
  - query: |
        -- Temp file to write on. It will be truncated for each collection.
        LET output_file <= tempfile(extension=".zip")
        
        -- Allow these settings to be set by the artifact parameter or the server metadata.
        LET bucket <= if(condition=Bucket, then=Bucket, 
           else=server_metadata().DefaultBucket)
        LET credentialskey <= if(condition=CredentialsKey, then=CredentialsKey, 
           else=server_metadata().S3AccessKeyId)
        LET region <= if(condition=Region, then=Region, 
           else=server_metadata().DefaultRegion)
        LET credentialssecret <= if(condition=CredentialsSecret, 
              then=CredentialsSecret, else=server_metadata().S3AccessSecret)
        
        -- Define a tmp artifact that uploads the files in the flow. 
        -- We will then collect that artifact into a zip file.
        LET UploadFlowDefinition = '
        name: UploadFlow
        
        parameters:
           - name: FlowId
           - name: ClientId
        
        sources:
          - name: FlowDetails
            query: SELECT * FROM flows(client_id=ClientId, flow_id=FlowId)
          - query: |
                SELECT * FROM foreach(
                row={
                    SELECT * FROM enumerate_flow(client_id=ClientId, flow_id=FlowId)
                },
                query={
                  SELECT FullPath, 
                         upload(file=FullPath, accessor="fs") AS Upload 
                  FROM stat(filename=VFSPath, accessor="fs")
                })
        '
        
        // Use second LET if you wish to use client labels in your filename/sketch 
        // LET upload_to_s3(ClientId, FlowId, Fqdn) = SELECT ClientId,
        LET upload_to_s3(ClientId, FlowId, Fqdn, Label) = SELECT ClientId,
               upload_s3(bucket=bucket,
                         credentialskey=credentialskey,
                         credentialssecret=credentialssecret,
                         region=region,
                         file=output_file,
                         //name=format(format="vr_kapefiles_%v.zip", 
                         //   args=[Fqdn])) AS S3
                         name=format(format="vr_kapefiles_%v_%v.zip", 
                            args=[Fqdn, Label])) AS S3                            
        FROM collect(artifacts="UploadFlow", artifact_definitions=UploadFlowDefinition,
                     args=dict(`UploadFlow`=dict(
                            ClientId=ClientId, FlowId=FlowId)), 
                     output=output_file)
                     
        // Use second LET if you wish to use client labels in your filename/sketch 
        // LET completions = SELECT *, client_info(client_id=ClientId).os_info.fqdn AS Fqdn 
        LET completions = SELECT *, client_info(client_id=ClientId).os_info.fqdn AS Fqdn, client_info(client_id=ClientId).labels[0] as Label 
            FROM watch_monitoring(artifact="System.Flow.Completion")
            WHERE Flow.artifacts_with_results =~ ArtifactNameRegex
        
        // Use second SELECT if you wish to use client labels in your filename/sketch 
        SELECT * FROM foreach(row=completions, query={
          // SELECT * FROM upload_to_s3(ClientId=ClientId, FlowId=FlowId, Fqdn=Fqdn)
          SELECT * FROM upload_to_s3(ClientId=ClientId, FlowId=FlowId, Fqdn=Fqdn, Label=Label)
        })
