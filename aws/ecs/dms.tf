# DMS is not compatible with DocumentDB + TLS enabled
# Use mongodump/mongorestore on the bastion host instead:
#
# 1. SSH to bastion: ssh ec2-user@<bastion_public_ip>
# 2. Install tools: sudo yum install -y mongodb-database-tools
# 3. Download cert: curl -o global-bundle.pem https://truststore.pki.rds.amazonaws.com/global/global-bundle.pem
# 4. Dump from v5:
#    mongodump --host <v5-endpoint>:27017 --ssl --sslCAFile global-bundle.pem \
#      --username docdbadmin --password '<password>' --db engine --out /tmp/backup
# 5. Restore to v8:
#    mongorestore --host <v8-endpoint>:27017 --ssl --sslCAFile global-bundle.pem \
#      --username docdbadmin --password '<password>' --db engine /tmp/backup/engine
