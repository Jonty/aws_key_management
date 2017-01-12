#!/bin/bash
#
# Will rotate the credentials for the user and account that you have
# currently configured. It will print the shell `export` lines to use
# the creds.
#
# If you team uses STS with MFA to access the API, you must use those
# STS credentials.
#

key_id=$AWS_ACCESS_KEY_ID

get_user_name() {
  aws sts get-caller-identity \
    --query Arn \
    --output text | cut -f 2 -d /
}

get_access_keys() {
  aws iam list-access-keys \
    --user-name "$1" \
    --query 'AccessKeyMetadata[].AccessKeyId' \
    --output text
}

create_new_access_key() {
  new_key=$(aws iam create-access-key \
    --query '[AccessKey.AccessKeyId,AccessKey.SecretAccessKey]' \
	--output text)

  # This sets it globally
  key_id=$(echo "${new_key}" | cut -f1)
  key_secret=$(echo "${new_key}" | cut -f2)
  printf 'export AWS_ACCESS_KEY_ID="%s"\nexport AWS_SECRET_ACCESS_KEY="%s"\n' "${key_id}" "${key_secret}"
}

delete_keys_that_are_not() {
  access_keys="$(get_access_keys "${1}")"
  for key in $access_keys; do
	if [ "${key}" != "$2" ]; then
	  aws iam delete-access-key \
		--access-key-id "${key}"
    fi
  done
}

set -eu -o pipefail
username="$(get_user_name)"

# Delete all keys that are not the key we're using right now
# * If you're not using STS, this is a standard key
# * If you're using STS, this will remove all keys as your current key is STS
delete_keys_that_are_not "${username}" "${key_id}"

create_new_access_key

# Delete all keys that are not the new access key we just generated
delete_keys_that_are_not "${username}" "${key_id}"
