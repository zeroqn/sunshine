#! /usr/bin/env nix-shell
#! nix-shell -i bash -p curl jq nix

set -euo pipefail

usage() {
  cat <<'EOF'
Update release-assets.json with the newest pinned GitHub release asset hashes.

Environment overrides:
  GITHUB_REPO    owner/repo override. Default: derived from git remote origin
  RELEASE_TAG    release tag to inspect. Default: main-build
  GITHUB_API_URL GitHub API base URL. Default: https://api.github.com
  ASSET_PREFIX   asset name prefix. Default: sunshine-main-
  MANIFEST_PATH  output manifest path. Default: release-assets.json
  GITHUB_TOKEN   optional token for private repositories/releases

Examples:
  ./updater.sh
  RELEASE_TAG=latest ./updater.sh
  GITHUB_REPO=owner/repo RELEASE_TAG=main-build ./updater.sh
EOF
}

if [[ "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

manifest_path="${MANIFEST_PATH:-release-assets.json}"
release_tag="${RELEASE_TAG:-main-build}"
api_url="${GITHUB_API_URL:-https://api.github.com}"
asset_prefix="${ASSET_PREFIX:-sunshine-main-}"

repo="${GITHUB_REPO:-}"
if [[ -z "$repo" ]]; then
  remote_url="$(git remote get-url origin)"
  repo="$(printf '%s\n' "$remote_url" | sed -E 's#^[^:]+:([^/]+/[^/.]+)(\.git)?$#\1#; s#^https://[^/]+/([^/]+/[^/.]+)(\.git)?$#\1#')"
fi

if [[ ! "$repo" =~ ^[^/]+/[^/]+$ ]]; then
  echo "Unable to determine GitHub owner/repo from origin remote: ${repo:-<empty>}" >&2
  exit 1
fi

owner="${repo%%/*}"
repo_name="${repo#*/}"

headers=(
  -H "Accept: application/vnd.github+json"
  -H "X-GitHub-Api-Version: 2022-11-28"
)

if [[ -n "${GITHUB_TOKEN:-}" ]]; then
  headers+=(-H "Authorization: Bearer ${GITHUB_TOKEN}")
fi

release_endpoint="repos/${repo}/releases/tags/${release_tag}"
if [[ "$release_tag" == "latest" ]]; then
  release_endpoint="repos/${repo}/releases/latest"
fi

release_json="$(curl --silent --show-error --fail --location "${headers[@]}" "${api_url%/}/${release_endpoint}")"

assets_json="$(
  jq --arg prefix "$asset_prefix" '
    [
      .assets[]
      | select(.name | startswith($prefix))
      | select(.name | endswith(".tar.gz"))
      | {
          name,
          url: .browser_download_url,
          system: (
            .name
            | sub("^" + $prefix; "")
            | sub("\\.tar\\.gz$"; "")
          )
        }
    ]
  ' <<<"$release_json"
)"

asset_count="$(jq 'length' <<<"$assets_json")"
if [[ "$asset_count" -eq 0 ]]; then
  echo "No release assets matching ${asset_prefix}*.tar.gz were found for ${repo}@${release_tag}" >&2
  exit 1
fi

workdir="$(mktemp -d)"
trap 'rm -rf "$workdir"' EXIT
printf '[]\n' >"$workdir/assets.json"

while IFS=$'\t' read -r system name url; do
  download_path="$workdir/${name}"
  curl --silent --show-error --fail --location "${headers[@]}" --output "$download_path" "$url"
  hash="$(nix hash file --type sha256 --sri "$download_path")"

  jq \
    --arg system "$system" \
    --arg name "$name" \
    --arg url "$url" \
    --arg hash "$hash" \
    '. + [{key: $system, value: {name: $name, url: $url, hash: $hash}}]' \
    "$workdir/assets.json" >"$workdir/assets.next.json"
  mv "$workdir/assets.next.json" "$workdir/assets.json"
done < <(
  jq --raw-output '.[] | [.system, .name, .url] | @tsv' <<<"$assets_json"
)

short_commit="$(jq --raw-output '(.target_commitish // .tag_name // "unknown")[:12]' <<<"$release_json")"
tag_name="$(jq --raw-output '.tag_name' <<<"$release_json")"
version="${tag_name}-${short_commit}"

jq -n \
  --arg owner "$owner" \
  --arg repo "$repo_name" \
  --arg tag "$tag_name" \
  --arg version "$version" \
  --slurpfile assets "$workdir/assets.json" \
  '{
    owner: $owner,
    repo: $repo,
    release: {
      tag: $tag,
      version: $version
    },
    assets: ($assets[0] | from_entries)
  }' >"$manifest_path"

echo "Updated ${manifest_path} for ${repo}@${tag_name}"
