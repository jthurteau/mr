group { 'ncsu':
  ensure => 'present',
  gid    => 1011,
}

file { '/var/www/application/vendor':
  ensure  => directory,
  require => File['/var/www/application'],
  group => 'ncsu',
}

file { '/var/www/application/library':
  ensure  => directory,
  require => File['/var/www/application'],
  group => 'ncsu',
}
