#NOTE use this manifest for linking local-dev Saf copy since the hiera method 
# doesn't layer well with project specific rhlamp:manage_files directives

file { "${::app_vendor_root}/Saf":
  ensure => 'link',
  target => '/saf',
}
