# Deploy HDP to a single node

1. Install & Start Ambari-Agent & Ambari-Server
2. Update `cluster.json`: Replace `yourhostnamehere` with the hostname of the server.
  - Can determine the full hostname with: `hostname -f`
3. Execute `./deploy.sh` from the Ambari Server
  - (Optional): Update `server=` if not running from the Ambari Server
  - (Optional): Update `pass=` to the Ambari password if changed from `admin`
