#!/bin/sh

set -eux

#########
# Parameters
SALT_VERSION=${SALT_VERSION:-3006}

##########
# Step 1: Install Saltstack and git
#wget -O - https://bootstrap.saltproject.io | sh -s -- stable ${SALT_VERSION}
#wget -O - https://raw.githubusercontent.com/saltstack/salt-bootstrap/0899e72c34958da284c29fd71eeddb52cc5abe9f/bootstrap-salt.sh | sh -s -- stable ${SALT_VERSION}
# workaround for https://github.com/saltstack/salt-bootstrap/issues/2027
# also see salt_bootstrap.sh -r
mkdir -p /etc/apt/keyrings
curl -fsSL https://packages.broadcom.com/artifactory/api/security/keypair/SaltProjectKey/public | tee /etc/apt/keyrings/salt-archive-keyring.pgp
curl -fsSL https://github.com/saltstack/salt-install-guide/releases/latest/download/salt.sources | tee /etc/apt/sources.list.d/salt.sources

echo "Package: salt-*
Pin: version ${SALT_VERSION}.*
Pin-Priority: 1001" | tee /etc/apt/preferences.d/salt-pin-1001

# grab installer script
wget -L https://github.com/saltstack/salt-bootstrap/releases/latest/download/bootstrap-salt.sh --output-document salt_bootstrap.sh --no-verbose

sh salt_bootstrap.sh -r -F -c /tmp onedir "${SALT_VERSION}"

# disable the service until configured
service salt-minion stop
# the bootstrap formula might need git installed..
apt-get install -y git

###########
# Step 2: install the bootstrap formula
wget -O - https://raw.githubusercontent.com/ketzacoatl/bootstrap-salt-formula/master/install.sh | sh

###########
# Step 3: configure the bootstrap formula
# edit this to enter your bootstrap pillar here, or upload during provisioning
if [ -n "${BOOTSTRAP_PILLAR_FILE+1}" ]; then
  mv ${BOOTSTRAP_PILLAR_FILE} /srv/bootstrap-salt-formula/pillar/bootstrap.sls
else
  cat <<END_PILLAR > /srv/bootstrap-salt-formula/pillar/bootstrap.sls
# for the salt.file_roots.single formula
file_roots_single:
  roots_root: /srv/salt
  url: https://github.com/fpco/fpco-salt-formula
  rev: master
END_PILLAR
fi
###########
# Step 4: bootstrap salt formula!
salt-call --local                                           \
          --file-root   /srv/bootstrap-salt-formula/formula \
          --pillar-root /srv/bootstrap-salt-formula/pillar  \
          --config-dir  /srv/bootstrap-salt-formula/conf    \
          state.highstate queue=True
