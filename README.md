Varnish will act as the entry point and cache layer because it is very good with shuttling connections and managing what
happens when things 404. So Varnish sits in front of NGINX and the S3 proxy. For get requests we first try nginx and if
that works then great we just serve the file. If it is a POST request (i.e. a file upload) it goes to the S3 proxy so
that it can write things to a directory for the next person that wants to get it. If we get a request that nginx can't
serve then Varnish asks the S3 proxy to get the file from S3 and write it to a directory that nginx can serve. Once the file
is in the right place we send a re-try response to the client and they come back to get the file that has been downloaded from S3
and decrypted. 

# Dataflow
All the state is kept of the file system to make it easier to debug any issues. Here's the current dataflow:

* User uploads file to a server
* File is moved to a non-temporary folder where nginx can serve it and a symlink is created to it in another folder to indicate that it needs to be encrypted and uploaded to S3. Notice that the move is atomic so at no point do we have a file that is visible to anyone in a half-copied state. This also means that even if we move another file on top of it the work that has already started using this file will not be corrupted
* A cron job or some process reads the symlink and begins encrypting the file. The results are written incrementally to a staging folder. If something goes wrong at this point the only price we pay is repeated work because we only remove the symlink if we get to the point of moving the file atomically to another folder to indicate successful completion of encryption
* Once processing is complete the file is moved into a third directory and the symlink is removed to indicate completion. Once again notice that if something goes wrong and we don’t remove the symlink then the only price we pay is doing extra work and at no point do we have any data that is in a half-finished state
* Now another process comes along and does further work using the same pattern of saving progress in a temporary place and then atomically moving it into another folder for further processing and indicating completion by removing any symlinks from the previous place. In our case this just means uploading the encrypted file to S3

This procedure gets us almost all the way there but there is subtle bug in the pipeline. There is a race condition between an upload and the completion of the first processing stage. This means that while we are processing the file it is possible for an upload to overwrite the file we are currently processing and although this is not a problem because the previous file will be processed to completion we will incorrectly remove a symlink to a file that is newer than than one we were processing. This means we will never process the newer file because the new symlink will be deleted once we are done processing the older file.

Fortunately this is easy to fix. Before we begin processing the first stage of the pipeline we acquire a lock and release it when we are done processing the file. This means that the upload process must also acquire the lock to create the symlink and so it blocks until the first stage of the pipeline is done. Once it is unblocked the upload process will re-create the symlink and upon the next iteration of the pipeline we will process the newer file. We only need to be concerned about the first stage because that is the only place where there is a race condition. Of course this is all assuming nothing crashes while performing all these operations. Nothing bad happens if the processing pipeline crashes because in all those cases we will just do extra work. There is a problem though if the upload process crashes after the file is moved into place but before the symlink is created to indicate that we need to process the file.

To handle the case of the crashed upload process we touch a file before moving the file into place and creating the symlink and delete that file once the symlink is created. This means if we crash at any point we will have an indicator that something went wrong because the file that we touched to indicate the beginning of the transaction will not be deleted. We can use those markers to do weekly maintenance on the state of the file system by stopping both the upload process and the processing pipeline and then repairing any stale data left from potential crashes.

# Key Rotation
We keep track of which key was used to encrypt the artifact by prepending SHA1 of the key to the S3 upload path. This lets us add new keys as necessary while retaining the ability to decrypt old artifacts and also re-rencrypt all old artifacts with new keys if necessary. We also have another layer of protection through S3 keys and can revoke access to the bucket by just revoking S3 keys.

# Endpoints
There are just two endpoints `GET /*` and `POST /*`. The post endpoint assumes a file is being uploaded and treats the splat parameter as the path from the root of wherever files are being served. The GET endpoint assumes the file needs to be fetched from S3, decrypted, and the full path placed at the root of the wherever files are being served. The splat parameter is again treated as the full path to the file that needs to be fetched from S3.

So to upload a file just make a POST with a form variable `file=@file` and with the relative path of where you want the file to end up from the root directory.

# Directory Structure
The initial directory structure of `/opt/s3proxy` should look as below. We are excluding `vendor` because that's just Ruby gems. The `keys` directory structure will change
but `latest` will always point at the most recent key and it needs to be there regardless of whether artifacts are going to be encrypted or not

```
.
├── app.rb
├── bin
│   └── encryptor.rb
├── config.ru
├── config.yaml
├── Gemfile
├── Gemfile.lock
├── keys
│   ├── latest -> private_key
│   └── private_key
├── lib
│   └── constants.rb
├── nginx
│   └── nginx.conf
├── Rakefile
├── README.md
├── requirements
├── setup.sh
├── systemd
│   ├── scripts
│   └── system
│       └── s3proxy.service
└── varnish
    └── default.vcl
```

## POST /*
Making a post request (`curl -X POST -F 'file=@file' localhost:9292/path/to/file`) should leave the directory structure in the following form regardless of whether you
plan to encrypt the artifact before uploading to S3 or not

```
# ...
├── locks
│   └── path
│       └── to
│           └── file
# ...
├── to_encrypt
│   └── path
│       └── to
│           └── file -> /opt/s3proxy/uploads/path/to/file
├── uploading
│   └── path
│       └── to
├── uploads
│   └── path
│       └── to
│           └── file
# ...
```

So by uploading a file the server will create the necessary directories to juggle the bits into place atomically. Specifically `uploads` will contain the full upload path
and `to_encrypt` will contain a symlink to the file to indicate that when `bin/encryptor.rb` runs it needs to upload the file to S3 (w/ encryption if configured in `config.yaml`).

If encryption is set to `false` in `config.yaml` then when you run `bin/encryptor.rb` you should end up with the following state locally and remotely respectively
upon a successful uploading of artifacts to S3

```
# ...
├── encrypted
│   └── ba495d1b86988b92ef3806dcc3d3777112a089cc
│       └── path
│           └── to
├── encrypting
│   └── ba495d1b86988b92ef3806dcc3d3777112a089cc
│       └── path
│           └── to
├── locks
│   └── path
│       └── to
│           └── file
# ...
├── to_encrypt
│   └── path
│       └── to
├── uploading
│   └── path
│       └── to
├── uploads
│   └── path
│       └── to
│           └── file
# ...
```

```
2015-05-28 02:22        33   s3://encrypted-artifacts/ba495d1b86988b92ef3806dcc3d3777112a089cc/path/to/file
```

If you have encryption set to `true` in `config.yaml` then the local and remote state should look as follows

```
# ...
├── encrypted
│   └── ba495d1b86988b92ef3806dcc3d3777112a089cc
│       └── path
│           └── to
├── encrypting
│   └── ba495d1b86988b92ef3806dcc3d3777112a089cc
│       └── path
│           └── to
├── locks
│   └── path
│       └── to
│           └── file
# ...
├── to_encrypt
│   └── path
│       └── to
├── uploading
│   └── path
│       └── to
├── uploads
│   └── path
│       └── to
│           └── file
# ...
```

```
2015-05-28 02:27        33   s3://encrypted-artifacts/ba495d1b86988b92ef3806dcc3d3777112a089cc/path/to/file
2015-05-28 02:27        12   s3://encrypted-artifacts/ba495d1b86988b92ef3806dcc3d3777112a089cc/path/to/file-iv
```

Notice the extra file. We need the extra file because during encryption we generate a random IV and we need it for decryption.

## GET /*
Assuming we start with a clean directory structure and we have some remote artifacts that we can get we can ask the proxy to download those artifacts by making a request to
the GET endpoint (`curl localhost:9292/path/to/file`). The logic for downloading is the same whether encryptiong is set to `true` or `false`. The only extra step is that
if encryption is set to `true` then we decrypt the downloaded artifact before moving it to `uploads/`

```
[root@localhost s3proxy]# curl localhost:9292/path/to/file
# ...
[root@localhost s3proxy]# tree -I vendor
# ...
├── to_decrypt
│   └── path
│       └── to
├── uploads
│   └── path
│       └── to
│           └── file
# ...
```

Notice `to_decrypt/`. The encrypted (or unencrypted artifact) and the IV file are downloaded to that folder before being decrypted and put into `uploads/` so that they can be
served by nginx and varnish.

# Deployment
RPM that can be installed with `rpm -i`. Can not be completely automatic because we need to set up S3 configuration for `s3cmd` for the user that will be running the service and we need to provide a private key for encryption/decryption. The current key in the repo (`private_key`) is only for testing purposes.
