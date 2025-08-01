#!/bin/bash
# ~omadjoudj
#

usage() {
    cat << EOF
Usage: $0 --helmbundle <STRING> [--confirm]
       $0 [-h|--help]

Options:
  --helmbundle <STRING>  Required: Specify the helm bundle
  --confirm              Optional: Confirmation flag
  -h, --help            Show this help message

Example:

cd <GERRIT ROOT DIRECTORY>

helmbundles-apply.sh --helmbundle customisation-interstellar-cephmon.yaml

## Review the changes, then apply

helmbundles-apply.sh --helmbundle customisation-interstellar-cephmon.yaml --confirm


EOF
}

HELM_BUNDLE=""
CONFIRM=false
PREFIX="helm-controller/helmbundles"

while [ $# -gt 0 ]; do
    case "$1" in
        --helmbundle)
            if [ "$2" ]; then
                HELM_BUNDLE="$2"
                shift 2
            else
                echo "Error: --helmbundle requires a value" >&2
                exit 1
            fi
            ;;
        --confirm)
            CONFIRM=true
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1" >&2
            usage
            exit 1
            ;;
    esac
done

if [ -z "$HELM_BUNDLE" ]; then
    echo "Error: --helmbundle is required" >&2
    usage
    exit 1
fi

for c in $(kubectl config get-contexts | grep mcc | awk '{print $2}') ; do
    NS="customisations-$(kubectl --context "$c" get cluster -A --no-headers | grep -v default | awk '{print $1}')"
	echo "===============[ $c ]=================="
	if [[ "$CONFIRM" == "true" ]]; then
		echo "[!!]  confirm option was used. Applying changes for real."
		kubectl --context "$c" -n "$NS" apply -f "$PREFIX/$NS/$HELM_BUNDLE"
	else
		echo "[--]  This is a dry run. Showing diff as well."
		kubectl --context "$c" -n "$NS" --dry-run=client apply -f "$PREFIX/$NS/$HELM_BUNDLE"
		kubectl --context "$c" -n "$NS" diff -f "$PREFIX/$NS/$HELM_BUNDLE"

	fi

done
