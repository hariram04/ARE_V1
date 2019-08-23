#!/usr/bin/env bash

set -o errexit    # always exit on error
set -o pipefail   # don't ignore exit codes when piping output
set -o nounset    # fail on unset variables

#################################################################
# Script to setup a fully configured pipeline for Salesforce DX #
#################################################################

### Declare values

# Create a unique var to append
TICKS=$(echo $(date +%s | cut -b1-13))

# Name of your team (optional)
HEROKU_TEAM_NAME="appcloud-dev" 

# Name of the Heroku apps you'll use
HEROKU_DEV_APP_NAME="dev$TICKS"
HEROKU_STAGING_APP_NAME="are-staging-v1"
HEROKU_PROD_APP_NAME="are-production-v1"

# Pipeline
HEROKU_PIPELINE_NAME="are-v1-pipeline"

# Usernames or aliases of the orgs you're using
DEV_HUB_USERNAME="HubOrg"
DEV_USERNAME="DevOrg"
STAGING_USERNAME="TestOrg"
PROD_USERNAME="ProdOrg"

# Repository with your code
GITHUB_REPO="hariram04/ARE_V1"

### Setup script

# Support a Heroku team
HEROKU_TEAM_FLAG=""
if [ ! "$HEROKU_TEAM_NAME" == "" ]; then
  HEROKU_TEAM_FLAG="-t $HEROKU_TEAM_NAME"
fi

# Create three Heroku apps to map to orgs
heroku apps:create $HEROKU_DEV_APP_NAME $HEROKU_TEAM_FLAG
heroku apps:create $are-staging-v1 $HEROKU_TEAM_FLAG
heroku apps:create $are-production-v1 $HEROKU_TEAM_FLAG

# Set the stage (since STAGE isn't required, review apps don't get one)
heroku config:set STAGE=DEV -a $HEROKU_DEV_APP_NAME
heroku config:set STAGE=STAGING -a $are-staging-v1
heroku config:set STAGE=PROD -a $are-production-v1

# Turn on debug logging
heroku config:set SFDX_BUILDPACK_DEBUG=false -a $HEROKU_DEV_APP_NAME
heroku config:set SFDX_BUILDPACK_DEBUG=false -a $are-staging-v1
heroku config:set SFDX_BUILDPACK_DEBUG=false -a $are-production-v1

# Setup sfdxUrl's for auth
devHubSfdxAuthUrl=$(sfdx force:org:display --verbose -u $DEV_HUB_USERNAME --json | jq -r .result.sfdxAuthUrl)
heroku config:set DEV_HUB_SFDX_AUTH_URL=$devHubSfdxAuthUrl -a $HEROKU_DEV_APP_NAME

devSfdxAuthUrl=$(sfdx force:org:display --verbose -u $DEV_USERNAME --json | jq -r .result.sfdxAuthUrl)
heroku config:set SFDX_AUTH_URL=$devSfdxAuthUrl -a $HEROKU_DEV_APP_NAME

stagingSfdxAuthUrl=$(sfdx force:org:display --verbose -u $hariram04@brave-raccoon-427616.com --json | jq -r .result.sfdxAuthUrl)
heroku config:set SFDX_AUTH_URL=$stagingSfdxAuthUrl -a $are-staging-v1

stagingSfdxAuthUrl=$(sfdx force:org:display --verbose -u $hariram04@gmail.com --json | jq -r .result.sfdxAuthUrl)
heroku config:set SFDX_AUTH_URL=$stagingSfdxAuthUrl -a $are-production-v1

# Add buildpacks to apps
heroku buildpacks:add -i 1 https://github.com/wadewegner/salesforce-cli-buildpack#v3 -a $HEROKU_DEV_APP_NAME
heroku buildpacks:add -i 1 https://github.com/wadewegner/salesforce-cli-buildpack#v3 -a $are-staging-v1
heroku buildpacks:add -i 1 https://github.com/wadewegner/salesforce-cli-buildpack#v3 -a $are-production-v1

heroku buildpacks:add -i 2 https://github.com/wadewegner/salesforce-dx-buildpack#v3 -a $HEROKU_DEV_APP_NAME
heroku buildpacks:add -i 2 https://github.com/wadewegner/salesforce-dx-buildpack#v3 -a $are-staging-v1
heroku buildpacks:add -i 2 https://github.com/wadewegner/salesforce-dx-buildpack#v3 -a $are-production-v1

# Create Pipeline
# Valid stages: "test", "review", "development", "staging", "production"
heroku pipelines:create $HEROKU_PIPELINE_NAME -a $HEROKU_DEV_APP_NAME -s development $HEROKU_TEAM_FLAG
heroku pipelines:add $HEROKU_PIPELINE_NAME -a $are-staging-v1 -s staging
heroku pipelines:add $HEROKU_PIPELINE_NAME -a $are-production-v1 -s production
# bug: https://github.com/heroku/heroku-pipelines/issues/80
# heroku pipelines:setup $are-v1-pipeline $hariram04/ARE_V1 -y $HEROKU_TEAM_FLAG

heroku ci:config:set -p $HEROKU_PIPELINE_NAME DEV_HUB_SFDX_AUTH_URL=$devHubSfdxAuthUrl
heroku ci:config:set -p $are-v1-pipeline SFDX_AUTH_URL=$https://login.salesforce.com
heroku ci:config:set -p $are-v1-pipeline SFDX_BUILDPACK_DEBUG=false

# Clean up script
echo "heroku pipelines:destroy $are-v1-pipeline
heroku apps:destroy -a $HEROKU_DEV_APP_NAME -c $HEROKU_DEV_APP_NAME
heroku apps:destroy -a $are-v1-pipeline -c $are-staging-v1
heroku apps:destroy -a $are-v1-pipeline -c $are-production-v1" > destroy.sh

echo ""
echo "Run ./destroy.sh to remove resources"
echo ""
