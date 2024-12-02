

# Create SP

```shell
SUBSCRIPTION_ID=$(az account list -o json | jq -r '.[]|select(.isDefault)|.id')
echo "Subscription: $SUBSCRIPTION_ID"
# note credentials for config
AZCRED=$(az ad sp create-for-rbac --name "waf-deployer" --role="Contributor" --scopes="/subscriptions/$SUBSCRIPTION_ID")
# echo "$AZCRED" | jq .
CLIENT_ID=$(echo "$AZCRED" | jq -r .appId)
CLIENT_SECRET=$(echo "$AZCRED" | jq -r .password)
TENANT_ID=$(echo "$AZCRED" | jq -r .tenant)

# for your terraform.tfvars
echo "az_clientid=\"$CLIENT_ID\""
echo "az_clientsecret=\"$CLIENT_SECRET\""
echo "az_tenantid=\"$TENANT_ID\""
echo "az_subscription=\"$SUBSCRIPTION_ID\""

# own SP audit
az ad sp list --show-mine -o table

# when closing lab, remove SP
az ad sp list --display-name waf-deployer -o json 
az ad sp delete --id $(az ad sp list --display-name waf-deployer -o json | jq -r .[].id)


### self signed cert into pfx file (for Azure Key Vault)

# produde app.key+app.pem
APPSECAPP=wafpoc-0ed1ab09.westeurope.cloudapp.azure.com
openssl req -newkey rsa:2048 -nodes -keyout app.key -x509 -days 365 -addext "subjectAltName = DNS:${APPSECAPP}" -subj "/C=US/CN=${APPSECAPP}" -out app.pem

# ispect
openssl x509 -text -noout -in app.pem | egrep 'DNS|CN'
# export as pfx
openssl pkcs12 -export -out app.pfx -inkey app.key -in app.pem 
# pwd vpn123 ;-)
```