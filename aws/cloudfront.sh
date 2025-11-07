# invalidade cloudfront distribution function
function invalidate_cloudfront_distribution() {
  local distribution_id=$1
  local paths=$2

  if [[ -z "$distribution_id" || -z "$paths" ]]; then
    echo "Usage: invalidate_cloudfront_distribution <distribution_id> <paths>"
    return 1
  fi

  aws cloudfront create-invalidation --distribution-id "$distribution_id" --paths "$paths"
}
