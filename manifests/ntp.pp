# Install and configure NTP service
class sunet::ntp {
   package { 'ntp': ensure => 'latest' }
   service { 'ntp':
      name       => 'ntp',
      ensure     => running,
      enable     => true,
      hasrestart => true,
      require => Package['ntp'],
   }

   # Don't use pool.ntp.org servers, but rather DHCP provided NTP servers
   sunet::snippets::file_line { 'no_pool_ntp_org_servers':
     ensure      => 'comment',
     filename    => '/etc/ntp.conf',
     line        => '^server .*\.pool\.ntp\.org',
     notify      => Service['ntp'],
   }

}