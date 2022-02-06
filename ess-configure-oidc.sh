#!/bin/bash

# Default OIDC config
read -r -d '' OIDC_CONFIG << EOM
xpack.security.authc.realms.oidc.your-oidc-realm-name:
    order: 2
    rp.client_id: "client-id"
    rp.response_type: "code"
    rp.redirect_uri: "<KIBANA_ENDPOINT_URL>/api/security/oidc/callback"
    op.issuer: "<check with your OpenID Connect Provider>"
    op.authorization_endpoint: "<check with your OpenID Connect Provider>"
    op.token_endpoint: "<check with your OpenID Connect Provider>"
    op.userinfo_endpoint: "<check with your OpenID Connect Provider>"
    op.jwkset_path: "<check with your OpenID Connect Provider>"
    claims.principal: sub
    claims.groups: "http://example.info/claims/groups"
EOM

function usage {
	cat <<EOM
Usage:
$(basename "$0") -i <CLUSTER_ID> -c [CONFIGURATION_STRING] -a [API_KEY]
$(basename "$0") -p

  -i CLUSTER_ID
			The cluster ID that you want to set the OIDC configuration for

  -c CONFIGURATION_STRING (optional)
			The OIDC configuration you want to add to the cluster.  The Kibana
			URLs in the configuration will be replaced with the proper URLs
			from the real cluster.  IF THIS IS NOT PROVIDED THE DEFAULT OIDC
			CONFIG WILL BE USED

  -a API_KEY (optional)
			The ESS API key as a base64 encoded string
			If you don't specify an API key the EC_API_KEY variable will be used
			If neither are set then the program will exit with an error

  -p
			Print the default OIDC configuration

  -h
			Display help

EOM

	exit 2
}

if [ $# -eq 0 ] ; then
	usage
	exit 2
fi

while getopts ":i:c:a:hp" OPTKEY; do
	case "$OPTKEY" in
		i)
			CLUSTER_ID=$OPTARG
			;;
		c)
			CONFIG=$OPTARG
			;;
        a)
            export EC_API_KEY=$OPTARG
            ;;
		p)
			printf "$OIDC_CONFIG"
			exit 0
			;;
		h|*)
			usage
			;;
	esac
done

shift $((OPTIND - 1))

if [ -z "$EC_API_KEY" ]; then
	echo "The ESS API key can be found"
	usage
fi

if [ -z "$CLUSTER_ID" ]; then
	echo "Cluster ID is not set!"
	usage
fi

# Check to see if ecctl is installed
command -v ecctl >/dev/null 2>&1 || { printf >&2 "\necctl is not installed.\nPlease install using the following link:\nhttps://www.elastic.co/downloads/ecctl\n\n"; exit 1; }

# Check to see if jq is installed
command -v jq >/dev/null 2>&1 || { printf >&2 "\njq (https://stedolan.github.io/jq/) is not installed.\nPlease install jq before proceeding\n\n"; exit 1; }

# Get the configuration for the cluster ID
printf "Attempting to fetch the cluster configuration..\n"
CLUSTER_CONFIG="`ecctl deployment show --generate-update-payload "$CLUSTER_ID"`"

if [ $? -ne 0 ]; then
	printf "Cluster not found...exiting.  Please check if the cluster ID is valid\n"
    exit 2
fi
printf "Found the cluster configuration\n"

#Get the proper Kibana URL
printf "Attempting to find the Kibana URL..\n"
KIBANA_URL="`ecctl deployment show "$CLUSTER_ID" | jq -r '.resources.kibana[0].info.metadata.service_url'`"

if [ $? -ne 0 ]; then
	printf "Kibana URL not found...exiting.  Please check if the json path to the Kibana URL is valid\n"
    exit 2
fi

printf "Found the following Kibana URL:\n  $KIBANA_URL\n\n"

# Insert the Kibana URL into the OIDC_CONFIG variable
printf "Replacing Kibana URL in OIDC_CONFIG...\n"

OIDC_CONFIG="`echo \"$OIDC_CONFIG\" | sed s~\<KIBANA_ENDPOINT_URL\>~\$KIBANA_URL~`"

if [ $? -ne 0 ]; then
    printf "Kibana URL replacement error...exiting.  Please check if the Kibana URL placeholder is equal to <KIBANA_ENDPOINT_URL>\n"
	exit 2
fi

printf "Using the following OIDC config...\n\n$OIDC_CONFIG\n\n"

# Insert OIDC_CONFIG into CLUSTER_CONFIG
CLUSTER_CONFIG=`echo "$CLUSTER_CONFIG" | jq --arg oidc_config "$OIDC_CONFIG" '.resources.elasticsearch[0].plan.elasticsearch += { "user_settings_yaml": $oidc_config}'` 

printf "Updating the cluster with the following cluster configuration:\n\n$CLUSTER_CONFIG\n\n"

ecctl deployment update $CLUSTER_ID -f <(printf "%s" "$CLUSTER_CONFIG")

if [ $? -ne 0 ]; then
    printf "Cluster config update failed.  Please check the output\n"
	exit 2
fi

printf "Cluster update in progress!\n"
