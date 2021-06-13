vcsrepo { '/var/www/application/vendor/ncsulib-assets':
  ensure   => latest,
  provider => git,
  source   => "https://${developer}:${ghe_pat}@github.ncsu.edu/ncsu-libraries/shared-website-assets.git",
  require => File['/var/www/application/vendor'],
  #revision => 'v0.8.0', #TODO version from facts
}

# vcsrepo { '/var/www/application/vendor/footer':
#   ensure   => latest,
#   provider => git,
#   source   => "https://${developer}:${ghe_pat}@github.ncsu.edu/ncsu-libraries/footer.git",
#   require => File['/var/www/application/vendor'],
#   revision => 'v0.5.0', #TODO version from facts
# }
