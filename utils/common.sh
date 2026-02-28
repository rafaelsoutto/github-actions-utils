# if variable GET_ENVRIONMENT_BY_BRANCH is set to "true", get environment name from git branch
get_environment_by_branch() {
  local branch_name
  branch_name=$(git rev-parse --abbrev-ref HEAD)

  case "$branch_name" in
    main | master)
      export ENVIRONMENT="prod"
      ;;
    develop | dev)
      export ENVIRONMENT="dev"
      ;;
    staging | stage)
      export ENVIRONMENT="dev"
      ;;
    feature/*)
      export ENVIRONMENT="dev"
      ;;
    bugfix/*)
      export ENVIRONMENT="dev"
      ;;
    hotfix/*)
      export ENVIRONMENT="dev"
      ;;
    *)
      export ENVIRONMENT="dev"
      ;;
  esac

  echo "Set ENVIRONMENT to '$ENVIRONMENT' based on branch '$branch_name'"
}
