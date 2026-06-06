#!/usr/bin/env bash
# Runs in GitHub Actions every 15 min. Tries to launch the Always-Free ARM
# instance in Chuncheon. On success: notifies Discord. On capacity error: quiet exit.
set -uo pipefail
export SUPPRESS_LABEL_WARNING=True

C="$OCI_COMPARTMENT"
AD="$OCI_AD"
SUBNET="$OCI_SUBNET"

# Already have a (non-terminated) postiz instance? Then stop hunting.
CNT=$(oci compute instance list --compartment-id "$C" \
  --query "length(data[?\"display-name\"=='postiz' && \"lifecycle-state\"!='TERMINATED'])" \
  --raw-output 2>/dev/null || echo 0)
if [ "${CNT:-0}" != "0" ]; then
  echo "postiz instance already exists (count=$CNT). Nothing to do."
  exit 0
fi

# Latest Ubuntu 24.04 ARM image
IMG=$(oci compute image list --compartment-id "$C" \
  --operating-system "Canonical Ubuntu" --operating-system-version "24.04" \
  --shape "VM.Standard.A1.Flex" --sort-by TIMECREATED \
  --query 'data[0].id' --raw-output)
echo "image=$IMG"

echo "$SSH_PUBKEY" > /tmp/key.pub

set +e
ID=$(oci compute instance launch \
  --compartment-id "$C" --availability-domain "$AD" \
  --shape VM.Standard.A1.Flex --shape-config '{"ocpus":2,"memoryInGBs":12}' \
  --image-id "$IMG" --subnet-id "$SUBNET" --assign-public-ip true \
  --ssh-authorized-keys-file /tmp/key.pub --display-name postiz \
  --query 'data.id' --raw-output --wait-for-state RUNNING 2>/tmp/err.txt)
rc=$?
set -e

if [ $rc -ne 0 ] || [ -z "${ID:-}" ]; then
  if grep -q "Out of host capacity" /tmp/err.txt; then
    echo "Out of host capacity — retry next run."
    exit 0
  fi
  echo "Launch error (non-capacity):"; cat /tmp/err.txt
  exit 0  # never fail the workflow on transient errors
fi

IP=$(oci compute instance list-vnics --instance-id "$ID" \
  --query 'data[0]."public-ip"' --raw-output)
echo "SUCCESS instance=$ID ip=$IP"

if [ -n "${DISCORD_WEBHOOK:-}" ]; then
  MSG="🎉 오라클 무료 서버 드디어 잡혔어!\\n공용 IP: \\\`$IP\\\`\\n클로드한테 \\\"서버 잡혔대\\\" 하면 Postiz 깔아줄게."
  curl -s -H "Content-Type: application/json" \
    -d "{\"content\":\"$MSG\"}" "$DISCORD_WEBHOOK" >/dev/null || true
fi
