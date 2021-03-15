echo Setting Up Eyaml...
# https://github.ncsu.edu/ncstate-linux/infrastructure/blob/production/docs/puppet/using-eyaml.md
yum install rubygems
gem install hiera-eyaml
# populate ~/.eyaml/ncsu.pem
# copy ~/.eyaml/config.yaml
##
# ---
# pkcs7_public_key: '/home/vagrant/.eyaml/ncsu.pem' #it doesn't understand ~

# example
##
# eyaml encrypt -s secretvalue