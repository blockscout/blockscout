#!/usr/bin/env bash

SECRET_KEY_REF="blockscout-data-migration-secret-key-ref"
KEY="initial-value"

function execute_command () {
	if [ ! -z "$DRY_RUN" ]; then
		echo "Would run: $1"
	else 
		if [ ! -z "$VERBOSE" ]; then
			echo "Executing: $1"
		fi	
		eval "$1"
	fi
}

function help () {
	echo "data_migration.sh -e DEPLOY_ENVIRONMENT -i INITIAL_VALUE" --dry-run
	echo "Starts a data migration job for the current k8s cluster context for the given environment and value."
	exit 0
}

function assert_value () {

	if [ -z "$DEPLOY_ENVIRONMENT" ]; then
		echo "No environment provided, please set an environment (e.g. alfajores, rc1staging)"
		exit 1
	fi

	if [ -z "$INITIAL_VALUE" ]; then
		echo "No initial value provided, please set an initial value for the migration"
		exit 2
	fi
}

function prepare_secret () {
	execute_command 'kubectl -n "$DEPLOY_ENVIRONMENT" delete secret "$SECRET_KEY_REF"'
	execute_command 'kubectl -n "$DEPLOY_ENVIRONMENT" create secret generic "$SECRET_KEY_REF" --from-literal="$KEY"="$INITIAL_VALUE"'
}

function start_job () {
	execute_command 'kubectl create job -n rc1staging --from=cronjob/"$DEPLOY_ENVIRONMENT"-blockscout"$SUFFIX"-data-migration "$DEPLOY_ENVIRONMENT"-blockscout"$SUFFIX"-data-migration-instance'
}



while [[ $# -gt 0 ]]; do
  case $1 in
    -h|--help)
      help
      ;;
    -e|--env)
      DEPLOY_ENVIRONMENT="$2"
      shift 2
      ;;
    -i|--initial-value)
      INITIAL_VALUE="$2"
      shift 2
      ;;
    --dry-run)
      DRY_RUN=true
      shift 
      ;;
    --suffix)
      SUFFIX="$2"
      shift 
      ;;
    -v|--verbose)
      VERBOSE=true
      shift 
      ;;
    -*|--*)
      echo "Unknown option $1"
      exit 1
      ;;
    *)
      POSITIONAL_ARGS+=("$1") # save positional arg
      shift # past argument
      ;;
  esac
done

assert_value
prepare_secret
start_job
